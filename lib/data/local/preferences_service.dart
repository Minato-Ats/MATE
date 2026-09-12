import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/intervention_event.dart';
import '../models/schedule_rule.dart';

/// Thin wrapper around [SharedPreferences].
///
/// This is the base of MATE's local data layer: every piece of user data
/// stays on-device (no accounts, no server) per the project's core
/// principles. Structured data that outgrows simple key-value storage
/// (e.g. historical stats at real scale) will move to an on-device database
/// in a later phase behind the repository interfaces in `data/repositories`;
/// everything Phase 0-2 need fits comfortably here.
///
/// Both the main MATE UI and the separate intervention screen (a different
/// Flutter engine/isolate, see `intervention_main.dart`) create their own
/// instance of this class, but both read/write the same underlying Android
/// `SharedPreferences` storage — that's how the two independent Dart
/// isolates share settings like per-app wait time without a platform
/// channel round-trip.
class PreferencesService {
  PreferencesService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService._(prefs);
  }

  static const _themeModeKey = 'theme_mode';
  static const _guardedPackagesKey = 'guarded_packages';
  static const _waitSecondsKey = 'wait_seconds_by_package';
  static const _eventLogKey = 'intervention_events';
  static const _questionByPackageKey = 'question_by_package';
  static const _scheduleRuleKey = 'schedule_rule';
  static const _alwaysGuardPackagesKey = 'always_guard_packages';
  static const _pausedUntilKey = 'paused_until_epoch_ms';
  static const _strictModeKey = 'strict_mode_enabled';

  /// Presented as the only wait-time choices in the UI (Phase 4: fewer,
  /// clearer options rather than a long list).
  static const waitSecondsOptions = [3, 5, 10, 30];
  static const defaultWaitSeconds = 5;

  /// Shown in the intervention screen's purpose field when no custom
  /// question has been set for that app — worded to invite a moment's
  /// thought, not to interrogate.
  static const defaultQuestion = '何しに開く？';

  static const _maxEventLogEntries = 500;

  /// One of 'system', 'light', 'dark'. Defaults to 'system'.
  String get themeMode => _prefs.getString(_themeModeKey) ?? 'system';

  Future<void> setThemeMode(String value) => _prefs.setString(_themeModeKey, value);

  /// Package names of apps the user has chosen for MATE to guard.
  Set<String> get guardedPackageNames => (_prefs.getStringList(_guardedPackagesKey) ?? const []).toSet();

  Future<void> setGuardedPackageNames(Set<String> packageNames) =>
      _prefs.setStringList(_guardedPackagesKey, packageNames.toList());

  /// How long the intervention screen makes the user wait before "開く"
  /// becomes available for [packageName]. Falls back to [defaultWaitSeconds].
  int waitSecondsFor(String packageName) => _waitSecondsByPackage[packageName] ?? defaultWaitSeconds;

  Future<void> setWaitSecondsFor(String packageName, int seconds) async {
    final updated = Map<String, int>.of(_waitSecondsByPackage)..[packageName] = seconds;
    await _prefs.setString(_waitSecondsKey, jsonEncode(updated));
  }

  Map<String, int> get _waitSecondsByPackage {
    final raw = _prefs.getString(_waitSecondsKey);
    if (raw == null) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as int));
  }

  /// Custom intervention question for [packageName], or [defaultQuestion]
  /// if none was set (an empty/whitespace-only custom value also falls
  /// back, so clearing the field back to blank behaves as "reset").
  String questionFor(String packageName) {
    final custom = _questionByPackage[packageName]?.trim();
    return (custom == null || custom.isEmpty) ? defaultQuestion : custom;
  }

  Future<void> setQuestionFor(String packageName, String? question) async {
    final updated = Map<String, String>.of(_questionByPackage);
    final trimmed = question?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      updated.remove(packageName);
    } else {
      updated[packageName] = trimmed;
    }
    await _prefs.setString(_questionByPackageKey, jsonEncode(updated));
  }

  Map<String, String> get _questionByPackage {
    final raw = _prefs.getString(_questionByPackageKey);
    if (raw == null) return const {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  /// The global guarding schedule (time-of-day + weekdays). Disabled by
  /// default, meaning "guard whenever the app is on the guarded list" —
  /// exactly Phase 1-3's behavior, so turning this on is opt-in narrowing.
  ScheduleRule get scheduleRule {
    final raw = _prefs.getString(_scheduleRuleKey);
    if (raw == null) return ScheduleRule.disabled;
    return ScheduleRule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> setScheduleRule(ScheduleRule rule) =>
      _prefs.setString(_scheduleRuleKey, jsonEncode(rule.toJson()));

  /// Apps that ignore [scheduleRule] entirely and are guarded around the
  /// clock — the "actually, always watch this one" escape hatch so the one
  /// global schedule doesn't have to fit every app.
  Set<String> get alwaysGuardPackages => (_prefs.getStringList(_alwaysGuardPackagesKey) ?? const []).toSet();

  Future<void> setAlwaysGuardPackages(Set<String> packageNames) =>
      _prefs.setStringList(_alwaysGuardPackagesKey, packageNames.toList());

  /// When non-null and in the future, MATE doesn't intervene for *any* app
  /// until this moment — a temporary, self-expiring pause rather than a
  /// separate on/off switch, so there's nothing to remember to turn back on.
  DateTime? get pausedUntil {
    final millis = _prefs.getInt(_pausedUntilKey);
    if (millis == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(millis);
    return until.isAfter(DateTime.now()) ? until : null;
  }

  Future<void> setPausedUntil(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_pausedUntilKey);
    } else {
      await _prefs.setInt(_pausedUntilKey, value.millisecondsSinceEpoch);
    }
  }

  /// Strict Mode: makes settings changes deliberately harder to weaken in
  /// the moment (see `StrictModeGuard`), without ever making them
  /// impossible — see that class for the specific limits it enforces.
  bool get strictModeEnabled => _prefs.getBool(_strictModeKey) ?? false;

  Future<void> setStrictModeEnabled(bool value) => _prefs.setBool(_strictModeKey, value);

  /// Appends one intervention event, trimming the oldest entries beyond
  /// [_maxEventLogEntries] so this can't grow without bound. The Stats
  /// screen reads this (via [loadEventLog]) to compute real statistics.
  ///
  /// Uses [SharedPreferencesAsync] rather than the cached [SharedPreferences]
  /// instance above, deliberately: this is written by the intervention
  /// screen's *separate* Flutter engine (a fresh isolate every time, see
  /// `intervention_main.dart`) and read by the main app's engine, which
  /// stays alive for a long time. The legacy `SharedPreferences.getInstance()`
  /// API caches its values in memory per-isolate and never notices writes
  /// made by another isolate, so the main engine would keep showing stale
  /// (or empty) stats until the whole app process restarted. `SharedPreferencesAsync`
  /// has no such cache — every call goes to native storage — which is
  /// exactly the freshness this cross-engine data needs.
  Future<void> appendEvent(InterventionEvent event) async {
    final events = await loadEventLog()..add(event);
    final trimmed = events.length > _maxEventLogEntries
        ? events.sublist(events.length - _maxEventLogEntries)
        : events;
    await _asyncPrefs.setString(_eventLogKey, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<List<InterventionEvent>> loadEventLog() async {
    final raw = await _asyncPrefs.getString(_eventLogKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => InterventionEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Deliberately not `static final`: SharedPreferencesAsync's constructor
  // captures whatever SharedPreferencesAsyncPlatform.instance is *at
  // construction time*, so a cached instance would keep pointing at a
  // stale platform after tests swap it out between cases. Constructing
  // fresh per call is cheap (a thin wrapper, no I/O happens here) and
  // avoids that trap.
  SharedPreferencesAsync get _asyncPrefs => SharedPreferencesAsync();
}

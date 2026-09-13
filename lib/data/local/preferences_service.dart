import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/intervention_event.dart';
import '../models/schedule_rule.dart';
import '../models/serious_mode_escalation.dart';

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
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _soundEffectsEnabledKey = 'sound_effects_enabled';
  static const _goalKey = 'user_goal';
  static const _seriousModeEnabledKey = 'serious_mode_enabled';
  static const _seriousModeEscalationKey = 'serious_mode_escalation';
  static const _seriousModeMaxWaitReachedKey = 'serious_mode_max_wait_seconds_reached';
  static const _seriousModeMessageHistoryKey = 'serious_mode_message_history';

  /// How many recently-shown serious-mode message ids to remember, so the
  /// anti-repeat picker can avoid reshowing any of them (Phase 6.6 spec: a
  /// ~20-entry recent-usage history).
  static const _seriousModeMessageHistoryLimit = 20;

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

  /// Whether the first-run onboarding flow (Phase 5) has been completed.
  /// Defaults to `false` so a fresh install always sees it once.
  bool get onboardingCompleted => _prefs.getBool(_onboardingCompletedKey) ?? false;

  Future<void> setOnboardingCompleted(bool value) => _prefs.setBool(_onboardingCompletedKey, value);

  /// Whether short button-tap sound effects (Phase 5) play alongside
  /// haptics. Defaults to `true`; haptics themselves are unaffected by this
  /// flag — it only gates sound.
  bool get soundEffectsEnabled => _prefs.getBool(_soundEffectsEnabledKey) ?? true;

  Future<void> setSoundEffectsEnabled(bool value) => _prefs.setBool(_soundEffectsEnabledKey, value);

  /// The user's one current self-defined goal (free text — 受験合格、資格取得、
  /// 転職、筋トレ、etc; Phase 6.6), or `null` if they've never set one. MATE
  /// works fully without this being set; it's only ever used to personalize
  /// serious-mode copy.
  String? get goal {
    final value = _prefs.getString(_goalKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setGoal(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _prefs.remove(_goalKey);
    } else {
      await _prefs.setString(_goalKey, trimmed);
    }
  }

  /// 本気モード (Serious Mode, Phase 6.6) — a distinct, much stricter
  /// intervention flow (reason input → 今必要？ → escalating "それでも開く"
  /// wait) than ルール固定モード, which only guards *settings* from being
  /// weakened. Defaults to `false`: this is an opt-in feature only for users
  /// who deliberately turn it on, never forced on an existing/new user.
  bool get seriousModeEnabled => _prefs.getBool(_seriousModeEnabledKey) ?? false;

  Future<void> setSeriousModeEnabled(bool value) => _prefs.setBool(_seriousModeEnabledKey, value);

  /// Loads the shared (cross-app) cumulative "それでも開く" escalation state.
  /// Uses [_asyncPrefs] like [appendEvent]/[loadEventLog] — for the same
  /// reason: this is read and written from the intervention screen's fresh
  /// isolate every time a guarded app is opened, and must always see the
  /// truly-latest value written by whichever isolate handled the previous
  /// guarded-app trigger, not a stale per-isolate cache.
  Future<SeriousModeEscalation> loadSeriousModeEscalation() async {
    final raw = await _asyncPrefs.getString(_seriousModeEscalationKey);
    if (raw == null) return SeriousModeEscalation.initial;
    return SeriousModeEscalation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveSeriousModeEscalation(SeriousModeEscalation state) =>
      _asyncPrefs.setString(_seriousModeEscalationKey, jsonEncode(state.toJson()));

  /// What "それでも開く" would cost right now, across any guarded app.
  Future<int> effectiveSeriousModeWaitSeconds(DateTime now) async =>
      (await loadSeriousModeEscalation()).effectiveWaitSeconds(now);

  /// Records the user explicitly choosing "それでも開く" at [now], escalating
  /// the shared wait for every guarded app's *next* trigger. Must only be
  /// called from that one choice — never from detection alone, and never
  /// from "やめとく" (Phase 6.6: only this explicit choice may increase the
  /// penalty).
  Future<void> recordSeriousModeOpenAnyway(DateTime now) async {
    final current = await loadSeriousModeEscalation();
    final next = current.afterOpenAnyway(now);
    await _saveSeriousModeEscalation(next);
    final maxReached = await _asyncPrefs.getInt(_seriousModeMaxWaitReachedKey) ?? 0;
    if (next.pendingSeconds > maxReached) {
      await _asyncPrefs.setInt(_seriousModeMaxWaitReachedKey, next.pendingSeconds);
    }
  }

  /// The highest escalated wait ever reached (for future stats display —
  /// Phase 6.6 doesn't require surfacing this in the UI yet).
  Future<int> get seriousModeMaxWaitSecondsReached async =>
      await _asyncPrefs.getInt(_seriousModeMaxWaitReachedKey) ?? 0;

  /// Ids of the most recently shown serious-mode copy templates (newest
  /// last), capped at [_seriousModeMessageHistoryLimit] — used to avoid
  /// reshowing the same line too soon. Cross-isolate-safe for the same
  /// reason as [loadSeriousModeEscalation].
  Future<List<String>> loadSeriousModeMessageHistory() async {
    final raw = await _asyncPrefs.getString(_seriousModeMessageHistoryKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> pushSeriousModeMessageId(String id) async {
    final history = await loadSeriousModeMessageHistory()..add(id);
    final trimmed = history.length > _seriousModeMessageHistoryLimit
        ? history.sublist(history.length - _seriousModeMessageHistoryLimit)
        : history;
    await _asyncPrefs.setString(_seriousModeMessageHistoryKey, jsonEncode(trimmed));
  }

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

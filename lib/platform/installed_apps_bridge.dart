import 'package:flutter/services.dart';

import '../data/models/installed_app.dart';
import '../data/models/schedule_rule.dart';

/// Boundary between MATE's Flutter/Dart core and OS-specific app-listing and
/// usage-access APIs (Android `PackageManager` + `UsageStatsManager` today;
/// iOS Screen Time / FamilyControls in a later phase).
///
/// Every call falls back to a safe empty/false result if no native
/// implementation is registered for the current platform (e.g. iOS today,
/// or Windows/tests), so call sites in `data/repositories` never need to
/// branch on platform.
class InstalledAppsBridge {
  InstalledAppsBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.mate/installed_apps');

  final MethodChannel _channel;

  /// Apps the OS reports as installed and launchable, excluding MATE itself.
  Future<List<InstalledApp>> fetchInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('getInstalledApps');
      if (result == null) return const [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map((raw) => InstalledApp(
                packageName: raw['packageName'] as String,
                appName: raw['appName'] as String,
                iconBytes: raw['icon'] as Uint8List?,
              ))
          .toList();
    } on MissingPluginException {
      // No native implementation on this platform yet (e.g. iOS, desktop).
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Whether the user has granted MATE the "Usage access" special app
  /// permission, required to detect the foreground app.
  Future<bool> hasUsageAccessPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccessPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the OS settings screen where the user can grant usage access.
  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on MissingPluginException {
      // Nothing to open on platforms without this settings screen.
    } on PlatformException {
      // Ignore: best-effort navigation to a system settings screen.
    }
  }

  /// Whether the user has granted MATE "Display over other apps". Needed so
  /// the native watcher can briefly show a covering overlay right before
  /// launching the intervention screen — without a visible window at that
  /// moment, Android's background-activity-start restrictions silently
  /// block the launch (confirmed via on-device testing in Phase 2).
  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the OS settings screen where the user can grant that permission.
  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod<void>('openOverlaySettings');
    } on MissingPluginException {
      // Nothing to open on platforms without this settings screen.
    } on PlatformException {
      // Ignore: best-effort navigation to a system settings screen.
    }
  }

  /// Pushes the current guarded-package set to the native side, which needs
  /// its own copy because [ForegroundWatcherService] (Android) runs
  /// independently of the Flutter engine and can't read Dart state directly.
  Future<void> syncGuardedPackages(Set<String> packageNames) async {
    try {
      await _channel.invokeMethod<void>('syncGuardedPackages', packageNames.toList());
    } on MissingPluginException {
      // No native watcher on this platform yet.
    } on PlatformException {
      // Best-effort sync; the next successful call will catch up.
    }
  }

  /// Starts the always-on native watcher that detects a guarded app coming
  /// to the foreground, independent of whether MATE's own UI is open.
  Future<void> startWatcherService() async {
    try {
      await _channel.invokeMethod<void>('startWatcherService');
    } on MissingPluginException {
      // No native watcher on this platform yet.
    } on PlatformException {
      // Ignore: caller re-evaluates and retries on the next state change.
    }
  }

  Future<void> stopWatcherService() async {
    try {
      await _channel.invokeMethod<void>('stopWatcherService');
    } on MissingPluginException {
      // No native watcher on this platform yet.
    } on PlatformException {
      // Ignore.
    }
  }

  /// Pushes the global schedule rule (Phase 4) to native, which needs its
  /// own copy for the same reason [syncGuardedPackages] does.
  Future<void> syncScheduleRule(ScheduleRule rule) async {
    try {
      await _channel.invokeMethod<void>('syncScheduleRule', {
        'enabled': rule.enabled,
        'startMinutes': rule.startMinutes,
        'endMinutes': rule.endMinutes,
        'weekdays': rule.weekdays.toList(),
      });
    } on MissingPluginException {
      // No native watcher on this platform yet.
    } on PlatformException {
      // Best-effort sync; the next successful call will catch up.
    }
  }

  /// Pushes the set of packages that ignore [syncScheduleRule] and stay
  /// guarded around the clock.
  Future<void> syncAlwaysGuardPackages(Set<String> packageNames) async {
    try {
      await _channel.invokeMethod<void>('syncAlwaysGuardPackages', packageNames.toList());
    } on MissingPluginException {
      // No native watcher on this platform yet.
    } on PlatformException {
      // Best-effort sync; the next successful call will catch up.
    }
  }

  /// Pushes the "don't intervene until" timestamp (epoch millis, 0 = not
  /// paused) so the native watcher can suppress interventions during a
  /// temporary pause without needing to ask Dart on every poll.
  Future<void> syncPausedUntil(DateTime? until) async {
    try {
      await _channel.invokeMethod<void>('syncPausedUntil', until?.millisecondsSinceEpoch ?? 0);
    } on MissingPluginException {
      // No native watcher on this platform yet.
    } on PlatformException {
      // Best-effort sync; the next successful call will catch up.
    }
  }
}

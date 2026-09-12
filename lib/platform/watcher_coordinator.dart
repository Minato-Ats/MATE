import '../data/local/preferences_service.dart';
import 'installed_apps_bridge.dart';

/// Decides whether the native always-on foreground watcher should be
/// running, and keeps it in sync with the current guarded-package set.
///
/// The watcher should run exactly when there's something worth watching for
/// (at least one guarded app) and MATE is actually able to detect it
/// (usage access granted). This is re-evaluated from two independent
/// triggers — [AndroidGuardedAppsRepository] after every guard toggle, and
/// [UsageAccessController] after every permission refresh — rather than one
/// piece of code owning both signals, since they change independently.
class WatcherCoordinator {
  WatcherCoordinator({
    required InstalledAppsBridge bridge,
    required PreferencesService preferences,
  })  : _bridge = bridge, // ignore: prefer_initializing_formals
        _preferences = preferences; // ignore: prefer_initializing_formals

  final InstalledAppsBridge _bridge;
  final PreferencesService _preferences;

  Future<void>? _inFlight;

  /// At app startup, [AppState], [UsageAccessController] and
  /// [OverlayAccessController] each independently call this once — by
  /// design, since they react to different signals — which without this
  /// guard meant three near-simultaneous, redundant native calls (and, if
  /// the app happened to already be backgrounding at that exact moment,
  /// three identical failed attempts to start the watcher service). Callers
  /// that arrive while a call is already running just await that same one
  /// instead of starting another.
  Future<void> evaluate() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    final guardedPackages = _preferences.guardedPackageNames;
    final hasUsageAccess = await _bridge.hasUsageAccessPermission();
    // Also required: without a visible window at the moment a guarded app is
    // detected, Android blocks the service from launching the intervention
    // screen at all (see ForegroundWatcherService.showTransitionCover).
    final hasOverlayAccess = await _bridge.hasOverlayPermission();

    if (guardedPackages.isNotEmpty && hasUsageAccess && hasOverlayAccess) {
      await _bridge.syncGuardedPackages(guardedPackages);
      await _bridge.syncScheduleRule(_preferences.scheduleRule);
      await _bridge.syncAlwaysGuardPackages(_preferences.alwaysGuardPackages);
      await _bridge.syncPausedUntil(_preferences.pausedUntil);
      await _bridge.startWatcherService();
    } else {
      await _bridge.stopWatcherService();
    }
  }
}

import 'dart:async';

import '../local/preferences_service.dart';
import '../models/guarded_app.dart';
import '../models/installed_app.dart';
import '../../platform/installed_apps_bridge.dart';
import '../../platform/watcher_coordinator.dart';

/// Provides the list of apps MATE can guard, and persists which ones are on.
abstract class GuardedAppsRepository {
  Future<List<GuardedApp>> fetchApps();

  Future<void> setGuarded(String packageName, bool isGuarded);
}

/// Real implementation: reads installed apps from the OS via
/// [InstalledAppsBridge] and merges in the persisted on/off selection from
/// [PreferencesService]. This is the implementation used on-device; Phase 0
/// screens built against [GuardedAppsRepository] needed no changes to keep
/// working once this replaced the mock.
class AndroidGuardedAppsRepository implements GuardedAppsRepository {
  AndroidGuardedAppsRepository({
    required InstalledAppsBridge bridge,
    required PreferencesService preferences,
    required WatcherCoordinator watcherCoordinator,
  })  : _bridge = bridge, // ignore: prefer_initializing_formals
        _preferences = preferences, // ignore: prefer_initializing_formals
        _watcherCoordinator = watcherCoordinator; // ignore: prefer_initializing_formals

  final InstalledAppsBridge _bridge;
  final PreferencesService _preferences;
  final WatcherCoordinator _watcherCoordinator;

  @override
  Future<List<GuardedApp>> fetchApps() async {
    final installedApps = await _bridge.fetchInstalledApps();
    final guardedPackageNames = _preferences.guardedPackageNames;

    // Keep the native watcher's copy of the guarded set fresh on every load
    // (e.g. app restart), not just when the user flips a toggle.
    unawaited(_watcherCoordinator.evaluate());

    return installedApps
        .map((app) => _toGuardedApp(app, guardedPackageNames.contains(app.packageName)))
        .toList();
  }

  @override
  Future<void> setGuarded(String packageName, bool isGuarded) async {
    final current = _preferences.guardedPackageNames;
    final updated = isGuarded ? {...current, packageName} : (current..remove(packageName));
    await _preferences.setGuardedPackageNames(updated);
    await _watcherCoordinator.evaluate();
  }

  GuardedApp _toGuardedApp(InstalledApp app, bool isGuarded) {
    return GuardedApp(
      packageName: app.packageName,
      appName: app.appName,
      isGuarded: isGuarded,
      iconBytes: app.iconBytes,
    );
  }
}

/// Fixed, in-memory catalog used in widget tests and on platforms without a
/// native installed-apps implementation (there is no device to query).
class FakeGuardedAppsRepository implements GuardedAppsRepository {
  final List<GuardedApp> _apps = [
    const GuardedApp(packageName: 'com.instagram.android', appName: 'Instagram', isGuarded: true),
    const GuardedApp(packageName: 'com.zhiliaoapp.musically', appName: 'TikTok', isGuarded: true),
    const GuardedApp(packageName: 'com.twitter.android', appName: 'X', isGuarded: true),
    const GuardedApp(packageName: 'com.google.android.youtube', appName: 'YouTube', isGuarded: false),
  ];

  @override
  Future<List<GuardedApp>> fetchApps() async => List.unmodifiable(_apps);

  @override
  Future<void> setGuarded(String packageName, bool isGuarded) async {
    final index = _apps.indexWhere((app) => app.packageName == packageName);
    if (index == -1) return;
    _apps[index] = _apps[index].copyWith(isGuarded: isGuarded);
  }
}

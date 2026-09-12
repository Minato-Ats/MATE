import 'package:flutter/foundation.dart';

import '../platform/installed_apps_bridge.dart';
import '../platform/watcher_coordinator.dart';

/// Tracks whether the user has granted MATE the "Usage access" special
/// permission needed to detect the foreground app (Phase 1).
///
/// Granting happens in a system settings screen outside MATE, so callers
/// should [refresh] when the app resumes (e.g. after the user comes back
/// from Settings) rather than assuming a one-time check stays valid.
class UsageAccessController extends ChangeNotifier {
  UsageAccessController(this._bridge, this._watcherCoordinator);

  final InstalledAppsBridge _bridge;
  final WatcherCoordinator _watcherCoordinator;

  bool _hasAccess = false;
  bool get hasAccess => _hasAccess;

  Future<void> refresh() async {
    final value = await _bridge.hasUsageAccessPermission();
    if (value != _hasAccess) {
      _hasAccess = value;
      notifyListeners();
    }
    // Permission may have just been granted (or revoked) in system settings:
    // start/stop the watcher accordingly rather than waiting for the next
    // guarded-app toggle to notice.
    await _watcherCoordinator.evaluate();
  }

  Future<void> openSettings() => _bridge.openUsageAccessSettings();
}

import 'package:flutter/foundation.dart';

import '../platform/installed_apps_bridge.dart';
import '../platform/watcher_coordinator.dart';

/// Tracks whether the user has granted MATE "Display over other apps".
///
/// Required alongside usage access (see [UsageAccessController]) for the
/// Phase 2 watcher to actually show its intervention screen — without it,
/// Android's background-activity-start restrictions silently block the
/// launch. Granting happens in a system settings screen outside MATE, so
/// callers should [refresh] when the app resumes.
class OverlayAccessController extends ChangeNotifier {
  OverlayAccessController(this._bridge, this._watcherCoordinator);

  final InstalledAppsBridge _bridge;
  final WatcherCoordinator _watcherCoordinator;

  bool _hasAccess = false;
  bool get hasAccess => _hasAccess;

  Future<void> refresh() async {
    final value = await _bridge.hasOverlayPermission();
    if (value != _hasAccess) {
      _hasAccess = value;
      notifyListeners();
    }
    await _watcherCoordinator.evaluate();
  }

  Future<void> openSettings() => _bridge.openOverlaySettings();
}

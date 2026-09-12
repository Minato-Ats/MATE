import 'package:flutter/services.dart';

/// Which guarded app triggered the intervention screen, as reported by
/// [InterventionActivity] on the native side.
class InterventionArgs {
  const InterventionArgs({required this.packageName, required this.appName, this.iconBytes});

  factory InterventionArgs.fromMap(Map<Object?, Object?> map) {
    return InterventionArgs(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String? ?? map['packageName'] as String,
      iconBytes: map['icon'] as Uint8List?,
    );
  }

  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
}

/// Bridge used only by the separate intervention Flutter engine
/// (`intervention_main.dart`) to talk to [InterventionActivity].
///
/// This is a different channel from `app.mate/installed_apps` because it's
/// handled by a different native Activity (InterventionActivity, not
/// MainActivity) running in a different Flutter engine instance.
class InterventionBridge {
  InterventionBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('app.mate/intervention');

  final MethodChannel _channel;

  /// Fires whenever the native side reuses this screen for a *different*
  /// guarded app (the singleTask activity was already showing when another
  /// guarded app came to the foreground) — callers should re-fetch [getArgs].
  void setOnArgsChanged(VoidCallback callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'argsChanged') callback();
    });
  }

  Future<InterventionArgs?> getArgs() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>('getArgs');
    if (result == null || result['packageName'] == null) return null;
    return InterventionArgs.fromMap(result);
  }

  /// User chose to proceed: native launches [packageName] and marks it
  /// bypassed so the watcher doesn't immediately re-trigger.
  Future<void> resolveOpen(String packageName) {
    return _channel.invokeMethod<void>('resolveOpen', {'packageName': packageName});
  }

  /// User chose not to proceed: native returns to the home screen.
  Future<void> resolveGiveUp() {
    return _channel.invokeMethod<void>('resolveGiveUp');
  }

  /// Tells the native side this screen has actually drawn a real frame, so
  /// it can remove the transition cover it showed while launching this
  /// Activity. Call this right after the first frame with real content
  /// (icon/text/buttons) is painted — not merely after `setState`, since a
  /// `setState` call schedules a frame but doesn't guarantee one has been
  /// drawn yet by the time this returns. See ForegroundWatcherService.kt's
  /// `hideTransitionCoverIfShowing` for why a fixed timer isn't good enough.
  Future<void> notifyReady() {
    return _channel.invokeMethod<void>('readyToShow');
  }
}

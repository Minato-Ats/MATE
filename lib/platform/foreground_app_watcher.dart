import 'package:flutter/services.dart';

import '../data/models/foreground_event.dart';

/// Streams "app came to the foreground" events reported by the OS.
///
/// Backed by Android `UsageStatsManager` polling on the native side (see
/// `MainActivity.kt`); emits nothing on platforms without an implementation
/// (e.g. iOS today) or before the user grants usage access.
///
/// This is Phase 1's technical proof that MATE can detect a guarded app
/// being opened. The actual "wait / open / give up" intervention UI is
/// built in Phase 2 on top of this signal.
class ForegroundAppWatcher {
  ForegroundAppWatcher({EventChannel? channel})
      : _channel = channel ?? const EventChannel('app.mate/foreground_events');

  final EventChannel _channel;

  Stream<ForegroundEvent>? _stream;

  Stream<ForegroundEvent> get onForegroundAppChanged {
    return _stream ??= _channel.receiveBroadcastStream().map(
          (event) => ForegroundEvent.fromMap(event as Map<Object?, Object?>),
        );
  }
}

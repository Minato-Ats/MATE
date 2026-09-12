import 'package:flutter/foundation.dart';

/// A single "app came to the foreground" transition reported by the OS.
@immutable
class ForegroundEvent {
  const ForegroundEvent({required this.packageName, required this.timestamp});

  factory ForegroundEvent.fromMap(Map<Object?, Object?> map) {
    return ForegroundEvent(
      packageName: map['packageName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  final String packageName;
  final DateTime timestamp;
}

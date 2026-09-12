import 'package:flutter/foundation.dart';

/// The four moments Phase 2's intervention screen can produce, recorded so
/// Phase 3 can aggregate them into real statistics without needing to
/// change how they're captured.
class InterventionEventType {
  InterventionEventType._();

  /// A guarded app was detected coming to the foreground and the
  /// intervention screen was shown.
  static const detected = 'detected';

  /// The configured wait time finished (independent of what the user
  /// chooses afterward).
  static const waitCompleted = 'wait_completed';

  /// The user chose to proceed into the guarded app.
  static const opened = 'opened';

  /// The user chose not to proceed.
  static const gaveUp = 'gave_up';
}

@immutable
class InterventionEvent {
  const InterventionEvent({
    required this.type,
    required this.packageName,
    required this.timestamp,
  });

  factory InterventionEvent.fromJson(Map<String, dynamic> json) {
    return InterventionEvent(
      type: json['type'] as String,
      packageName: json['packageName'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  final String type;
  final String packageName;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'type': type,
        'packageName': packageName,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

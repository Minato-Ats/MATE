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

  // 本気モード (Serious Mode, Phase 6.6) events — a distinct, stricter
  // intervention flow. Recorded for future stats use only; existing
  // aggregation (`StatsRepository._bucketByDay`) safely ignores unrecognized
  // types, so no other stats code needs to change for these to be logged.

  /// The serious-mode reason step ("何のために開く？") was shown.
  static const seriousModeStarted = 'serious_mode_started';

  /// The user answered "今必要" (YES) to "それ、今必要？".
  static const seriousModeYes = 'serious_mode_yes';

  /// The user answered "今必要ではない" (NO) to "それ、今必要？".
  static const seriousModeNo = 'serious_mode_no';

  /// After a NO answer, the user chose "やめとく" — no penalty increase.
  static const seriousModeGaveUp = 'serious_mode_gave_up';

  /// After a NO answer, the user chose "それでも開く" — escalates the shared
  /// cumulative wait for every guarded app's next trigger.
  static const seriousModeOpenAnyway = 'serious_mode_open_anyway';
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

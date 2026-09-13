import 'package:flutter/foundation.dart';

/// The "本気モード" (Serious Mode) cumulative-friction state: how long the
/// next "それでも開く" (open anyway) wait will be, shared across *every*
/// guarded app — not per-app — so switching targets can't be used to dodge
/// it (see Phase 6.6's design: X → YouTube → Instagram keeps escalating,
/// it doesn't reset).
///
/// Deliberately a pure, no-IO model: every method takes `now` as an
/// explicit parameter instead of calling `DateTime.now()` itself, so the
/// escalate/reset timing (in particular the 1-hour reset window) is
/// trivially testable with fixed `DateTime` values rather than needing a
/// mocked clock or a real hour-long wait.
@immutable
class SeriousModeEscalation {
  const SeriousModeEscalation({required this.pendingSeconds, required this.lastOpenAnywayAt});

  /// Fresh/never-escalated state: the first "それでも開く" costs
  /// [initialSeconds].
  static const initial = SeriousModeEscalation(pendingSeconds: initialSeconds, lastOpenAnywayAt: null);

  /// What the *next* "それでも開く" will cost, before accounting for the
  /// 1-hour reset window (see [effectiveWaitSeconds]) — the raw persisted
  /// value.
  final int pendingSeconds;

  /// When the last "それでも開く" happened, across any guarded app. `null`
  /// if it has never happened (or was reset).
  final DateTime? lastOpenAnywayAt;

  static const int initialSeconds = 15;
  static const int stepSeconds = 15;
  static const int maxSeconds = 3600;
  static const Duration resetAfter = Duration(hours: 1);

  /// The wait that would be applied *right now* if the user chose "それで
  /// も開く" — [pendingSeconds], unless more than [resetAfter] has passed
  /// since [lastOpenAnywayAt], in which case the escalation has cooled all
  /// the way back down to [initialSeconds].
  int effectiveWaitSeconds(DateTime now) {
    final last = lastOpenAnywayAt;
    if (last == null) return initialSeconds;
    if (now.difference(last) >= resetAfter) return initialSeconds;
    return pendingSeconds;
  }

  /// The new state after the user explicitly chooses "それでも開く" at
  /// [now]. Only ever called from that one choice — detecting a guarded
  /// app, or choosing "やめとく", must never call this.
  SeriousModeEscalation afterOpenAnyway(DateTime now) {
    final applied = effectiveWaitSeconds(now);
    final next = (applied + stepSeconds).clamp(initialSeconds, maxSeconds);
    return SeriousModeEscalation(pendingSeconds: next, lastOpenAnywayAt: now);
  }

  factory SeriousModeEscalation.fromJson(Map<String, dynamic> json) {
    final lastMs = json['lastOpenAnywayAtMs'] as int?;
    return SeriousModeEscalation(
      pendingSeconds: json['pendingSeconds'] as int? ?? initialSeconds,
      lastOpenAnywayAt: lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs),
    );
  }

  Map<String, dynamic> toJson() => {
        'pendingSeconds': pendingSeconds,
        'lastOpenAnywayAtMs': lastOpenAnywayAt?.millisecondsSinceEpoch,
      };
}

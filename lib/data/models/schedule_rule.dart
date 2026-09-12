import 'package:flutter/foundation.dart';

/// When MATE should actively guard apps, expressed as a time-of-day window
/// plus which days of the week it applies on.
///
/// This is a single *global* rule (see `PreferencesService.scheduleRule`) —
/// deliberately not a per-app schedule, to keep the settings UI from
/// exploding into a grid of time pickers. Individual apps can instead be
/// marked to always ignore it (see `alwaysGuardPackages`), which covers the
/// common "actually, guard this one all the time" case without needing a
/// second full schedule.
@immutable
class ScheduleRule {
  const ScheduleRule({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.weekdays,
  });

  /// Off by default: until a user deliberately opts in, MATE guards
  /// around the clock, every day — the schedule only narrows that.
  static const disabled = ScheduleRule(
    enabled: false,
    startMinutes: 8 * 60,
    endMinutes: 22 * 60,
    weekdays: {1, 2, 3, 4, 5, 6, 7},
  );

  final bool enabled;

  /// Minutes since midnight, 0-1439.
  final int startMinutes;
  final int endMinutes;

  /// ISO weekday numbers (1 = Monday .. 7 = Sunday) this rule applies on.
  /// Defaults to all seven — turning the schedule on only narrows the
  /// *time of day* until the user also deliberately narrows the days, so
  /// enabling it never silently stops guarding on, say, a Tuesday.
  final Set<int> weekdays;

  /// Whether [dateTime] falls inside this rule's active window. Handles an
  /// overnight window (e.g. 22:00-02:00) by wrapping past midnight.
  bool isActiveAt(DateTime dateTime) {
    if (!enabled) return true;
    if (!weekdays.contains(dateTime.weekday)) return false;

    final minutesOfDay = dateTime.hour * 60 + dateTime.minute;
    if (startMinutes <= endMinutes) {
      return minutesOfDay >= startMinutes && minutesOfDay < endMinutes;
    }
    // Overnight window: active from start through midnight, then midnight
    // through end.
    return minutesOfDay >= startMinutes || minutesOfDay < endMinutes;
  }

  ScheduleRule copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    Set<int>? weekdays,
  }) {
    return ScheduleRule(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      weekdays: weekdays ?? this.weekdays,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'start': startMinutes,
        'end': endMinutes,
        'weekdays': weekdays.toList(),
      };

  factory ScheduleRule.fromJson(Map<String, dynamic> json) {
    return ScheduleRule(
      enabled: json['enabled'] as bool,
      startMinutes: json['start'] as int,
      endMinutes: json['end'] as int,
      weekdays: (json['weekdays'] as List<dynamic>).map((e) => e as int).toSet(),
    );
  }
}

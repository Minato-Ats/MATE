import 'package:flutter_test/flutter_test.dart';
import 'package:mate/data/models/schedule_rule.dart';
import 'package:mate/data/models/strict_mode_guard.dart';

void main() {
  group('ScheduleRule', () {
    test('disabled schedule is always active', () {
      expect(ScheduleRule.disabled.isActiveAt(DateTime(2026, 9, 14, 3)), isTrue);
    });

    test('same-day window respects weekday and time', () {
      const rule = ScheduleRule(
        enabled: true,
        startMinutes: 18 * 60,
        endMinutes: 23 * 60,
        weekdays: {DateTime.monday},
      );

      expect(rule.isActiveAt(DateTime(2026, 9, 14, 20)), isTrue); // Monday
      expect(rule.isActiveAt(DateTime(2026, 9, 14, 17)), isFalse);
      expect(rule.isActiveAt(DateTime(2026, 9, 15, 20)), isFalse); // Tuesday
    });

    test('overnight tail belongs to previous weekday', () {
      const rule = ScheduleRule(
        enabled: true,
        startMinutes: 22 * 60,
        endMinutes: 2 * 60,
        weekdays: {DateTime.monday},
      );

      expect(rule.isActiveAt(DateTime(2026, 9, 14, 23)), isTrue); // Monday
      expect(rule.isActiveAt(DateTime(2026, 9, 15, 1)), isTrue); // Tuesday tail
      expect(rule.isActiveAt(DateTime(2026, 9, 15, 23)), isFalse);
    });
  });

  group('StrictModeGuard', () {
    test('all wait choices are available when strict mode is off', () {
      expect(
        StrictModeGuard.selectableWaitSeconds([3, 5, 10, 30], 10, strictModeEnabled: false),
        [3, 5, 10, 30],
      );
    });

    test('strict mode only allows same or longer waits', () {
      expect(
        StrictModeGuard.selectableWaitSeconds([3, 5, 10, 30], 10, strictModeEnabled: true),
        [10, 30],
      );
    });
  });
}

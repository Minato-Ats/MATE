import 'package:flutter/foundation.dart';

import 'daily_stats.dart';

/// Aggregated stats used by the Home and Stats screens.
@immutable
class StatsSummary {
  const StatsSummary({
    required this.today,
    required this.last7Days,
    required this.currentStreakDays,
    required this.totalMinutesSavedAllTime,
    required this.monthlyTemptationsWon,
    required this.monthlyLaunchAttempts,
    required this.monthlyMinutesSaved,
  });

  final DailyStats today;

  /// Oldest first, exactly 7 entries ending with [today].
  final List<DailyStats> last7Days;

  final int currentStreakDays;
  final int totalMinutesSavedAllTime;

  /// Rolling last-30-days totals (not calendar-month-to-date — simpler to
  /// reason about and avoids a near-empty count on the 1st of the month).
  final int monthlyTemptationsWon;
  final int monthlyLaunchAttempts;
  final int monthlyMinutesSaved;

  int get weeklyTemptationsWon =>
      last7Days.fold(0, (sum, day) => sum + day.temptationsWon);

  int get weeklyMinutesSaved =>
      last7Days.fold(0, (sum, day) => sum + day.minutesSaved);
}

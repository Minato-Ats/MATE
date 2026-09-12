import '../local/preferences_service.dart';
import '../models/daily_stats.dart';
import '../models/intervention_event.dart';
import '../models/stats_summary.dart';

/// Supplies MATE's usage statistics.
abstract class StatsRepository {
  Future<StatsSummary> fetchSummary();
}

/// Estimates time saved by resisting a guarded app.
///
/// Phase 3 has no real per-app session-length data yet (that would need
/// tracking how long the user typically stays in each app once opened, via
/// `UsageStatsManager`'s per-app foreground time). Until that exists, this
/// uses a single, clearly-labeled assumption so the number shown is at
/// least explainable and consistent rather than arbitrary. Swap
/// [assumedMinutesPerResistedOpen] for a real per-app average here later —
/// every caller goes through this one function.
class SaveTimeEstimator {
  SaveTimeEstimator._();

  /// Rough average session length for the kind of app MATE guards
  /// (social/video/games), used as a stand-in until real per-app usage
  /// duration data is available.
  static const assumedMinutesPerResistedOpen = 5;

  static int estimateMinutesSaved(int resistedCount) => resistedCount * assumedMinutesPerResistedOpen;
}

/// Real implementation: reads Phase 2's local event log and aggregates it
/// into daily/weekly/monthly figures. No server, no analytics SDK — every
/// number here is computed from events already stored on-device.
class RealStatsRepository implements StatsRepository {
  RealStatsRepository(this._preferences);

  final PreferencesService _preferences;

  @override
  Future<StatsSummary> fetchSummary() async {
    final events = await _preferences.loadEventLog();
    final buckets = _bucketByDay(events);
    final today = _dateOnly(DateTime.now());

    final last7Days = List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      final counts = buckets[date] ?? const _DayCounts();
      return DailyStats(
        date: date,
        temptationsWon: counts.gaveUp,
        launchAttempts: counts.detected,
        minutesSaved: SaveTimeEstimator.estimateMinutesSaved(counts.gaveUp),
      );
    });

    var monthlyWon = 0;
    var monthlyAttempts = 0;
    for (var i = 0; i < 30; i++) {
      final counts = buckets[today.subtract(Duration(days: i))] ?? const _DayCounts();
      monthlyWon += counts.gaveUp;
      monthlyAttempts += counts.detected;
    }

    final totalGaveUp = events.where((e) => e.type == InterventionEventType.gaveUp).length;

    return StatsSummary(
      today: last7Days.last,
      last7Days: last7Days,
      currentStreakDays: _computeStreak(buckets, today),
      totalMinutesSavedAllTime: SaveTimeEstimator.estimateMinutesSaved(totalGaveUp),
      monthlyTemptationsWon: monthlyWon,
      monthlyLaunchAttempts: monthlyAttempts,
      monthlyMinutesSaved: SaveTimeEstimator.estimateMinutesSaved(monthlyWon),
    );
  }

  Map<DateTime, _DayCounts> _bucketByDay(List<InterventionEvent> events) {
    final buckets = <DateTime, _DayCounts>{};
    for (final event in events) {
      final day = _dateOnly(event.timestamp);
      final current = buckets[day] ?? const _DayCounts();
      buckets[day] = switch (event.type) {
        InterventionEventType.detected => current.copyWith(detected: current.detected + 1),
        InterventionEventType.gaveUp => current.copyWith(gaveUp: current.gaveUp + 1),
        InterventionEventType.opened => current.copyWith(opened: current.opened + 1),
        InterventionEventType.waitCompleted => current.copyWith(waitCompleted: current.waitCompleted + 1),
        _ => current,
      };
    }
    return buckets;
  }

  /// Consecutive days, counting back from today, with zero "開く" (opened)
  /// events — i.e. days you didn't give in. A day with no MATE activity at
  /// all still counts (nothing to resist isn't a loss), but the streak never
  /// extends further back than the first day MATE ever recorded anything,
  /// so an unused install doesn't show a misleadingly large streak.
  int _computeStreak(Map<DateTime, _DayCounts> buckets, DateTime today) {
    if (buckets.isEmpty) return 0;
    final earliestDay = buckets.keys.reduce((a, b) => a.isBefore(b) ? a : b);

    var streak = 0;
    var day = today;
    while (!day.isBefore(earliestDay)) {
      final counts = buckets[day] ?? const _DayCounts();
      if (counts.opened > 0) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _dateOnly(DateTime dateTime) => DateTime(dateTime.year, dateTime.month, dateTime.day);
}

class _DayCounts {
  const _DayCounts({this.detected = 0, this.gaveUp = 0, this.opened = 0, this.waitCompleted = 0});

  final int detected;
  final int gaveUp;
  final int opened;
  final int waitCompleted;

  _DayCounts copyWith({int? detected, int? gaveUp, int? opened, int? waitCompleted}) {
    return _DayCounts(
      detected: detected ?? this.detected,
      gaveUp: gaveUp ?? this.gaveUp,
      opened: opened ?? this.opened,
      waitCompleted: waitCompleted ?? this.waitCompleted,
    );
  }
}

/// Fixed mock data used only in widget tests, where there is no real event
/// history to compute from.
class MockStatsRepository implements StatsRepository {
  @override
  Future<StatsSummary> fetchSummary() async {
    final today = DateTime.now();
    // A deterministic-but-varied week so the weekly chart doesn't look flat.
    const wins = [4, 7, 3, 9, 6, 8, 8];
    const attempts = [6, 9, 5, 11, 8, 9, 10];
    const minutes = [12, 21, 9, 26, 18, 24, 23];

    final last7Days = List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      return DailyStats(
        date: DateTime(date.year, date.month, date.day),
        temptationsWon: wins[i],
        launchAttempts: attempts[i],
        minutesSaved: minutes[i],
      );
    });

    return StatsSummary(
      today: last7Days.last,
      last7Days: last7Days,
      currentStreakDays: 5,
      totalMinutesSavedAllTime: 842,
      monthlyTemptationsWon: wins.fold(0, (a, b) => a + b) * 4,
      monthlyLaunchAttempts: attempts.fold(0, (a, b) => a + b) * 4,
      monthlyMinutesSaved: minutes.fold(0, (a, b) => a + b) * 4,
    );
  }
}

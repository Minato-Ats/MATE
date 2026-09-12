// Unit tests for Phase 3's real event-log-driven statistics: this is the
// core "does the math match the events" correctness check that a UI/widget
// test on the emulator can't easily exercise.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:mate/data/local/preferences_service.dart';
import 'package:mate/data/models/intervention_event.dart';
import 'package:mate/data/repositories/stats_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // appendEvent/loadEventLog use SharedPreferencesAsync (see
    // preferences_service.dart for why); that API needs its own platform
    // fake — SharedPreferences.setMockInitialValues only covers the legacy
    // cached API used for everything else in this class.
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  DateTime daysAgo(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - days, 12);
  }

  test('today with no events shows zeros, not mock placeholders', () async {
    final preferences = await PreferencesService.create();
    final repository = RealStatsRepository(preferences);

    final summary = await repository.fetchSummary();

    expect(summary.today.launchAttempts, 0);
    expect(summary.today.temptationsWon, 0);
    expect(summary.today.minutesSaved, 0);
    expect(summary.currentStreakDays, 0);
    expect(summary.totalMinutesSavedAllTime, 0);
  });

  test('detected/gave_up/opened events aggregate into today\'s stats', () async {
    final preferences = await PreferencesService.create();
    final today = daysAgo(0);

    // Two interventions today: one resisted, one given in to.
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: today));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: today));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'b', timestamp: today));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.opened, packageName: 'b', timestamp: today));

    final summary = await RealStatsRepository(preferences).fetchSummary();

    expect(summary.today.launchAttempts, 2, reason: 'two "detected" events today');
    expect(summary.today.temptationsWon, 1, reason: 'one "gave_up" event today');
    expect(summary.today.winRate, 0.5);
    expect(summary.today.minutesSaved, SaveTimeEstimator.estimateMinutesSaved(1));
  });

  test('streak counts consecutive no-open days back from today and stops at an open', () async {
    final preferences = await PreferencesService.create();

    // 3 days ago: resisted (streak day). 2 days ago: gave in (breaks streak
    // before that point). Yesterday and today: resisted.
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(3)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: daysAgo(3)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(2)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.opened, packageName: 'a', timestamp: daysAgo(2)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(1)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: daysAgo(1)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(0)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: daysAgo(0)));

    final summary = await RealStatsRepository(preferences).fetchSummary();

    // Today and yesterday have no "opened" -> streak of 2, broken by the
    // "opened" 2 days ago.
    expect(summary.currentStreakDays, 2);
  });

  test('opening the guarded app today resets the streak to zero', () async {
    final preferences = await PreferencesService.create();
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(0)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.opened, packageName: 'a', timestamp: daysAgo(0)));

    final summary = await RealStatsRepository(preferences).fetchSummary();

    expect(summary.currentStreakDays, 0);
  });

  test('monthly totals sum the last 30 days, and events older than that are excluded', () async {
    final preferences = await PreferencesService.create();
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(10)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: daysAgo(10)));
    // Outside the 30-day window: must not be counted.
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(40)));
    await preferences.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: daysAgo(40)));

    final summary = await RealStatsRepository(preferences).fetchSummary();

    expect(summary.monthlyTemptationsWon, 1);
    // All-time total still includes the 40-day-old event.
    expect(summary.totalMinutesSavedAllTime, SaveTimeEstimator.estimateMinutesSaved(2));
  });

  test('stats persist across a fresh PreferencesService instance (simulates app restart)', () async {
    final first = await PreferencesService.create();
    await first.appendEvent(InterventionEvent(type: InterventionEventType.detected, packageName: 'a', timestamp: daysAgo(0)));
    await first.appendEvent(InterventionEvent(type: InterventionEventType.gaveUp, packageName: 'a', timestamp: daysAgo(0)));

    // A brand new instance, as main() creates on the next app launch.
    final second = await PreferencesService.create();
    final summary = await RealStatsRepository(second).fetchSummary();

    expect(summary.today.temptationsWon, 1);
  });
}

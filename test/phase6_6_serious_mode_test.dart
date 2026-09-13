// Phase 6.6 ("MATEコア体験強化") tests: the shared, cross-app escalating
// "それでも開く" penalty, its 1-hour reset, goal/本気モード persistence, the
// categorized anti-fatigue message picker, and the SeriousModeFlow widget's
// step-by-step branching.
//
// Time-dependent behavior (in particular the 1-hour reset window) is tested
// by passing fixed `DateTime` values directly to the model/PreferencesService
// APIs — both are designed to take `now` as an explicit parameter rather
// than calling `DateTime.now()` internally, so no real wait is needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:mate/core/copy/serious_mode_templates.dart';
import 'package:mate/core/time/clock.dart';
import 'package:mate/data/local/preferences_service.dart';
import 'package:mate/data/models/intervention_event.dart';
import 'package:mate/data/models/serious_mode_escalation.dart';
import 'package:mate/features/intervention/serious_mode/serious_mode_flow.dart';
import 'package:mate/platform/intervention_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  group('SeriousModeEscalation (pure model)', () {
    final t0 = DateTime(2026, 1, 1, 12, 0);

    test('initial state costs 15 seconds', () {
      expect(SeriousModeEscalation.initial.effectiveWaitSeconds(t0), 15);
    });

    test('escalates by 15s per それでも開く: 15 -> 30 -> 45 -> 60', () {
      var state = SeriousModeEscalation.initial;
      state = state.afterOpenAnyway(t0);
      expect(state.pendingSeconds, 30);
      state = state.afterOpenAnyway(t0.add(const Duration(minutes: 1)));
      expect(state.pendingSeconds, 45);
      state = state.afterOpenAnyway(t0.add(const Duration(minutes: 2)));
      expect(state.pendingSeconds, 60);
      state = state.afterOpenAnyway(t0.add(const Duration(minutes: 3)));
      expect(state.pendingSeconds, 75);
    });

    test('never exceeds the 3600s cap', () {
      var state = SeriousModeEscalation.initial;
      var now = t0;
      for (var i = 0; i < 400; i++) {
        now = now.add(const Duration(minutes: 1));
        state = state.afterOpenAnyway(now);
        expect(state.pendingSeconds, lessThanOrEqualTo(3600));
      }
      expect(state.pendingSeconds, 3600);
    });

    test('less than 1 hour since last それでも開く does not reset', () {
      var state = SeriousModeEscalation.initial;
      state = state.afterOpenAnyway(t0); // -> next costs 30
      state = state.afterOpenAnyway(t0.add(const Duration(minutes: 5))); // -> next costs 45
      final justUnder1h = t0.add(const Duration(minutes: 5)).add(const Duration(minutes: 59));
      expect(state.effectiveWaitSeconds(justUnder1h), 45);
    });

    test('1+ hour since last それでも開く resets the next cost to 15', () {
      var state = SeriousModeEscalation.initial;
      state = state.afterOpenAnyway(t0); // pending -> 30
      state = state.afterOpenAnyway(t0.add(const Duration(minutes: 5))); // pending -> 45
      final oneHourLater = t0.add(const Duration(minutes: 5)).add(const Duration(hours: 1));
      expect(state.effectiveWaitSeconds(oneHourLater), 15);
    });

    test('a que それでも開く after the reset window escalates from 15 again, not from the stale pending value', () {
      var state = SeriousModeEscalation.initial;
      state = state.afterOpenAnyway(t0); // pending -> 30, last=t0
      final wayLater = t0.add(const Duration(hours: 2));
      state = state.afterOpenAnyway(wayLater);
      expect(state.pendingSeconds, 30); // 15 (reset) + 15 step, not 30+15=45
    });
  });

  group('PreferencesService: goal + 本気モード + escalation persistence', () {
    test('goal defaults to null and MATE works without one set', () async {
      final prefs = await PreferencesService.create();
      expect(prefs.goal, isNull);
    });

    test('goal save/load round-trips and trims whitespace', () async {
      final prefs = await PreferencesService.create();
      await prefs.setGoal('  宅建に合格する  ');
      expect(prefs.goal, '宅建に合格する');
    });

    test('clearing the goal back to empty removes it', () async {
      final prefs = await PreferencesService.create();
      await prefs.setGoal('5kg痩せる');
      await prefs.setGoal('   ');
      expect(prefs.goal, isNull);
    });

    test('本気モード defaults to OFF for both new and existing users', () async {
      final prefs = await PreferencesService.create();
      expect(prefs.seriousModeEnabled, isFalse);
    });

    test('serious mode escalation defaults to the initial (15s) state', () async {
      final prefs = await PreferencesService.create();
      final state = await prefs.loadSeriousModeEscalation();
      expect(state.pendingSeconds, SeriousModeEscalation.initialSeconds);
      expect(state.lastOpenAnywayAt, isNull);
      expect(await prefs.effectiveSeriousModeWaitSeconds(DateTime(2026, 1, 1)), 15);
    });

    test('recordSeriousModeOpenAnyway escalates and is shared across different guarded apps', () async {
      final prefs = await PreferencesService.create();
      final t0 = DateTime(2026, 1, 1, 10, 0);

      // X -> 15s (first ever), then YouTube -> 30s, then Instagram -> 45s,
      // then TikTok -> 60s — the same shared counter regardless of which
      // app's intervention triggered it (recordSeriousModeOpenAnyway takes
      // no packageName at all, by design).
      expect(await prefs.effectiveSeriousModeWaitSeconds(t0), 15);
      await prefs.recordSeriousModeOpenAnyway(t0);

      final t1 = t0.add(const Duration(minutes: 2));
      expect(await prefs.effectiveSeriousModeWaitSeconds(t1), 30);
      await prefs.recordSeriousModeOpenAnyway(t1);

      final t2 = t1.add(const Duration(minutes: 2));
      expect(await prefs.effectiveSeriousModeWaitSeconds(t2), 45);
      await prefs.recordSeriousModeOpenAnyway(t2);

      final t3 = t2.add(const Duration(minutes: 2));
      expect(await prefs.effectiveSeriousModeWaitSeconds(t3), 60);
    });

    test('switching guarded apps does not reset the cumulative wait (no per-app reset)', () async {
      final prefs = await PreferencesService.create();
      final t0 = DateTime(2026, 1, 1, 10, 0);
      await prefs.recordSeriousModeOpenAnyway(t0); // pending -> 30
      // A different app's trigger a moment later must see the same escalated
      // value, not a fresh 15s.
      final laterSameHour = t0.add(const Duration(minutes: 10));
      expect(await prefs.effectiveSeriousModeWaitSeconds(laterSameHour), 30);
    });

    test('under 1 hour since the last それでも開く: no reset', () async {
      final prefs = await PreferencesService.create();
      final t0 = DateTime(2026, 1, 1, 10, 0);
      await prefs.recordSeriousModeOpenAnyway(t0); // pending -> 30
      final t1 = t0.add(const Duration(minutes: 30));
      expect(await prefs.effectiveSeriousModeWaitSeconds(t1), 30);
    });

    test('1+ hour since the last それでも開く: resets to 15', () async {
      final prefs = await PreferencesService.create();
      final t0 = DateTime(2026, 1, 1, 10, 0);
      await prefs.recordSeriousModeOpenAnyway(t0); // pending -> 30
      final t1 = t0.add(const Duration(hours: 1, minutes: 1));
      expect(await prefs.effectiveSeriousModeWaitSeconds(t1), 15);
    });

    test('escalation state persists across a fresh PreferencesService instance (simulates app/process restart)', () async {
      final first = await PreferencesService.create();
      final t0 = DateTime(2026, 1, 1, 10, 0);
      await first.recordSeriousModeOpenAnyway(t0);
      await first.recordSeriousModeOpenAnyway(t0.add(const Duration(minutes: 1)));

      // A brand new instance, exactly as main() creates on the next launch —
      // also stands in for "survives device reboot", since both go through
      // the same persisted-storage read path with no in-memory-only state.
      final second = await PreferencesService.create();
      expect(
        await second.effectiveSeriousModeWaitSeconds(t0.add(const Duration(minutes: 2))),
        45,
      );
    });

    test('max wait ever reached is tracked for future stats use', () async {
      final prefs = await PreferencesService.create();
      final t0 = DateTime(2026, 1, 1, 10, 0);
      await prefs.recordSeriousModeOpenAnyway(t0);
      await prefs.recordSeriousModeOpenAnyway(t0.add(const Duration(minutes: 1)));
      expect(await prefs.seriousModeMaxWaitSecondsReached, 45);
    });

    test('message history caps at 20 entries', () async {
      final prefs = await PreferencesService.create();
      for (var i = 0; i < 25; i++) {
        await prefs.pushSeriousModeMessageId('id_$i');
      }
      final history = await prefs.loadSeriousModeMessageHistory();
      expect(history.length, 20);
      expect(history.first, 'id_5'); // oldest 5 trimmed off
      expect(history.last, 'id_24');
    });
  });

  group('SeriousModeCopy (categorized anti-fatigue templates)', () {
    test('never repeats the immediately-previous NO-branch line', () async {
      final prefs = await PreferencesService.create();
      const ctx = SeriousModeTemplateContext(reason: '暇つぶし', goal: '宅建に合格する', todayCount: 3, waitSeconds: 30);

      String? previous;
      for (var i = 0; i < 30; i++) {
        final line = await SeriousModeCopy.pickNoSting(prefs, ctx);
        expect(line, isNotEmpty);
        if (previous != null) expect(line, isNot(previous));
        previous = line;
      }
    });

    test('reason and goal placeholders are actually substituted', () async {
      final prefs = await PreferencesService.create();
      const ctx = SeriousModeTemplateContext(reason: '返信', goal: '転職活動を終わらせる', todayCount: 1, waitSeconds: 15);

      var sawReason = false;
      var sawGoal = false;
      for (var i = 0; i < 60; i++) {
        final line = await SeriousModeCopy.pickNoSting(prefs, ctx);
        if (line.contains('返信')) sawReason = true;
        if (line.contains('転職活動を終わらせる')) sawGoal = true;
      }
      expect(sawReason, isTrue, reason: 'reason-based templates should show up over many draws');
      expect(sawGoal, isTrue, reason: 'goal-based templates should show up over many draws');
    });

    test('YES-branch ack never stings and echoes the typed reason', () async {
      final prefs = await PreferencesService.create();
      const ctx = SeriousModeTemplateContext(reason: '仕事の確認', goal: null, todayCount: 1, waitSeconds: 0);
      final line = await SeriousModeCopy.pickYesAck(prefs, ctx);
      expect(line, contains('仕事の確認'));
    });
  });

  group('SeriousModeFlow widget', () {
    Widget wrap(Widget child) => MaterialApp(home: child);

    const args = InterventionArgs(packageName: 'com.example.target', appName: 'TargetApp');

    testWidgets('reason step requires non-empty input before continuing', (tester) async {
      final prefs = await PreferencesService.create();
      await tester.pumpWidget(wrap(SeriousModeFlow(
        args: args,
        preferences: prefs,
        normalWaitSeconds: 0,
        onGiveUp: () async {},
        onOpen: () async {},
        clock: Clock.fixed(DateTime(2026, 1, 1, 10)),
      )));
      await tester.pumpAndSettle();

      expect(find.text('何のために開く？'), findsOneWidget);
      await tester.tap(find.text('つぎへ'));
      await tester.pump();
      expect(find.text('それ、今必要？'), findsNothing, reason: 'empty reason must not be allowed to proceed');
    });

    testWidgets('YES branch: never escalates, uses the normal wait, and calls onOpen', (tester) async {
      final prefs = await PreferencesService.create();
      var opened = false;
      var gaveUp = false;

      await tester.pumpWidget(wrap(SeriousModeFlow(
        args: args,
        preferences: prefs,
        normalWaitSeconds: 0, // 0 so the wait completes immediately, no pumping needed
        onGiveUp: () async => gaveUp = true,
        onOpen: () async => opened = true,
        clock: Clock.fixed(DateTime(2026, 1, 1, 10)),
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '動画を見る');
      await tester.tap(find.text('つぎへ'));
      await tester.pumpAndSettle();

      expect(find.text('それ、今必要？'), findsOneWidget);
      await tester.tap(find.text('必要'));
      await tester.pumpAndSettle();

      // Light wait (0s) should already show 開く enabled.
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
      expect(gaveUp, isFalse);
      // The YES route must never touch the shared escalation counter.
      expect(await prefs.effectiveSeriousModeWaitSeconds(DateTime(2026, 1, 1, 10)), 15);
    });

    testWidgets('NO branch + やめとく: gives up immediately, no penalty increase', (tester) async {
      final prefs = await PreferencesService.create();
      var opened = false;
      var gaveUp = false;

      await tester.pumpWidget(wrap(SeriousModeFlow(
        args: args,
        preferences: prefs,
        normalWaitSeconds: 5,
        onGiveUp: () async => gaveUp = true,
        onOpen: () async => opened = true,
        clock: Clock.fixed(DateTime(2026, 1, 1, 10)),
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '暇つぶし');
      await tester.tap(find.text('つぎへ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('必要ない'));
      await tester.pumpAndSettle();

      // A sting message should now be showing with やめとく/それでも開く.
      expect(find.text('やめとく'), findsOneWidget);
      expect(find.text('それでも開く'), findsOneWidget);

      await tester.tap(find.text('やめとく'));
      await tester.pumpAndSettle();

      expect(gaveUp, isTrue);
      expect(opened, isFalse);
      expect(await prefs.effectiveSeriousModeWaitSeconds(DateTime(2026, 1, 1, 10)), 15);

      final events = await prefs.loadEventLog();
      expect(events.any((e) => e.type == InterventionEventType.seriousModeGaveUp), isTrue);
      expect(events.any((e) => e.type == InterventionEventType.seriousModeOpenAnyway), isFalse);
    });

    testWidgets('NO branch + それでも開く: escalates the shared wait by 15s and starts the escalated countdown', (tester) async {
      final prefs = await PreferencesService.create();

      await tester.pumpWidget(wrap(SeriousModeFlow(
        args: args,
        preferences: prefs,
        normalWaitSeconds: 5,
        onGiveUp: () async {},
        onOpen: () async {},
        clock: Clock.fixed(DateTime(2026, 1, 1, 10)),
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '調べもの');
      await tester.tap(find.text('つぎへ'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('必要ない'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('それでも開く'));
      await tester.pumpAndSettle();

      // First-ever それでも開く costs 15s, shown immediately on the ring.
      expect(find.text('15'), findsOneWidget);
      // 開く must not be tappable until the wait completes.
      final openButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '開く'));
      expect(openButton.onPressed, isNull);

      // Escalation is recorded for the *next* trigger, right away.
      expect(await prefs.effectiveSeriousModeWaitSeconds(DateTime(2026, 1, 1, 10)), 30);

      final events = await prefs.loadEventLog();
      expect(events.any((e) => e.type == InterventionEventType.seriousModeOpenAnyway), isTrue);
    });

    testWidgets('やめとく stays available (and works) even during the escalated wait', (tester) async {
      final prefs = await PreferencesService.create();
      var gaveUp = false;

      await tester.pumpWidget(wrap(SeriousModeFlow(
        args: args,
        preferences: prefs,
        normalWaitSeconds: 5,
        onGiveUp: () async => gaveUp = true,
        onOpen: () async {},
        clock: Clock.fixed(DateTime(2026, 1, 1, 10)),
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '返信');
      await tester.tap(find.text('つぎへ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('必要ない'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('それでも開く'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('やめとく'));
      await tester.pumpAndSettle();

      expect(gaveUp, isTrue);
    });
  });
}

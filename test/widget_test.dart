// Basic smoke tests for MATE's UI shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mate/app.dart';
import 'package:mate/data/local/preferences_service.dart';
import 'package:mate/data/repositories/guarded_apps_repository.dart';
import 'package:mate/data/repositories/stats_repository.dart';
import 'package:mate/platform/installed_apps_bridge.dart';
import 'package:mate/platform/watcher_coordinator.dart';
import 'package:mate/state/app_state.dart';
import 'package:mate/state/overlay_access_controller.dart';
import 'package:mate/state/theme_controller.dart';
import 'package:mate/state/usage_access_controller.dart';

Future<Widget> buildTestApp({bool seedOnboardingCompleted = true}) async {
  // Onboarding is gated on a fresh install (see lib/app.dart); most of these
  // tests exercise MainShell directly, so seed it as already completed by
  // default. Onboarding itself is covered in test/onboarding_test.dart,
  // which passes `seedOnboardingCompleted: false`.
  SharedPreferences.setMockInitialValues({'onboarding_completed': seedOnboardingCompleted});
  final preferences = await PreferencesService.create();
  final watcherCoordinator = WatcherCoordinator(bridge: InstalledAppsBridge(), preferences: preferences);

  return MultiProvider(
    providers: [
      Provider<PreferencesService>.value(value: preferences),
      Provider<WatcherCoordinator>.value(value: watcherCoordinator),
      ChangeNotifierProvider(create: (_) => ThemeController(preferences)),
      ChangeNotifierProvider(
        create: (_) => AppState(
          // No platform channel is registered under `flutter test`, so the
          // real Android-backed repository would just return an empty list.
          // Tests exercise the UI against a fixed fake catalog instead.
          guardedAppsRepository: FakeGuardedAppsRepository(),
          statsRepository: MockStatsRepository(),
        )..load(),
      ),
      ChangeNotifierProvider(
        create: (_) => UsageAccessController(InstalledAppsBridge(), watcherCoordinator),
      ),
      ChangeNotifierProvider(
        create: (_) => OverlayAccessController(InstalledAppsBridge(), watcherCoordinator),
      ),
    ],
    child: const MateApp(),
  );
}

void main() {
  testWidgets('Home screen shows today\'s summary and bottom navigation', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('MATE'), findsOneWidget);
    expect(find.textContaining('回、誘惑に勝った'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('対象アプリ'), findsOneWidget);
    expect(find.text('統計'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('Navigating to Apps screen shows guarded app toggles', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('対象アプリ'));
    await tester.pumpAndSettle();

    expect(find.text('Instagram'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('Tapping a guarded app row opens per-app settings', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('対象アプリ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();

    expect(find.textContaining('の見守り設定'), findsOneWidget);
    expect(find.text('待機時間'), findsOneWidget);
    expect(find.text('ひとこと質問'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('Navigating to Stats screen shows weekly chart', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('統計'));
    await tester.pumpAndSettle();

    expect(find.text('直近7日間'), findsOneWidget);
  });

  testWidgets('Navigating to Settings screen allows theme mode change', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();

    // Phase 4 added guard-rule cards above the Display section, so the
    // theme controls are now below the initial test viewport. Scroll them
    // into view rather than assuming a fixed layout height.
    await tester.scrollUntilVisible(
      find.text('外観'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('外観'), findsOneWidget);
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();
  });

  testWidgets('Settings screen shows Phase 4 guard controls', (tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();

    expect(find.text('見守る時間'), findsOneWidget);
    expect(find.text('一時休止'), findsOneWidget);

    // ルール固定モード (formerly "Strict Mode") lives collapsed under 詳細設定
    // by design (Phase 6.5: keep the default settings view short) — its
    // actual on/off behavior is covered by StrictModeGuard's own tests
    // (phase4_rules_test.dart); here it's enough to confirm the section
    // renders.
    expect(find.text('ルール固定モード'), findsOneWidget);

    // 詳細設定 pushes 権限 further down than the initial test viewport (+
    // cache extent) reaches, so scroll it into view first — same reasoning
    // as the 外観 scroll above.
    await tester.scrollUntilVisible(
      find.text('使用状況へのアクセス'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('使用状況へのアクセス'), findsOneWidget);
    expect(find.text('検知テスト（開発用）'), findsOneWidget);
  });
}

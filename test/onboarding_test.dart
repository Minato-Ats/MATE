// Covers the Phase 5 first-run onboarding gate in lib/app.dart: a fresh
// install shows OnboardingScreen, and completing it reveals MainShell and
// persists the completed flag.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' show buildTestApp;

void main() {
  testWidgets('fresh install shows onboarding, not MainShell', (tester) async {
    await tester.pumpWidget(await buildTestApp(seedOnboardingCompleted: false));
    await tester.pumpAndSettle();

    expect(find.text('はじめまして、MATEです'), findsOneWidget);
    expect(find.text('ホーム'), findsNothing);
  });

  testWidgets('completing onboarding reveals MainShell and persists the flag', (tester) async {
    await tester.pumpWidget(await buildTestApp(seedOnboardingCompleted: false));
    await tester.pumpAndSettle();

    // Advance through all 4 pages ("つぎへ" x3, then "はじめる").
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('つぎへ'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('ホーム'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });
}

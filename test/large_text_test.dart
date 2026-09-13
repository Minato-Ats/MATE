// Phase 5 close: verifies main screens don't overflow/clip under a large
// text scale (accessibility large-font users). Not a permanent regression
// test file the app ships with conceptually forever, but kept alongside
// the other tests since it guards a real accessibility requirement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show buildTestApp;

Future<void> _pumpAtScale(WidgetTester tester, double scale) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: await buildTestApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.3, 2.0]) {
    testWidgets('Home/Apps/Stats/Settings render without overflow at ${scale}x text', (tester) async {
      await _pumpAtScale(tester, scale);
      expect(tester.takeException(), isNull, reason: 'Home overflowed at ${scale}x');

      await tester.tap(find.text('対象アプリ'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Apps screen overflowed at ${scale}x');

      await tester.tap(find.text('Instagram'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Wait-time sheet overflowed at ${scale}x');
      await tester.tapAt(const Offset(10, 10)); // dismiss sheet (tap scrim)
      await tester.pumpAndSettle();

      await tester.tap(find.text('統計'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Stats screen overflowed at ${scale}x');

      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Settings screen overflowed at ${scale}x');

      await tester.scrollUntilVisible(
        find.text('操作音（SE）'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull, reason: 'Settings screen (scrolled) overflowed at ${scale}x');
    });
  }

  testWidgets('Onboarding renders without overflow at 2.0x text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: await buildTestApp(seedOnboardingCompleted: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Onboarding welcome page overflowed at 2.0x');

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('つぎへ'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Onboarding page ${i + 2} overflowed at 2.0x');
    }
  });
}

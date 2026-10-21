import 'package:bath_wise/app.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bath_wise/features/rates/presentation/rates_screen.dart';
import 'package:bath_wise/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(fx: FakeFxRepository(Ok(sampleSnapshot()))),
        child: const BathWiseApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the dashboard with a bottom navigation bar', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('switches tabs from the navigation bar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Rates'));
    await tester.pumpAndSettle();

    expect(find.byType(RatesScreen), findsOneWidget);
  });

  testWidgets('theme switcher applies dark mode', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('uses a navigation rail on wide screens', (tester) async {
    await pumpApp(tester, size: const Size(1024, 768));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

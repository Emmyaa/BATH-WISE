// README screenshots from the real app with live data.
//
//   flutter drive -d <iPhone simulator> \
//     --driver=test_driver/screenshots_driver.dart \
//     --target=integration_test/screenshots_test.dart
//
// Uses a few BOT calls. Leaves the theme on System when done.
import 'dart:async';

import 'package:bath_wise/app.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:bath_wise/features/settings/presentation/settings_controller.dart';
import 'package:bath_wise/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps until [finder] matches (live data takes a moment), then lets
  /// entrance animations finish. Never pumpAndSettle: shimmers loop.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Waiting for $finder', timeout);
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> openTab(WidgetTester tester, int index) async {
    await tester.tap(find.byType(NavigationDestination).at(index));
    await tester.pump();
  }

  testWidgets('screenshots', (tester) async {
    await app.main();
    await waitFor(tester, find.text('USD / THB'));
    final settings = ProviderScope.containerOf(
      tester.element(find.byType(BathWiseApp)),
    ).read(settingsControllerProvider.notifier);
    await settings.setThemeMode(ThemeMode.light);
    await waitFor(tester, find.text('USD / THB'));
    await binding.takeScreenshot('01_dashboard');

    await openTab(tester, 1);
    await waitFor(tester, find.byType(RateTile));
    await binding.takeScreenshot('02_rates');

    await tester.tap(find.byType(RateTile).first);
    await waitFor(tester, find.text('Stats'));
    await binding.takeScreenshot('03_currency_detail');
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));

    await openTab(tester, 2);
    await waitFor(tester, find.text('You convert'));
    await binding.takeScreenshot('04_converter');

    await openTab(tester, 3);
    await waitFor(tester, find.byTooltip('Rate alerts for USD'));
    await binding.takeScreenshot('05_watchlist');

    await openTab(tester, 4);
    await waitFor(tester, find.text('Data sources'));
    await binding.takeScreenshot('06_settings');

    await settings.setThemeMode(ThemeMode.dark);
    await openTab(tester, 0);
    await waitFor(tester, find.text('USD / THB'));
    // Theme cross-fade.
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('07_dashboard_dark');

    await settings.setThemeMode(ThemeMode.system);
  });
}

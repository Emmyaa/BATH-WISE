import 'package:bath_wise/app.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/golden_helpers.dart';

/// Every tab at 200% text on a small phone: no overflow, no exception.
void main() {
  // Real glyph widths: the default test font is much wider.
  setUpAll(loadAppFonts);

  for (final (tab, label) in [
    (0, 'Home'),
    (1, 'Rates'),
    (2, 'Convert'),
    (3, 'Watchlist'),
    (4, 'Settings'),
  ]) {
    testWidgets('$label tab at 200% text', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(fx: FakeFxRepository(Ok(sampleSnapshot()))),
          child: const BathWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(tab));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

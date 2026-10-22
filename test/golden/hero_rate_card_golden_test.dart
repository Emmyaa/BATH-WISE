@Tags(['golden'])
library;

import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/core/widgets/app_background.dart';
import 'package:bath_wise/features/dashboard/presentation/widgets/hero_rate_card.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/golden_helpers.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    useTolerantGoldens();
  });

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('hero card, $name', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 280)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(fx: FakeFxRepository(Ok(sampleSnapshot()))),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AppBackground(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: HeroRateCard(snapshot: sampleSnapshot(), onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HeroRateCard),
        matchesGoldenFile('goldens/hero_rate_card_$name.png'),
      );
    });
  }
}

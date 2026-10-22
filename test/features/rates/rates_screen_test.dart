import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/currency_detail_screen.dart';
import 'package:bath_wise/features/rates/presentation/rates_screen.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFxRepository repo;

  Future<void> pumpRates(
    WidgetTester tester, {
    Size size = const Size(420, 1600),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(fx: repo),
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RatesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tileFor(String code) => find.byWidgetPredicate(
    (w) => w is RateTile && w.quote.currencyCode == code,
  );

  setUp(() => repo = FakeFxRepository(Ok(sampleSnapshot())));

  testWidgets('lists currencies with mid rates and the BOT status line', (
    tester,
  ) async {
    await pumpRates(tester);

    expect(tileFor('USD'), findsOneWidget);
    expect(find.text('33.4859'), findsOneWidget);
    expect(find.text('Official BOT rate as of Oct 19, 2026'), findsOneWidget);
    expect(find.text('Next update today at 18:00'), findsOneWidget);
  });

  testWidgets('JPY shows its quotation unit', (tester) async {
    await pumpRates(tester);
    await tester.enterText(find.byType(TextField), 'jpy');
    await tester.pumpAndSettle();

    expect(find.textContaining('per 100 JPY'), findsOneWidget);
  });

  testWidgets('search filters and shows an empty state', (tester) async {
    await pumpRates(tester);

    await tester.enterText(find.byType(TextField), 'euro');
    await tester.pumpAndSettle();
    expect(tileFor('EUR'), findsOneWidget);
    expect(tileFor('USD'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('No currency matches “xyz”'), findsOneWidget);
  });

  testWidgets('rate type toggle switches the shown value', (tester) async {
    await pumpRates(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sell'));
    await tester.pumpAndSettle();

    expect(find.text('33.6489'), findsOneWidget);
    expect(tester.widget<RateTile>(tileFor('USD')).rateType, RateType.selling);
  });

  testWidgets('rows are announced as one sentence', (tester) async {
    await pumpRates(tester);

    expect(
      tester.getSemantics(tileFor('USD')).label,
      startsWith('US Dollar, 33.4859 baht'),
    );
  });

  testWidgets('rows can be activated from a screen reader', (tester) async {
    await pumpRates(tester);

    expect(
      tester.getSemantics(tileFor('USD')),
      matchesSemantics(isButton: true, hasTapAction: true),
    );
  });

  testWidgets('pull-to-refresh forces a refresh', (tester) async {
    await pumpRates(tester);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 500),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(repo.lastForceRefresh, isTrue);
  });

  testWidgets('offline cache shows a banner', (tester) async {
    repo.latest = Ok(sampleSnapshot(refreshFailure: const NetworkFailure()));
    await pumpRates(tester);

    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('ECB fallback: banner, source line, buy/sell disabled', (
    tester,
  ) async {
    repo.latest = Ok(
      sampleSnapshot(
        source: RateSource.ecb,
        refreshFailure: const UnauthorizedFailure(),
      ),
    );
    await pumpRates(tester);

    expect(find.textContaining('ECB reference rates'), findsOneWidget);
    expect(find.text('ECB reference rate as of Oct 19, 2026'), findsOneWidget);
    final sell = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Sell'),
    );
    expect(sell.onSelected, isNull);
  });

  testWidgets('error state retries', (tester) async {
    repo.latest = const Err(NetworkFailure());
    await pumpRates(tester);

    expect(find.text("Couldn't load rates"), findsOneWidget);
    repo.latest = Ok(sampleSnapshot());
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(tileFor('USD'), findsOneWidget);
  });

  testWidgets('wide screens show the detail next to the list', (tester) async {
    await pumpRates(tester, size: const Size(1200, 900));

    // USD is preselected in the pane: its name shows in the list tile and
    // in the detail header.
    expect(find.byType(CurrencyDetailView), findsOneWidget);
    expect(find.text("Today's rates"), findsOneWidget);
    expect(
      tester.widget<CurrencyDetailView>(find.byType(CurrencyDetailView)).code,
      'USD',
    );

    await tester.tap(tileFor('EUR'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CurrencyDetailView>(find.byType(CurrencyDetailView)).code,
      'EUR',
    );
  });
}

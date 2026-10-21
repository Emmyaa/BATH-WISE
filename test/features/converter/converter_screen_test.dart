import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/features/converter/presentation/converter_screen.dart';
import 'package:bath_wise/features/converter/presentation/widgets/amount_keypad.dart';
import 'package:bath_wise/features/converter/presentation/widgets/conversion_pair.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFxRepository repo;

  Future<void> pumpConverter(
    WidgetTester tester, {
    Size size = const Size(420, 1400),
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
          home: const ConverterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String label) => find.descendant(
    of: find.byType(AmountKeypad),
    matching: find.bySemanticsLabel(label),
  );

  Future<void> press(WidgetTester tester, String keys) async {
    for (final k in keys.split('')) {
      await tester.tap(key(k == '.' ? 'Decimal point' : k));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Text inside the from/to cards.
  Finder inPair(String text) => find.descendant(
    of: find.byType(ConversionPair),
    matching: find.text(text),
  );

  /// The result card's spoken summary, which carries the exact result.
  Finder conversion(Pattern text) => find.bySemanticsLabel(text);

  setUp(() => repo = FakeFxRepository(Ok(sampleSnapshot())));

  testWidgets('starts at 100 USD → THB with the rate used and its source', (
    tester,
  ) async {
    await pumpConverter(tester);

    expect(inPair('100'), findsOneWidget);
    expect(inPair('3,348.59'), findsOneWidget);
    expect(find.text('1 USD = 33.4859 THB'), findsOneWidget);
    expect(find.text('BOT official · Mid rate · Oct 19, 2026'), findsOneWidget);
  });

  testWidgets('keypad replaces the default amount, then edits it', (
    tester,
  ) async {
    await pumpConverter(tester);

    await press(tester, '1234.5');
    expect(inPair('1,234.5'), findsOneWidget);
    expect(conversion('1,234.50 USD is 41,338.34 THB'), findsOneWidget);

    await tester.tap(key('Delete'));
    await tester.pumpAndSettle();
    expect(inPair('1,234.'), findsOneWidget);

    await tester.longPress(key('Delete'));
    await tester.pumpAndSettle();
    expect(inPair('0'), findsOneWidget);
    expect(conversion('0.00 USD is 0.00 THB'), findsOneWidget);
  });

  testWidgets('keys and the swap button work from a screen reader', (
    tester,
  ) async {
    await pumpConverter(tester);

    expect(
      tester.getSemantics(key('Delete')),
      matchesSemantics(
        label: 'Delete',
        isButton: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    tester.semantics
      ..tap(find.semantics.byLabel('7'))
      ..tap(find.semantics.byLabel('Swap currencies'));
    await tester.pumpAndSettle();

    expect(conversion('7.00 THB is 0.21 USD'), findsOneWidget);
  });

  testWidgets('quick amounts set the amount', (tester) async {
    await pumpConverter(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '10,000'));
    await tester.pumpAndSettle();

    expect(conversion('10,000.00 USD is 334,859.00 THB'), findsOneWidget);
  });

  testWidgets('swap converts the other way', (tester) async {
    await pumpConverter(tester);

    await tester.tap(find.byTooltip('Swap currencies'));
    await tester.pumpAndSettle();

    expect(conversion('100.00 THB is 2.99 USD'), findsOneWidget);
    expect(find.text('1 THB = 0.0299 USD'), findsOneWidget);
  });

  testWidgets('picking a currency from the sheet converts a cross rate', (
    tester,
  ) async {
    await pumpConverter(tester);

    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^You get THB.*Change currency$')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'euro');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'EUR'));
    await tester.pumpAndSettle();

    expect(conversion('100.00 USD is 89.22 EUR'), findsOneWidget);
    expect(find.text('1 USD = 0.8922 EUR'), findsOneWidget);
  });

  testWidgets('lists the amount in THB and watchlist currencies', (
    tester,
  ) async {
    await pumpConverter(tester);

    // THB is the pair's target, so it isn't repeated; USD is the source.
    expect(conversion('100.00 USD is 89.22 EUR'), findsOneWidget);
    expect(conversion('100.00 USD is 15,805.75 JPY'), findsOneWidget);
    expect(conversion(RegExp(r'USD is .* USD$')), findsNothing);

    await tester.tap(conversion('100.00 USD is 15,805.75 JPY'));
    await tester.pumpAndSettle();
    expect(find.text('1 USD = 158.0575 JPY'), findsOneWidget);
  });

  testWidgets('rate type changes the rate used', (tester) async {
    await pumpConverter(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sell'));
    await tester.pumpAndSettle();

    expect(find.text('1 USD = 33.6489 THB'), findsOneWidget);
    expect(conversion('100.00 USD is 3,364.89 THB'), findsOneWidget);
  });

  testWidgets('ECB fallback converts at mid with buy/sell disabled', (
    tester,
  ) async {
    repo.latest = Ok(
      sampleSnapshot(
        source: RateSource.ecb,
        refreshFailure: const UnauthorizedFailure(),
      ),
    );
    await pumpConverter(tester);

    expect(find.textContaining('ECB reference rates'), findsOneWidget);
    expect(
      find.text('ECB reference · Mid rate · Oct 19, 2026'),
      findsOneWidget,
    );
    final sell = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Sell'),
    );
    expect(sell.onSelected, isNull);
  });

  testWidgets('error state retries', (tester) async {
    repo.latest = const Err(NetworkFailure());
    await pumpConverter(tester);

    expect(find.text("Couldn't load rates"), findsOneWidget);
    repo.latest = Ok(sampleSnapshot());
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(AmountKeypad), findsOneWidget);
  });

  testWidgets('wide screens put the keypad beside the results', (tester) async {
    await pumpConverter(tester, size: const Size(1100, 800));

    final keypad = tester.getRect(find.byType(AmountKeypad));
    final result = tester.getRect(inPair('3,348.59'));
    expect(keypad.left, greaterThan(result.right));
  });
}

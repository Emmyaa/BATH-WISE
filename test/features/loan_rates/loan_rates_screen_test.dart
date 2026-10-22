import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/loan_rates/presentation/loan_rates_screen.dart';
import 'package:bath_wise/features/loan_rates/presentation/loan_rates_view_model.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_helpers.dart';

const _domestic = 'Commercial Banks Registered in Thailand';
const _foreign = 'Foreign Bank Branches';

LoanRate _bank(
  String name, {
  String type = _domestic,
  String? mor,
  String? mlr,
  String? mrr,
  String? nameTh,
}) => LoanRate(
  kind: LoanRateKind.bank,
  period: DateTime.utc(2026, 10, 20),
  nameEn: name,
  nameTh: nameTh ?? 'ธนาคาร$name',
  bankTypeEn: type,
  bankTypeTh: type == _domestic
      ? 'ธนาคารพาณิชย์จดทะเบียนในประเทศ'
      : 'สาขาธนาคารต่างประเทศ',
  mor: mor == null ? null : Decimal.parse(mor),
  mlr: mlr == null ? null : Decimal.parse(mlr),
  mrr: mrr == null ? null : Decimal.parse(mrr),
);

final List<LoanRate> _banks = [
  _bank('Bravo Bank', mor: '7.10', mlr: '6.60', mrr: '7.05'),
  _bank('Alpha Bank', mor: '6.95', mlr: '6.80', mrr: '6.90'),
  _bank('Delta Bank', type: _foreign, mor: '7.50', mlr: '6.40'),
  _bank('Charlie Bank', mor: '7.20', mlr: '6.60', mrr: '7.30'),
];

LoanRatesSnapshot _snapshot(
  List<LoanRate> rates, {
  LoanRateKind kind = LoanRateKind.bank,
  Failure? refreshFailure,
}) => LoanRatesSnapshot(
  kind: kind,
  asOf: DateTime.utc(2026, 10, 20),
  rates: rates,
  fetchedAt: bkk(2026, 10, 20, 14, 5),
  refreshFailure: refreshFailure,
);

void main() {
  group('filterAndSortLoanRates', () {
    List<String> names(LoanRatesListState state, {bool thai = false}) => [
      for (final r in filterAndSortLoanRates(_banks, state, thai: thai))
        r.nameEn,
    ];

    test('defaults to lowest MLR, ties by name', () {
      expect(names(const LoanRatesListState()), [
        'Delta Bank',
        'Bravo Bank',
        'Charlie Bank',
        'Alpha Bank',
      ]);
    });

    test('a missing rate sorts last', () {
      expect(
        names(const LoanRatesListState(sort: LoanSort.mrr)).last,
        'Delta Bank',
      );
    });

    test('name sort uses the display language', () {
      final thaiFirst = [
        _bank('Zulu Bank', nameTh: 'ธนาคารกรุง'),
        _bank('Alpha Bank', nameTh: 'ธนาคารไทย'),
      ];
      List<String> sorted({required bool thai}) => [
        for (final r in filterAndSortLoanRates(
          thaiFirst,
          const LoanRatesListState(sort: LoanSort.name),
          thai: thai,
        ))
          r.nameEn,
      ];
      expect(sorted(thai: false), ['Alpha Bank', 'Zulu Bank']);
      expect(sorted(thai: true), ['Zulu Bank', 'Alpha Bank']);
    });

    test('filters by bank type', () {
      expect(names(const LoanRatesListState(bankType: _foreign)), [
        'Delta Bank',
      ]);
    });

    test('bankTypesOf keeps first-seen order without duplicates', () {
      expect(
        [for (final t in bankTypesOf(_banks)) t.en],
        [_domestic, _foreign],
      );
    });
  });

  group('LoanRatesScreen', () {
    late FakeLoanRatesRepository loans;

    setUp(() {
      loans = FakeLoanRatesRepository(
        Ok(_snapshot(_banks)),
        Ok(
          _snapshot([
            LoanRate(
              kind: LoanRateKind.average,
              period: DateTime.utc(2026, 10, 20),
              nameEn: 'Commercial banks',
              nameTh: 'ธนาคารพาณิชย์',
              mor: Decimal.parse('7.11'),
              mlr: Decimal.parse('6.66'),
              mrr: Decimal.parse('7.22'),
            ),
          ], kind: LoanRateKind.average),
        ),
      );
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(420, 1800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(
            fx: FakeFxRepository(Ok(sampleSnapshot())),
            loans: loans,
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoanRatesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double topOf(WidgetTester tester, String text) =>
        tester.getTopLeft(find.text(text)).dy;

    testWidgets('shows the average and banks sorted by lowest MLR', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Market average'), findsOneWidget);
      expect(find.text('6.66%'), findsOneWidget);
      expect(find.text('Rates as of Oct 20, 2026 · % per year'), findsOne);
      expect(
        topOf(tester, 'Delta Bank'),
        lessThan(topOf(tester, 'Alpha Bank')),
      );
      expect(
        find.bySemanticsLabel(RegExp('^Alpha Bank, .*MOR 6.95%')),
        findsOne,
      );
    });

    testWidgets('sorts from the menu', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lowest MOR'));
      await tester.pumpAndSettle();

      expect(
        topOf(tester, 'Alpha Bank'),
        lessThan(topOf(tester, 'Bravo Bank')),
      );
    });

    testWidgets('filters by bank type', (tester) async {
      await pumpScreen(tester);

      final foreignChip = find.widgetWithText(ChoiceChip, _foreign);
      await tester.ensureVisible(foreignChip);
      await tester.pumpAndSettle();
      await tester.tap(foreignChip);
      await tester.pumpAndSettle();
      expect(find.text('Delta Bank'), findsOneWidget);
      expect(find.text('Alpha Bank'), findsNothing);

      final allChip = find.widgetWithText(ChoiceChip, 'All banks');
      await tester.ensureVisible(allChip);
      await tester.pumpAndSettle();
      await tester.tap(allChip);
      await tester.pumpAndSettle();
      expect(find.text('Alpha Bank'), findsOneWidget);
    });

    testWidgets('a 403 explains the missing access and can retry', (
      tester,
    ) async {
      loans.result = const Err(UnauthorizedFailure('403'));
      await pumpScreen(tester);

      expect(find.text("Couldn't load loan rates"), findsOneWidget);
      expect(
        find.text("The API key doesn't have access to this data yet."),
        findsOneWidget,
      );

      loans.result = Ok(_snapshot(_banks));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha Bank'), findsOneWidget);
    });

    testWidgets('cached data after a failed refresh shows a banner', (
      tester,
    ) async {
      loans.result = Ok(
        _snapshot(_banks, refreshFailure: const NetworkFailure()),
      );
      await pumpScreen(tester);

      expect(find.textContaining("You're offline"), findsOneWidget);
    });

    testWidgets('Thai shows Thai names and types', (tester) async {
      tester.view
        ..physicalSize = const Size(420, 1800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(
            fx: FakeFxRepository(Ok(sampleSnapshot())),
            loans: loans,
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('th'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoanRatesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ธนาคารAlpha Bank'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'สาขาธนาคารต่างประเทศ'),
        findsOneWidget,
      );
    });
  });

  group('LoanRatesViewModel', () {
    test('refresh forces a fetch and keeps data on failure', () async {
      final loans = FakeLoanRatesRepository(Ok(_snapshot(_banks)));
      final container = ProviderContainer.test(
        overrides: appOverrides(
          fx: FakeFxRepository(Ok(sampleSnapshot())),
          loans: loans,
        ),
      )..listen(loanRatesViewModelProvider, (_, _) {});
      await container.read(loanRatesViewModelProvider.future);
      expect(loans.lastForceRefresh, isFalse);

      loans.result = const Err(NetworkFailure());
      final failure = await container
          .read(loanRatesViewModelProvider.notifier)
          .refresh();

      expect(loans.lastForceRefresh, isTrue);
      expect(failure, isA<NetworkFailure>());
      expect(
        container.read(loanRatesViewModelProvider).value!.rates,
        hasLength(4),
      );
    });
  });
}

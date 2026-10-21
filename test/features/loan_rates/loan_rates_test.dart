import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rate_api.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rate_dtos.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_local_data_source.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_repository_impl.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_helpers.dart';

class MockLoanRateApi extends Mock implements LoanRateApi;

class MockCalendarService extends Mock implements MarketCalendarService;

List<LoanRate> bankFixture() => [
  for (final row in botDataDetail(loadFixture('loan_rate_spec_shape.json')))
    ?BankLoanRateDto.fromJson(row).toEntity(),
];

void main() {
  setUpAll(() {
    registerFallbackValue(LoanRateKind.bank);
    registerFallbackValue(DateTime.utc(2000));
  });

  group('DTOs (spec-shaped fixtures)', () {
    test('bank rows: Decimals, empty → null, trimmed names', () {
      final rates = bankFixture();
      expect(rates, hasLength(3));
      final first = rates.first;
      expect(first.nameEn, 'Example Bank Public Company Limited');
      expect(first.mor, Decimal.parse('6.95'));
      expect(first.ceilingRate, isNull);
      expect(first.bankTypeEn, 'Commercial Banks Registered in Thailand');
    });

    test('average: data_detail as a single object', () {
      final rows = botDataDetail(loadFixture('avg_loan_rate_spec_shape.json'));
      final rate = AverageLoanRateDto.fromJson(rows.single).toEntity()!;
      expect(rate.kind, LoanRateKind.average);
      expect(rate.mrr, Decimal.parse('7.041'));
      expect(rate.bankTypeEn, isNull);
    });
  });

  group('LoanRatesRepositoryImpl', () {
    late AppDatabase db;
    late MockLoanRateApi api;
    late FakeClock clock;
    late LoanRatesRepositoryImpl repo;

    void stubApi(Object Function() answer) =>
        when(
          () => api.fetchRates(
            LoanRateKind.bank,
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer((_) async {
          final value = answer();
          if (value is Failure) throw value;
          return value as List<LoanRate>;
        });

    void verifyCalls(int n) => verify(
      () => api.fetchRates(
        LoanRateKind.bank,
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).called(n);

    setUp(() {
      db = inMemoryDatabase();
      api = MockLoanRateApi();
      clock = FakeClock(bkk(2026, 10, 20, 15));
      final calendar = MockCalendarService();
      when(() => calendar.calendarAround(any()))
          .thenAnswer((_) async => MarketCalendar());
      repo = LoanRatesRepositoryImpl(
        api,
        LoanRatesLocalDataSource(db),
        db,
        calendar,
        clock,
      );
    });
    tearDown(() => db.close());

    test('returns only the newest period', () async {
      stubApi(bankFixture);

      final snapshot = (await repo.getLatest(LoanRateKind.bank)).valueOrNull!;

      expect(snapshot.asOf, DateTime.utc(2026, 10, 20));
      expect(snapshot.rates, hasLength(2));
      expect(
        snapshot.rates.firstWhere((r) => r.nameEn.startsWith('Example')).mlr,
        Decimal.parse('6.5'),
      );
    });

    test('caches until the next 14:00 release', () async {
      stubApi(bankFixture);

      await repo.getLatest(LoanRateKind.bank);
      clock.current = bkk(2026, 10, 21, 13, 59);
      await repo.getLatest(LoanRateKind.bank);
      verifyCalls(1);

      clock.current = bkk(2026, 10, 21, 14, 1);
      await repo.getLatest(LoanRateKind.bank);
      verifyCalls(1);
    });

    test('403 without cache surfaces UnauthorizedFailure', () async {
      stubApi(() => const UnauthorizedFailure('403'));

      final result = await repo.getLatest(LoanRateKind.bank);

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });

    test('failure with cache → cached snapshot marked degraded', () async {
      stubApi(bankFixture);
      await repo.getLatest(LoanRateKind.bank);

      clock.current = bkk(2026, 10, 21, 15);
      stubApi(() => const NetworkFailure());
      final snapshot = (await repo.getLatest(LoanRateKind.bank)).valueOrNull!;

      expect(snapshot.refreshFailure, isA<NetworkFailure>());
      expect(snapshot.rates, hasLength(2));
    });
  });
}

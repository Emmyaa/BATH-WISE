import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_api.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_dto.dart';
import 'package:bath_wise/features/rates/data/frankfurter_api.dart';
import 'package:bath_wise/features/rates/data/frankfurter_dtos.dart';
import 'package:bath_wise/features/rates/data/fx_repository_impl.dart';
import 'package:bath_wise/features/rates/data/rates_local_data_source.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_helpers.dart';

class MockBotApi extends Mock implements BotExchangeRateApi;

class MockFrankfurterApi extends Mock implements FrankfurterApi;

class MockCalendarService extends Mock implements MarketCalendarService;

List<BotExchangeRateDto> sampleDtos(String name) => [
  for (final row in botDataDetail(loadApiSample(name)))
    BotExchangeRateDto.fromJson(row),
];

void main() {
  setUpAll(() {
    registerFallbackValue(Periodicity.daily);
    registerFallbackValue(DateTime.utc(2000));
  });

  late AppDatabase db;
  late MockBotApi bot;
  late MockFrankfurterApi frankfurter;
  late FakeClock clock;
  late FxRepositoryImpl repo;

  final daily = sampleDtos('exchange_daily_all');

  // Tue 20 Oct 2026 15:42 Bangkok: latest release was Mon 19 at 18:00.
  final now = bkk(2026, 10, 20, 15, 42);

  void stubBotDaily(Object Function() answer) =>
      when(
        () => bot.fetchRates(
          Periodicity.daily,
          start: any(named: 'start'),
          end: any(named: 'end'),
          currency: any(named: 'currency'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(Duration.zero);
        final value = answer();
        if (value is Failure) throw value;
        return value as List<BotExchangeRateDto>;
      });

  void verifyBotDailyCalls(int times) => verify(
    () => bot.fetchRates(
      Periodicity.daily,
      start: any(named: 'start'),
      end: any(named: 'end'),
      currency: any(named: 'currency'),
    ),
  ).called(times);

  setUp(() {
    db = inMemoryDatabase();
    bot = MockBotApi();
    frankfurter = MockFrankfurterApi();
    clock = FakeClock(now);
    final calendar = MockCalendarService();
    when(() => calendar.calendarAround(any())).thenAnswer(
      (_) async => MarketCalendar([
        Holiday(date: DateTime.utc(2026, 10, 13), nameEn: 'H', nameTh: 'H'),
      ]),
    );
    repo = FxRepositoryImpl(
      bot,
      frankfurter,
      RatesLocalDataSource(db),
      db,
      calendar,
      clock,
    );
  });
  tearDown(() => db.close());

  group('getLatestRates', () {
    test('first launch: one call for ~a month of all currencies', () async {
      stubBotDaily(() => daily);

      final snapshot = (await repo.getLatestRates()).valueOrNull!;

      expect(snapshot.source, RateSource.bot);
      expect(snapshot.asOf, DateTime.utc(2026, 10, 19));
      expect(snapshot.quotes, hasLength(19));
      expect(snapshot.fetchedAt, now);
      expect(snapshot.isDegraded, isFalse);
      final usd = snapshot.quoteFor('USD')!;
      expect(usd.current.mid, Decimal.parse('33.4859'));
      expect(usd.previous!.period, DateTime.utc(2026, 10, 15));

      verify(
        () => bot.fetchRates(
          Periodicity.daily,
          start: DateTime.utc(2026, 9, 20),
          end: DateTime.utc(2026, 10, 20),
        ),
      ).called(1);
      expect(usd.recent.map((r) => r.period.day), [12, 14, 15, 19]);
    });

    test('serves cache until the next 18:00 release', () async {
      stubBotDaily(() => daily);

      await repo.getLatestRates();
      clock.current = bkk(2026, 10, 20, 17, 59);
      await repo.getLatestRates();
      verifyBotDailyCalls(1);

      clock.current = bkk(2026, 10, 20, 18, 5);
      await repo.getLatestRates();
      verifyBotDailyCalls(1);
    });

    test('concurrent callers share one BOT request', () async {
      stubBotDaily(() => daily);

      final results = await Future.wait([
        repo.getLatestRates(),
        repo.getLatestRates(),
        repo.getLatestRates(),
      ]);

      expect(results.every((r) => r.isOk), isTrue);
      verifyBotDailyCalls(1);
    });

    test('pull-to-refresh is throttled to once a minute', () async {
      stubBotDaily(() => daily);
      await repo.getLatestRates();

      clock.advance(const Duration(seconds: 30));
      await repo.getLatestRates(forceRefresh: true);
      verifyBotDailyCalls(1);

      clock.advance(const Duration(seconds: 31));
      await repo.getLatestRates(forceRefresh: true);
      verifyBotDailyCalls(1);
    });

    test('BOT fails with cache → cached snapshot marked degraded', () async {
      stubBotDaily(() => daily);
      await repo.getLatestRates();

      clock.current = bkk(2026, 10, 21, 9);
      stubBotDaily(() => const NetworkFailure('offline'));
      final snapshot = (await repo.getLatestRates()).valueOrNull!;

      expect(snapshot.source, RateSource.bot);
      expect(snapshot.refreshFailure, isA<NetworkFailure>());
      expect(snapshot.fetchedAt, now, reason: 'last successful fetch');
      verifyNever(
        () => frankfurter.fetchSeries(
          base: any(named: 'base'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      );
    });

    test('BOT fails without cache → ECB fallback', () async {
      stubBotDaily(() => const UnauthorizedFailure('403'));
      final latest =
          loadApiSample('frankfurter_latest_thb')! as Map<String, dynamic>;
      when(
        () => frankfurter.fetchSeries(
          base: 'THB',
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => FrankfurterSeriesDto.fromJson({
          'base': 'THB',
          'rates': {'2026-10-19': latest['rates']},
        }),
      );

      final snapshot = (await repo.getLatestRates()).valueOrNull!;

      expect(snapshot.source, RateSource.ecb);
      expect(snapshot.refreshFailure, isA<UnauthorizedFailure>());
      expect(snapshot.quoteFor('USD')!.current.mid, isNotNull);
      expect(snapshot.quoteFor('USD')!.current.selling, isNull);
    });

    test('BOT and ECB both fail without cache → BOT failure', () async {
      stubBotDaily(() => const UnauthorizedFailure('403'));
      when(
        () => frankfurter.fetchSeries(
          base: any(named: 'base'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenThrow(const NetworkFailure());

      final result = await repo.getLatestRates();

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });

    test('BOT returns only "no data" rows on first launch → ECB', () async {
      stubBotDaily(() => sampleDtos('exchange_daily_weekend'));
      when(
        () => frankfurter.fetchSeries(
          base: any(named: 'base'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenThrow(const NetworkFailure());

      expect((await repo.getLatestRates()).failureOrNull, isA<NoDataFailure>());
    });
  });

  group('getHistory', () {
    final monthly = sampleDtos('exchange_monthly_usd');
    final start = DateTime.utc(2025, 10);
    final end = DateTime.utc(2026, 9);

    void stubMonthly(Object Function() answer) =>
        when(
          () => bot.fetchRates(
            Periodicity.monthly,
            start: start,
            end: end,
            currency: 'USD',
          ),
        ).thenAnswer((_) async {
          final value = answer();
          if (value is Failure) throw value;
          return value as List<BotExchangeRateDto>;
        });

    test('returns points oldest first and caches closed ranges', () async {
      stubMonthly(() => monthly);

      Future<void> load() async {
        final series = (await repo.getHistory(
          currencyCode: 'USD',
          periodicity: Periodicity.monthly,
          start: start,
          end: end,
        )).valueOrNull!;
        expect(series.points, hasLength(12));
        expect(series.points.first.period, start);
        expect(series.points.last.period, end);
      }

      await load();
      clock.advance(const Duration(days: 3));
      await load();

      verify(
        () => bot.fetchRates(
          Periodicity.monthly,
          start: start,
          end: end,
          currency: 'USD',
        ),
      ).called(1);
    });

    test('daily history falls back to ECB when BOT fails', () async {
      when(
        () => bot.fetchRates(
          Periodicity.daily,
          start: any(named: 'start'),
          end: any(named: 'end'),
          currency: 'USD',
        ),
      ).thenThrow(const NetworkFailure());
      when(
        () => frankfurter.fetchSeries(
          base: 'USD',
          start: any(named: 'start'),
          end: any(named: 'end'),
          symbols: ['THB'],
        ),
      ).thenAnswer(
        (_) async => FrankfurterSeriesDto.fromJson(
          loadApiSample('frankfurter_series_usd_thb')! as Map<String, dynamic>,
        ),
      );

      final series = (await repo.getHistory(
        currencyCode: 'USD',
        periodicity: Periodicity.daily,
        start: DateTime.utc(2026, 10, 10),
        end: DateTime.utc(2026, 10, 20),
      )).valueOrNull!;

      expect(series.source, RateSource.ecb);
      expect(series.refreshFailure, isA<NetworkFailure>());
      expect(series.points, hasLength(7));
    });

    test('monthly history has no ECB fallback', () async {
      stubMonthly(() => const NetworkFailure());

      final result = await repo.getHistory(
        currencyCode: 'USD',
        periodicity: Periodicity.monthly,
        start: start,
        end: end,
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('getCrossRate', () {
    test('fetches from ECB and caches for an hour', () async {
      when(() => frankfurter.fetchLatest(base: 'EUR', symbols: ['USD']))
          .thenAnswer(
            (_) async => const FrankfurterLatestDto(
              base: 'EUR',
              date: '2026-10-19',
              rates: {'USD': 1.1612},
            ),
          );

      final first = (await repo.getCrossRate(
        base: 'EUR',
        quote: 'USD',
      )).valueOrNull!;
      clock.advance(const Duration(minutes: 30));
      await repo.getCrossRate(base: 'EUR', quote: 'USD');
      clock.advance(const Duration(minutes: 31));
      await repo.getCrossRate(base: 'EUR', quote: 'USD');

      expect(first.rate, Decimal.parse('1.1612'));
      expect(first.date, DateTime.utc(2026, 10, 19));
      expect(first.source, RateSource.ecb);
      verify(() => frankfurter.fetchLatest(base: 'EUR', symbols: ['USD']))
          .called(2);
    });
  });
}

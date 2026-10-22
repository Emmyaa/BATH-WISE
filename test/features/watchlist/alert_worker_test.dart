import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/network/dio_providers.dart';
import 'package:bath_wise/core/network/guard_request.dart';
import 'package:bath_wise/core/network/interceptors/call_budget_interceptor.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/watchlist/background/alert_worker.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_providers.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('CallBudgetInterceptor', () {
    test('fails fast once the budget is spent', () async {
      final adapter = FakeHttpAdapter()
        ..enqueueJson(200, {'ok': true})
        ..enqueueJson(200, {'ok': true});
      final dio = buildApiDio(baseUrl: 'https://example.test', log: false)
        ..httpClientAdapter = adapter;
      dio.interceptors.insert(0, CallBudgetInterceptor(1));

      expect((await guardRequest(() => dio.get<void>('/a'))).isOk, isTrue);
      final second = await guardRequest(() => dio.get<void>('/b'));
      expect(second.failureOrNull, isA<RateLimitFailure>());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('background alert check', () {
    late ProviderContainer container;
    late FakeHttpAdapter bot;
    late FakeHttpAdapter ecb;
    late FakeAlertNotifier notifier;

    setUp(() async {
      bot = FakeHttpAdapter();
      ecb = FakeHttpAdapter();
      notifier = FakeAlertNotifier();
      container = ProviderContainer.test(
        overrides: [
          ...alertWorkerOverrides(),
          appDatabaseProvider.overrideWithValue(inMemoryDatabase()),
          clockProvider.overrideWithValue(FakeClock(bkk(2026, 10, 20, 19))),
          alertNotificationsProvider.overrideWithValue(notifier),
        ],
      );
      container.read(botDioProvider).httpClientAdapter = bot;
      container.read(frankfurterDioProvider).httpClientAdapter = ecb;

      final usdMid = sampleSnapshot().quoteFor('USD')!.current.mid!;
      await container.read(watchlistRepositoryProvider).addAlert((
        currencyCode: 'USD',
        direction: AlertDirection.above,
        target: usdMid - Decimal.one,
        rateType: RateType.mid,
      ));
    });

    Future<List<AlertTrigger>> run() =>
        container.read(alertCheckProvider).run();

    test('fetches rates with one BOT call and notifies', () async {
      bot.enqueueJson(200, loadApiSample('exchange_daily_all'));

      expect(await run(), hasLength(1));
      expect(bot.requests, hasLength(1));
      expect(bot.requests.single.path, contains('DAILY_AVG_EXG_RATE'));
      expect(notifier.shown.single.alert.currencyCode, 'USD');
    });

    test('a run with a current cache makes no BOT call', () async {
      bot.enqueueJson(200, loadApiSample('exchange_daily_all'));
      await run();
      await container.read(watchlistRepositoryProvider).addAlert((
        currencyCode: 'EUR',
        direction: AlertDirection.above,
        target: Decimal.fromInt(1000),
        rateType: RateType.mid,
      ));

      await run();
      expect(bot.requests, hasLength(1));
    });

    test('a failing BOT costs one call: no retry, no holidays', () async {
      bot.enqueueJson(503, {'error': 'unavailable'});
      ecb.enqueueConnectionError();

      expect(await run(), isEmpty);
      expect(bot.requests, hasLength(1));
      expect(notifier.shown, isEmpty);
    });

    test('ECB fallback data never fires an alert', () async {
      bot.enqueueJson(401, {'error': 'unauthorized'});
      ecb.enqueueJson(200, loadApiSample('frankfurter_latest_thb'));

      expect(await run(), isEmpty);
      expect(bot.requests, hasLength(1));
    });
  });

  test('CachedHolidayRepository serves cache only', () async {
    final db = inMemoryDatabase();
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        ...alertWorkerOverrides(),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    final adapter = FakeHttpAdapter();
    container.read(botDioProvider).httpClientAdapter = adapter;
    final repo = container.read(holidayRepositoryProvider);
    expect((await repo.getHolidays(2026)).valueOrNull, isEmpty);
    expect(adapter.requests, isEmpty);
  });
}

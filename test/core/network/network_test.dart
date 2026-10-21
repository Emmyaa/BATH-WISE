import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/core/network/dio_providers.dart';
import 'package:bath_wise/core/network/guard_request.dart';
import 'package:bath_wise/core/network/request_deduper.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late FakeHttpAdapter adapter;
  late List<String> logs;

  Dio buildDio({String Function()? token}) {
    logs = [];
    adapter = FakeHttpAdapter();
    return buildApiDio(
      baseUrl: 'https://example.test',
      authToken: token,
      logSink: logs.add,
      retryDelays: const [Duration.zero, Duration.zero],
    )..httpClientAdapter = adapter;
  }

  Future<Result<Object?>> get(Dio dio) =>
      guardRequest(() async => (await dio.get<Object?>('/x')).data);

  group('interceptor chain', () {
    test('adds the raw token and redacts it in logs', () async {
      final dio = buildDio(token: () => 'secret-token');
      adapter.enqueueJson(200, {'ok': true});

      await get(dio);

      expect(adapter.requests.single.headers['Authorization'], 'secret-token');
      expect(logs.join('\n'), isNot(contains('secret-token')));
      expect(logs.first, contains('***'));
    });

    test('clients without a token send no Authorization header', () async {
      final dio = buildDio();
      adapter.enqueueJson(200, {'ok': true});

      await get(dio);

      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('maps BOT 403 to UnauthorizedFailure with its message', () async {
      final dio = buildDio(token: () => 't');
      adapter.enqueueJson(403, loadApiSample('error_unauthorized'));

      final result = await get(dio);

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
      expect(
        result.failureOrNull!.message,
        'Access to this API has been disallowed',
      );
      expect(adapter.requests, hasLength(1), reason: '4xx is never retried');
    });

    test('reads gateway validation messages (31-day limit)', () async {
      final dio = buildDio(token: () => 't');
      adapter.enqueueJson(400, loadApiSample('error_range_limit'));

      final failure = (await get(dio)).failureOrNull;

      expect(failure, isA<ServerFailure>());
      expect(failure!.message, contains('Limit period is 31 days'));
    });

    test('maps 429 to RateLimitFailure with Retry-After', () async {
      final dio = buildDio();
      adapter.enqueueJson(
        429,
        {'error': 'too many'},
        headers: {
          'retry-after': ['120'],
        },
      );

      final failure = (await get(dio)).failureOrNull;

      expect(failure, isA<RateLimitFailure>());
      expect(
        (failure! as RateLimitFailure).retryAfter,
        const Duration(minutes: 2),
      );
    });

    test('retries transient errors, then succeeds', () async {
      final dio = buildDio();
      adapter
        ..enqueueConnectionError()
        ..enqueueJson(503, {'error': 'busy'})
        ..enqueueJson(200, {'ok': true});

      final result = await get(dio);

      expect(result.isOk, isTrue);
      expect(adapter.requests, hasLength(3));
    });

    test('gives up after the configured retries with NetworkFailure', () async {
      final dio = buildDio();
      adapter
        ..enqueueConnectionError()
        ..enqueueConnectionError()
        ..enqueueConnectionError();

      final result = await get(dio);

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(adapter.requests, hasLength(3));
    });
  });

  group('botDataDetail', () {
    test('accepts a list (real responses)', () {
      expect(botDataDetail(loadApiSample('exchange_daily_all')), hasLength(76));
    });

    test('accepts a single object (as the spec documents)', () {
      final body = {
        'result': {
          'data': {
            'data_detail': {'period': '2026-10-19'},
          },
        },
      };
      expect(botDataDetail(body), [
        {'period': '2026-10-19'},
      ]);
    });

    test('throws FormatException without the envelope', () {
      expect(() => botDataDetail({'error': 'x'}), throwsFormatException);
    });
  });

  test('daily ranges are split into windows of at most 31 days', () {
    final chunks = BotExchangeRateApi.dailyChunks(
      DateTime.utc(2026, 7, 20),
      DateTime.utc(2026, 10, 20),
    );
    expect(chunks.first.$1, DateTime.utc(2026, 7, 20));
    expect(chunks.last.$2, DateTime.utc(2026, 10, 20));
    for (final (from, to) in chunks) {
      expect(to.difference(from).inDays + 1, lessThanOrEqualTo(31));
    }
    for (var i = 1; i < chunks.length; i++) {
      expect(chunks[i].$1, chunks[i - 1].$2.add(const Duration(days: 1)));
    }
    expect(
      BotExchangeRateApi.dailyChunks(
        DateTime.utc(2026, 10, 20),
        DateTime.utc(2026, 10, 20),
      ),
      hasLength(1),
    );
  });

  test('RequestDeduper shares one in-flight future per key', () async {
    final deduper = RequestDeduper();
    var calls = 0;
    Future<int> task() async {
      calls++;
      await Future<void>.delayed(Duration.zero);
      return calls;
    }

    final results = await Future.wait([
      deduper.run('a', task),
      deduper.run('a', task),
      deduper.run('b', task),
    ]);

    expect(calls, 2);
    expect(results[0], results[1]);
    // Completed keys run again.
    await deduper.run('a', task);
    expect(calls, 3);
  });
}

import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/rates_list_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  final quotes = sampleSnapshot().quotes;

  group('filterAndSortQuotes', () {
    List<String> codes(RatesListState state) => [
      for (final q in filterAndSortQuotes(quotes, state)) q.currencyCode,
    ];

    test('default keeps BOT order', () {
      expect(codes(const RatesListState()).take(3), ['USD', 'GBP', 'EUR']);
    });

    test('searches code, English and Thai names case-insensitively', () {
      expect(codes(const RatesListState(query: 'jpy')), ['JPY']);
      expect(codes(const RatesListState(query: 'Yen')), ['JPY']);
      expect(codes(const RatesListState(query: 'เยน')), ['JPY']);
      expect(
        codes(const RatesListState(query: ' dollar ')),
        containsAll(['USD', 'HKD', 'SGD', 'BND', 'AUD', 'NZD', 'CAD']),
      );
      expect(codes(const RatesListState(query: 'zzz')), isEmpty);
    });

    test('code sort is alphabetical', () {
      final sorted = codes(const RatesListState(sort: RatesSort.code));
      expect(sorted, [...sorted]..sort());
    });

    test('gainers and losers sort by percent change of the chosen rate', () {
      List<double> percents(RatesSort sort) => [
        for (final q in filterAndSortQuotes(
          quotes,
          RatesListState(sort: sort, rateType: RateType.selling),
        ))
          q.changePercent(RateType.selling)!.toDouble(),
      ];
      final gainers = percents(RatesSort.gainers);
      final losers = percents(RatesSort.losers);
      expect(gainers, [...gainers]..sort((a, b) => b.compareTo(a)));
      expect(losers, [...losers]..sort());
    });
  });

  test('topMovers picks the largest absolute moves', () {
    final movers = topMovers(quotes);
    expect(movers, hasLength(3));
    double size(RateQuote q) => q.changePercent(RateType.mid)!.abs().toDouble();
    final others = quotes.where((q) => !movers.contains(q));
    expect(others.every((q) => size(q) <= size(movers.last)), isTrue);
  });

  group('LatestRatesViewModel', () {
    late FakeFxRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = FakeFxRepository(Ok(sampleSnapshot()));
      container = ProviderContainer.test(overrides: appOverrides(fx: repo));
    });

    test('loads the latest snapshot', () async {
      final snapshot = await container.read(
        latestRatesViewModelProvider.future,
      );
      expect(snapshot.quotes, hasLength(19));
      expect(repo.lastForceRefresh, isFalse);
    });

    test('refresh forces a fetch and returns any degradation', () async {
      await container.read(latestRatesViewModelProvider.future);
      repo.latest = Ok(sampleSnapshot(refreshFailure: const NetworkFailure()));

      final failure = await container
          .read(latestRatesViewModelProvider.notifier)
          .refresh();

      expect(repo.lastForceRefresh, isTrue);
      expect(failure, isA<NetworkFailure>());
      expect(
        container.read(latestRatesViewModelProvider).value!.isDegraded,
        isTrue,
      );
    });

    test('a failed refresh keeps the data on screen', () async {
      await container.read(latestRatesViewModelProvider.future);
      repo.latest = const Err(CacheFailure());

      final failure = await container
          .read(latestRatesViewModelProvider.notifier)
          .refresh();

      expect(failure, isA<CacheFailure>());
      expect(container.read(latestRatesViewModelProvider).hasValue, isTrue);
    });

    test('first load error, then retry succeeds', () async {
      repo.latest = const Err(UnauthorizedFailure());
      await expectLater(
        container.read(latestRatesViewModelProvider.future),
        throwsA(isA<UnauthorizedFailure>()),
      );

      repo.latest = Ok(sampleSnapshot());
      await container.read(latestRatesViewModelProvider.notifier).retry();

      expect(container.read(latestRatesViewModelProvider).hasValue, isTrue);
    });

    test('a failure is not retried automatically (BOT quota)', () async {
      repo.latest = const Err(UnauthorizedFailure());
      await container
          .read(latestRatesViewModelProvider.future)
          .then((_) {}, onError: (_) {});

      // Riverpod's default would retry after 200 ms, 400 ms, ...
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(repo.latestCalls, 1);
    });

    test('visibleQuotes follows search and rate type', () async {
      await container.read(latestRatesViewModelProvider.future);
      container.read(ratesListViewModelProvider.notifier).search('eur');

      expect(
        container.read(visibleQuotesProvider)?.map((q) => q.currencyCode),
        ['EUR'],
      );
    });
  });
}

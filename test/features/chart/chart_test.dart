import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/features/chart/domain/chart_range.dart';
import 'package:bath_wise/features/chart/domain/series_stats.dart';
import 'package:bath_wise/features/chart/presentation/currency_chart_view_model.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_dto.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_helpers.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);
  List<ChartPoint> points(List<String> values) => [
    for (final (i, v) in values.indexed)
      (date: DateTime.utc(2026, 10, 1 + i), value: d(v)),
  ];

  group('ChartRange', () {
    final today = DateTime.utc(2026, 10, 21);

    test('daily ranges end today; 1M fits one 31-day BOT call', () {
      expect(ChartRange.week.startFor(today), DateTime.utc(2026, 10, 14));
      expect(ChartRange.month.startFor(today), DateTime.utc(2026, 9, 21));
      expect(today.difference(ChartRange.month.startFor(today)).inDays, 30);
      expect(ChartRange.threeMonths.startFor(today), DateTime.utc(2026, 7, 21));
    });

    test('1Y and 5Y use monthly averages from the first of a month', () {
      expect(ChartRange.year.periodicity, Periodicity.monthly);
      expect(ChartRange.fiveYears.periodicity, Periodicity.monthly);
      expect(ChartRange.year.startFor(today), DateTime.utc(2025, 10));
      expect(ChartRange.fiveYears.startFor(today), DateTime.utc(2021, 10));
    });

    test('date math rolls over month and year boundaries', () {
      expect(
        ChartRange.threeMonths.startFor(DateTime.utc(2026, 2, 10)),
        DateTime.utc(2025, 11, 10),
      );
      expect(
        ChartRange.week.startFor(DateTime.utc(2026, 1, 3)),
        DateTime.utc(2025, 12, 27),
      );
    });
  });

  group('SeriesStats', () {
    test('high, low, average and change with exact Decimals', () {
      final stats = SeriesStats.of(
        points(['33.10', '33.50', '32.90', '33.30']),
      )!;
      expect(stats.high.value, d('33.50'));
      expect(stats.high.date, DateTime.utc(2026, 10, 2));
      expect(stats.low.value, d('32.90'));
      expect(stats.low.date, DateTime.utc(2026, 10, 3));
      expect(stats.average, d('33.2'));
      expect(stats.change, d('0.2'));
      expect(stats.changePercent, d('0.6042'));
    });

    test('ties keep the earliest date', () {
      final stats = SeriesStats.of(points(['1', '2', '2', '1']))!;
      expect(stats.high.date, DateTime.utc(2026, 10, 2));
      expect(stats.low.date, DateTime.utc(2026, 10));
    });

    test('volatility is the sample std. dev. of percent changes', () {
      // Changes: +1%, −1%, +1% → mean 1/3, variance 4/3.
      final stats = SeriesStats.of(
        points(['100', '101', '99.99', '100.9899']),
      )!;
      expect(stats.volatility, closeTo(1.1547, 1e-4));
    });

    test('a flat series has zero volatility and no change', () {
      final stats = SeriesStats.of(points(['5', '5', '5']))!;
      expect(stats.volatility, 0);
      expect(stats.changePercent, Decimal.zero);
    });

    test('too few points: no volatility; empty: no stats', () {
      expect(SeriesStats.of(points(['1', '2']))!.volatility, isNull);
      expect(SeriesStats.of(points(['1']))!.volatility, isNull);
      expect(SeriesStats.of(const []), isNull);
    });
  });

  group('percentChangeFromFirst', () {
    test('normalizes to percent change from the first point', () {
      final normalized = percentChangeFromFirst(points(['20', '21', '19.5']));
      expect(
        [for (final p in normalized) p.value],
        [Decimal.zero, d('5'), d('-2.5')],
      );
      expect(normalized.last.date, DateTime.utc(2026, 10, 3));
    });

    test('empty or zero-based series cannot be normalized', () {
      expect(percentChangeFromFirst(const []), isEmpty);
      expect(percentChangeFromFirst(points(['0', '1'])), isEmpty);
    });
  });

  group('buildChartView', () {
    test('skips missing mid rates and keeps the series source', () {
      final rates = [
        for (final row in botDataDetail(loadApiSample('exchange_monthly_usd')))
          ?BotExchangeRateDto.fromJson(row).toEntity(Periodicity.monthly),
      ];
      final series = fakeSeries('USD', const []).copyWith(
        periodicity: Periodicity.monthly,
        points: [
          ...rates,
          rates.last.copyWith(period: DateTime.utc(2030), mid: null),
        ],
      );

      final view = buildChartView(ChartRange.year, series);

      expect(view.isComparing, isFalse);
      expect(view.primary.points, hasLength(rates.length));
      expect(view.primary.points.first.value, rates.first.mid);
      expect(view.primary.stats!.last.value, rates.last.mid);
    });

    test('compare mode carries both lines with percent points', () {
      final view = buildChartView(
        ChartRange.month,
        fakeSeries('USD', [33, 33.33]),
        fakeSeries('EUR', [38, 37.62]),
      );
      expect(view.isComparing, isTrue);
      expect(view.primary.percentPoints.last.value, d('1'));
      expect(view.compare!.percentPoints.last.value, d('-1'));
    });
  });

  group('currencyChartProvider', () {
    late FakeFxRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = FakeFxRepository(Ok(sampleSnapshot()))
        ..history = (r) =>
            Ok(fakeSeries(r.code, [1, 2, 3], periodicity: r.periodicity));
      container = ProviderContainer(
        overrides: appOverrides(fx: repo, now: bkk(2026, 10, 21, 9)),
      );
      addTearDown(container.dispose);
    });

    Future<ChartView> chart() async {
      final sub = container.listen(currencyChartProvider('USD'), (_, _) {});
      addTearDown(sub.close);
      return await container.read(currencyChartProvider('USD').future);
    }

    ChartControls controls() =>
        container.read(chartControlsProvider('USD').notifier);

    test('defaults to 1M of daily USD rates ending today in Bangkok', () async {
      final view = await chart();
      expect(view.range, ChartRange.month);
      expect(repo.historyRequests.single, (
        code: 'USD',
        periodicity: Periodicity.daily,
        start: DateTime.utc(2026, 9, 21),
        end: DateTime.utc(2026, 10, 21),
      ));
    });

    test('switching to 5Y asks for monthly averages', () async {
      await chart();
      controls().selectRange(ChartRange.fiveYears);
      final view = await chart();

      expect(view.range, ChartRange.fiveYears);
      expect(repo.historyRequests.last.periodicity, Periodicity.monthly);
      expect(repo.historyRequests.last.start, DateTime.utc(2021, 10));
    });

    test('compare loads both currencies for the same range', () async {
      controls()
        ..selectRange(ChartRange.threeMonths)
        ..compareWith('EUR');
      final view = await chart();

      expect(view.compare!.code, 'EUR');
      expect({for (final r in repo.historyRequests) r.code}, {'USD', 'EUR'});
      expect(
        {for (final r in repo.historyRequests) r.start},
        {DateTime.utc(2026, 7, 21)},
      );

      controls().stopComparing();
      expect((await chart()).compare, isNull);
    });

    test('comparing with itself is ignored', () {
      controls().compareWith('USD');
      expect(container.read(chartControlsProvider('USD')).compareWith, isNull);
    });

    test('a failed history surfaces its Failure', () async {
      repo.history = (r) => r.code == 'EUR'
          ? const Err(RateLimitFailure())
          : Ok(fakeSeries(r.code, [1, 2]));
      controls().compareWith('EUR');

      await expectLater(chart(), throwsA(isA<RateLimitFailure>()));
    });
  });
}

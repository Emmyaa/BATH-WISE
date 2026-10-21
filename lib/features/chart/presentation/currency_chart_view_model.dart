import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/no_auto_retry.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/chart/domain/chart_range.dart';
import 'package:bath_wise/features/chart/domain/series_stats.dart';
import 'package:bath_wise/features/rates/data/rates_providers.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'currency_chart_view_model.freezed.dart';
part 'currency_chart_view_model.g.dart';

@freezed
abstract class ChartControlsState with _$ChartControlsState {
  const factory({
    @Default(ChartRange.month) ChartRange range,

    /// Second currency overlaid in compare mode, or null.
    String? compareWith,
  }) = _ChartControlsState;
}

/// Range and compare selection of one currency's chart. Resets when the
/// detail screen closes.
@riverpod
class ChartControls extends _$ChartControls {
  @override
  ChartControlsState build(String code) => const ChartControlsState();

  void selectRange(ChartRange range) => state = state.copyWith(range: range);

  /// Comparing a currency with itself is meaningless: ignored.
  void compareWith(String other) {
    if (other == code) return;
    state = state.copyWith(compareWith: other);
  }

  void stopComparing() => state = state.copyWith(compareWith: null);
}

/// One plotted currency.
@freezed
abstract class ChartLine with _$ChartLine {
  const factory({
    required String code,
    required RateSource source,

    /// Mid rates as published, oldest first.
    required List<ChartPoint> points,

    /// `points` as percent change from the first, for compare mode.
    required List<ChartPoint> percentPoints,
    required SeriesStats? stats,

    /// Set when the history came from cache because the refresh failed.
    Failure? refreshFailure,
  }) = _ChartLine;
}

@freezed
abstract class ChartView with _$ChartView {
  const factory({
    required ChartRange range,
    required ChartLine primary,

    /// Set in compare mode: both lines are then plotted as percent change.
    ChartLine? compare,
  }) = _ChartView;

  const new _();

  bool get isComparing => compare != null;

  Periodicity get periodicity => range.periodicity;
}

/// History for the current [ChartControls] of [code]. Changing the range
/// or compare currency rebuilds it; the previous view stays available
/// (`value`) while the new one loads.
@Riverpod(retry: noAutoRetry)
Future<ChartView> currencyChart(Ref ref, String code) async {
  final controls = ref.watch(chartControlsProvider(code));
  final repo = ref.watch(fxRepositoryProvider);
  final range = controls.range;
  final today = Bangkok.dateOf(ref.watch(clockProvider).now());

  Future<Result<RateSeries>> load(String currency) => repo.getHistory(
    currencyCode: currency,
    periodicity: range.periodicity,
    start: range.startFor(today),
    end: today,
  );

  // Results never throw, so both requests can run at once safely.
  final (primary, compare) = await (
    load(code),
    switch (controls.compareWith) {
      final other? => load(other),
      null => Future<Result<RateSeries>?>.value(),
    },
  ).wait;
  return buildChartView(range, primary.getOrThrow(), compare?.getOrThrow());
}

/// Pure so it can be unit tested.
ChartView buildChartView(
  ChartRange range,
  RateSeries primary, [
  RateSeries? compare,
]) => ChartView(
  range: range,
  primary: _line(primary),
  compare: compare == null ? null : _line(compare),
);

ChartLine _line(RateSeries series) {
  final points = chartPoints(series.points);
  return ChartLine(
    code: series.currencyCode,
    source: series.source,
    points: points,
    percentPoints: percentChangeFromFirst(points),
    stats: SeriesStats.of(points),
    refreshFailure: series.refreshFailure,
  );
}

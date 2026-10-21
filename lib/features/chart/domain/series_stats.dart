import 'dart:math' as math;

import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'series_stats.freezed.dart';

/// One plotted value: a rate as published (THB per `unit`), or a percent
/// change once normalized.
typedef ChartPoint = ({DateTime date, Decimal value});

/// The [type] values of [rates] that exist, oldest first.
List<ChartPoint> chartPoints(
  List<ExchangeRate> rates, {
  RateType type = RateType.mid,
}) => [
  for (final rate in rates)
    if (rate.valueOf(type) case final value?) (date: rate.period, value: value),
];

/// [points] as percent change from the first one (`0.25` = +0.25%), so
/// currencies of very different magnitudes share one axis.
List<ChartPoint> percentChangeFromFirst(List<ChartPoint> points) {
  if (points.isEmpty || points.first.value == Decimal.zero) return const [];
  final base = points.first.value;
  return [
    for (final p in points)
      (
        date: p.date,
        value: ((p.value - base) * Decimal.fromInt(100)).dividedBy(
          base,
          scale: 4,
        ),
      ),
  ];
}

/// Summary of a series over the chart's range.
@freezed
abstract class SeriesStats with _$SeriesStats {
  const factory({
    required ChartPoint first,
    required ChartPoint last,
    required ChartPoint high,
    required ChartPoint low,
    required Decimal average,

    /// Sample standard deviation of period-over-period percent changes
    /// (daily or monthly, matching the series). Null with fewer than two
    /// changes. A double because it needs a square root; it's only shown.
    required double? volatility,
  }) = _SeriesStats;

  const new _();

  Decimal get change => last.value - first.value;

  /// Null when the first value is zero.
  Decimal? get changePercent => first.value == Decimal.zero
      ? null
      : (change * Decimal.fromInt(100)).dividedBy(first.value, scale: 4);

  /// Null for an empty series.
  static SeriesStats? of(List<ChartPoint> points) {
    if (points.isEmpty) return null;
    var high = points.first;
    var low = points.first;
    var sum = Decimal.zero;
    for (final p in points) {
      // Strict comparisons keep the earliest date on ties.
      if (p.value > high.value) high = p;
      if (p.value < low.value) low = p;
      sum += p.value;
    }
    return SeriesStats(
      first: points.first,
      last: points.last,
      high: high,
      low: low,
      average: sum.dividedBy(Decimal.fromInt(points.length)),
      volatility: _volatility(points),
    );
  }

  static double? _volatility(List<ChartPoint> points) {
    final changes = [
      for (var i = 1; i < points.length; i++)
        if (points[i - 1].value != Decimal.zero)
          ((points[i].value - points[i - 1].value) * Decimal.fromInt(100))
              .dividedBy(points[i - 1].value)
              .toDouble(),
    ];
    if (changes.length < 2) return null;
    final mean = changes.reduce((a, b) => a + b) / changes.length;
    final variance =
        changes.map((c) => (c - mean) * (c - mean)).reduce((a, b) => a + b) /
        (changes.length - 1);
    return math.sqrt(variance);
  }
}

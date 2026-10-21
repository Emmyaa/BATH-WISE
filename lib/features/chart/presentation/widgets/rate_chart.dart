import 'dart:math' as math;

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/features/chart/presentation/currency_chart_view_model.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Line chart of a [ChartView]: rates with a gradient fill, or two
/// currencies as percent change in compare mode. Touch and drag shows a
/// crosshair with a tooltip.
///
/// The caller provides the screen reader summary; the chart itself is
/// excluded from semantics.
class RateChart extends StatelessWidget {
  const new({required this.view, super.key, this.height = 220});

  final ChartView view;
  final double height;

  /// X axis: whole days since the epoch, so both compare lines share it
  /// even when BOT skipped a currency on some day.
  static double _x(DateTime date) =>
      (date.millisecondsSinceEpoch / Duration.millisecondsPerDay)
          .roundToDouble();

  static double _y(Decimal value) => value.toDouble();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.bw;
    final comparing = view.isComparing;
    final series = [
      if (comparing) view.primary.percentPoints else view.primary.points,
      ?view.compare?.percentPoints,
    ];
    final lineColors = [colors.primary, if (comparing) tokens.compareLine];
    final codes = [view.primary.code, ?view.compare?.code];

    final all = [for (final s in series) ...s];
    if (all.isEmpty) return SizedBox(height: height);
    final ys = all.map((p) => _y(p.value));
    final low = ys.reduce(math.min);
    final high = ys.reduce(math.max);
    // Headroom so the line never touches the edges; a flat line gets a
    // small band around it.
    final pad = high > low
        ? (high - low) * 0.12
        : math.max(high.abs(), 1) * 0.01;
    final minY = low - pad;
    final maxY = high + pad;
    final xs = all.map((p) => _x(p.date));
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);

    final axisDigits = _axisDigits((maxY - minY) / 4, percent: comparing);
    final axisStyle = context.text.labelSmall?.tabular.copyWith(
      color: colors.onSurfaceVariant,
    );
    final gridColor = colors.onSurface.withValues(alpha: 0.06);

    String axisValue(double v) {
      final value = Decimal.parse(v.toStringAsFixed(axisDigits));
      return comparing
          ? context.decimals.percent(value, digits: axisDigits)
          : context.decimals.format(value, digits: axisDigits);
    }

    String axisDate(DateTime date) => view.periodicity == Periodicity.daily
        ? context.dates.dayMonth(date)
        : context.dates.month(date, shortYear: true);

    String tooltipDate(DateTime date) => view.periodicity == Periodicity.daily
        ? context.dates.date(date)
        : context.dates.month(date);

    String tooltipValue(Decimal value) => comparing
        ? context.decimals.percent(value)
        : context.decimals.format(value);

    final tooltipStyle = context.text.labelMedium!.tabular.copyWith(
      color: colors.onInverseSurface,
    );
    LineTooltipItem tooltipItem(LineBarSpot spot, {required bool first}) {
      final point = series[spot.barIndex][spot.spotIndex];
      final value = tooltipValue(point.value);
      return LineTooltipItem(
        // The date once, above the first line.
        first ? '${tooltipDate(point.date)}\n' : '',
        tooltipStyle.copyWith(
          color: colors.onInverseSurface.withValues(alpha: 0.75),
        ),
        textAlign: TextAlign.start,
        children: [
          TextSpan(
            text: comparing ? '${codes[spot.barIndex]} $value' : value,
            style: tooltipStyle.copyWith(
              fontWeight: FontWeight.w600,
              // Line color, lifted toward the tooltip text for contrast.
              color: comparing
                  ? Color.lerp(
                      lineColors[spot.barIndex],
                      colors.onInverseSurface,
                      0.35,
                    )
                  : null,
            ),
          ),
        ],
      );
    }

    LineChartBarData bar(int i) {
      final single = !comparing;
      return LineChartBarData(
        spots: [for (final p in series[i]) FlSpot(_x(p.date), _y(p.value))],
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        barWidth: 2.4,
        isStrokeCapRound: true,
        color: single ? null : lineColors[i],
        gradient: single ? tokens.brandGradient : null,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: single,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.26),
              tokens.brandGradient.colors.last.withValues(alpha: 0),
            ],
          ),
        ),
      );
    }

    final data = LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [for (var i = 0; i < series.length; i++) bar(i)],
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: gridColor, strokeWidth: 1, dashArray: const [4, 4]),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        leftTitles: const AxisTitles(),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            getTitlesWidget: (value, meta) =>
                value == meta.min || value == meta.max
                ? const SizedBox.shrink()
                : SideTitleWidget(
                    meta: meta,
                    child: Text(axisValue(value), style: axisStyle),
                  ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: maxX > minX ? (maxX - minX) / 3 : null,
            getTitlesWidget: (value, meta) =>
                value == meta.min || value == meta.max
                ? const SizedBox.shrink()
                : SideTitleWidget(
                    meta: meta,
                    child: Text(
                      axisDate(
                        DateTime.fromMillisecondsSinceEpoch(
                          (value * Duration.millisecondsPerDay).round(),
                          isUtc: true,
                        ),
                      ),
                      style: axisStyle,
                    ),
                  ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        // Crosshair: full-height dashed line plus a dot on each line.
        getTouchLineEnd: (_, _) => double.infinity,
        getTouchedSpotIndicator: (bar, indexes) => [
          for (final _ in indexes)
            TouchedSpotIndicatorData(
              FlLine(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
              FlDotData(
                getDotPainter: (_, _, bar, _) => FlDotCirclePainter(
                  radius: 4.5,
                  color: bar.color ?? colors.primary,
                  strokeWidth: 2,
                  strokeColor: colors.surface,
                ),
              ),
            ),
        ],
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          maxContentWidth: 180,
          getTooltipItems: (spots) => [
            for (final (i, spot) in spots.indexed)
              tooltipItem(spot, first: i == 0),
          ],
        ),
      ),
    );

    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: LineChart(
          data,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.medium,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  /// Enough decimals for axis labels [interval] apart to differ.
  static int _axisDigits(double interval, {required bool percent}) {
    if (interval <= 0) return 2;
    final needed = (-math.log(interval) / math.ln10).ceil() + 1;
    return needed.clamp(percent ? 1 : 2, 4);
  }
}

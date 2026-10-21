import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/change_indicator.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/features/chart/domain/series_stats.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// High / low / average / change / volatility over the chart's range.
class ChartStatsCard extends StatelessWidget {
  const new({required this.stats, required this.periodicity, super.key});

  final SeriesStats stats;
  final Periodicity periodicity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final daily = periodicity == Periodicity.daily;
    String date(DateTime d) =>
        daily ? context.dates.date(d) : context.dates.month(d);
    String rate(Decimal v, [int digits = 4]) =>
        context.decimals.format(v, digits: digits);

    final tiles = [
      _StatTile(
        label: l10n.statHigh,
        value: rate(stats.high.value),
        caption: date(stats.high.date),
      ),
      _StatTile(
        label: l10n.statLow,
        value: rate(stats.low.value),
        caption: date(stats.low.date),
      ),
      _StatTile(label: l10n.statAverage, value: rate(stats.average)),
      _StatTile(
        label: l10n.statVolatility,
        value: switch (stats.volatility) {
          null => '—',
          final v => '${rate(Decimal.parse(v.toStringAsFixed(4)), 2)}%',
        },
        caption: daily ? l10n.statVolatilityDaily : l10n.statVolatilityMonthly,
      ),
      _StatTile(
        label: l10n.statChange,
        valueWidget: ChangeIndicator(
          percent: stats.changePercent,
          change: stats.change,
        ),
        caption: '${date(stats.first.date)} – ${date(stats.last.date)}',
      ),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.statsTitle, style: context.text.titleSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns, one when large text leaves too little room.
              final columns = constraints.maxWidth >= 280 ? 2 : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final tile in tiles) SizedBox(width: width, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const new({required this.label, this.value, this.valueWidget, this.caption})
    : assert((value == null) != (valueWidget == null), 'one value');

  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          const SizedBox(height: AppSpacing.xxs),
          valueWidget ?? Text(value!, style: context.text.titleMedium?.tabular),
          if (caption case final caption?) Text(caption, style: muted),
        ],
      ),
    );
  }
}

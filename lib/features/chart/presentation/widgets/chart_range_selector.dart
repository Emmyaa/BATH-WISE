import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/features/chart/domain/chart_range.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// 1W / 1M / 3M / 1Y / 5Y. Segments announce the full span ("1 month").
class ChartRangeSelector extends StatelessWidget {
  const new({required this.selected, required this.onSelected, super.key});

  final ChartRange selected;
  final ValueChanged<ChartRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<ChartRange>(
      segments: [
        for (final range in ChartRange.values)
          ButtonSegment(
            value: range,
            label: Semantics(
              label: range.spokenLabel(l10n),
              excludeSemantics: true,
              child: Text(range.label(l10n)),
            ),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onSelected(s.single),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

extension ChartRangeLabel on ChartRange {
  String label(AppLocalizations l10n) => switch (this) {
    ChartRange.week => l10n.chartRangeWeek,
    ChartRange.month => l10n.chartRangeMonth,
    ChartRange.threeMonths => l10n.chartRangeThreeMonths,
    ChartRange.year => l10n.chartRangeYear,
    ChartRange.fiveYears => l10n.chartRangeFiveYears,
  };

  String spokenLabel(AppLocalizations l10n) => switch (this) {
    ChartRange.week => l10n.a11yRangeWeek,
    ChartRange.month => l10n.a11yRangeMonth,
    ChartRange.threeMonths => l10n.a11yRangeThreeMonths,
    ChartRange.year => l10n.a11yRangeYear,
    ChartRange.fiveYears => l10n.a11yRangeFiveYears,
  };
}

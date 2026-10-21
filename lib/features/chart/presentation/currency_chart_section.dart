import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/change_indicator.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/features/chart/presentation/currency_chart_view_model.dart';
import 'package:bath_wise/features/chart/presentation/widgets/chart_range_selector.dart';
import 'package:bath_wise/features/chart/presentation/widgets/chart_stats_card.dart';
import 'package:bath_wise/features/chart/presentation/widgets/rate_chart.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/widgets/currency_picker_sheet.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chart, range selector, compare control and stats of [code] on the
/// Currency Detail screen.
class CurrencyChartSection extends ConsumerWidget {
  const new({required this.code, required this.compareCandidates, super.key});

  final String code;

  /// Currencies that can be overlaid (all but [code]).
  final List<String> compareCandidates;

  /// Matches [RateChart]'s default height.
  static const _chartHeight = 220.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controls = ref.watch(chartControlsProvider(code));
    final notifier = ref.read(chartControlsProvider(code).notifier);
    final chart = ref.watch(currencyChartProvider(code));
    // The previous view stays on screen (dimmed) while the next loads.
    final view = chart.value;
    final failure = chart.hasError && !chart.isLoading ? chart.error : null;

    final Widget body;
    if (failure != null) {
      body = _ChartError(
        error: failure,
        onRetry: () => ref.invalidate(currencyChartProvider(code)),
      );
    } else if (view == null) {
      body = Shimmer(
        label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
        child: const SkeletonBox(height: _chartHeight),
      );
    } else if (view.primary.points.length < 2) {
      body = _ChartMessage(
        icon: Icons.show_chart_rounded,
        message: l10n.chartNotEnoughData,
      );
    } else {
      body = AnimatedOpacity(
        opacity: chart.isLoading ? 0.45 : 1,
        duration: AppDurations.fast,
        child: Semantics(
          label: _summary(context, view),
          child: RateChart(view: view),
        ),
      );
    }

    final stats = failure == null ? view?.primary.stats : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l10n.chartTitle, style: context.text.titleSmall),
              ),
            ),
            _CompareButton(
              comparingWith: controls.compareWith,
              onPick: () async {
                final picked = await showCurrencyPicker(
                  context,
                  codes: compareCandidates,
                  selected: controls.compareWith ?? '',
                  title: l10n.chartCompareTitle,
                );
                if (picked != null) notifier.compareWith(picked);
              },
              onStop: notifier.stopComparing,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ChartRangeSelector(
          selected: controls.range,
          onSelected: notifier.selectRange,
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (view?.isComparing ?? false) ...[
                _Legend(view: view!),
                const SizedBox(height: AppSpacing.sm),
              ],
              SizedBox(
                height: _chartHeight,
                child: AnimatedSwitcher(
                  duration: AppDurations.medium,
                  child: KeyedSubtree(
                    key: ValueKey(body.runtimeType),
                    child: body,
                  ),
                ),
              ),
              if (view != null && failure == null) ...[
                const SizedBox(height: AppSpacing.sm),
                _Caption(view: view),
              ],
            ],
          ),
        ),
        if (stats != null) ...[
          const SizedBox(height: AppSpacing.md),
          ChartStatsCard(stats: stats, periodicity: view!.periodicity),
        ],
      ],
    );
  }

  String _summary(BuildContext context, ChartView view) {
    final l10n = context.l10n;
    final range = view.range.spokenLabel(l10n);
    if (view.compare case final compare?) {
      String line(ChartLine l) => l10n.a11yCompareLine(
        l.code,
        describeChange(context, l.stats?.changePercent),
      );
      return l10n.a11yCompareChart(range, line(view.primary), line(compare));
    }
    final stats = view.primary.stats!;
    final rate = context.decimals.format;
    return l10n.a11yChart(
      context.currencyName(view.primary.code),
      range,
      rate(stats.first.value),
      rate(stats.last.value),
      describeChange(context, stats.changePercent),
    );
  }
}

class _CompareButton extends StatelessWidget {
  const new({
    required this.comparingWith,
    required this.onPick,
    required this.onStop,
  });

  final String? comparingWith;
  final VoidCallback onPick;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (comparingWith) {
      null => TextButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.compare_arrows_rounded),
        label: Text(l10n.chartCompare),
      ),
      final other => InputChip(
        avatar: CurrencyFlag(code: other, size: 20),
        label: Text(l10n.chartVersus(other)),
        onPressed: onPick,
        onDeleted: onStop,
        deleteButtonTooltipMessage: l10n.chartStopComparing(other),
      ),
    };
  }
}

/// Which color is which currency, with each one's change over the range.
class _Legend extends StatelessWidget {
  const new({required this.view});

  final ChartView view;

  @override
  Widget build(BuildContext context) {
    final lines = [
      (view.primary, context.colors.primary),
      (view.compare!, context.bw.compareLine),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (line, color) in lines)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(line.code, style: context.text.labelLarge),
              const SizedBox(width: AppSpacing.xxs),
              ChangeIndicator(percent: line.stats?.changePercent),
            ],
          ),
      ],
    );
  }
}

/// Source and kind of data, plus a note when it's saved data.
class _Caption extends StatelessWidget {
  const new({required this.view});

  final ChartView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = switch (view.primary.source) {
      RateSource.bot => l10n.sourceBot,
      RateSource.ecb => l10n.sourceEcb,
    };
    final start = view.primary.points.firstOrNull?.date;
    final stale =
        view.primary.refreshFailure != null ||
        view.compare?.refreshFailure != null;
    final lines = [
      if (view.isComparing && start != null)
        l10n.chartCaptionCompare(
          view.periodicity == Periodicity.daily
              ? context.dates.date(start)
              : context.dates.month(start),
        ),
      if (view.periodicity == Periodicity.daily)
        l10n.chartCaptionDaily(source)
      else
        l10n.chartCaptionMonthly(source),
      if (stale) l10n.chartStale,
    ];
    return Text(
      lines.join('\n'),
      style: context.text.bodySmall?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  const new({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (error) {
      final Failure f => f.localized(l10n),
      _ => l10n.errorGeneric,
    };
    return _ChartMessage(
      icon: Icons.error_outline_rounded,
      message: '${l10n.chartErrorTitle}\n$message',
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.retry),
      ),
    );
  }
}

class _ChartMessage extends StatelessWidget {
  const new({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    // Scrolls rather than overflows at large text sizes.
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: muted),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: muted),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/animated_decimal_text.dart';
import 'package:bath_wise/core/widgets/change_indicator.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/chart/presentation/currency_chart_section.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_type_selector.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rates_status.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_codes_provider.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currency Detail: header (Hero target), history chart with compare mode
/// and stats, and today's rates.
class CurrencyDetailScreen extends ConsumerWidget {
  const new({required this.code, super.key, this.heroTag});

  final String code;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(latestRatesViewModelProvider).value;
    final quote = snapshot?.quoteFor(code);

    return Scaffold(
      appBar: AppBar(
        title: Text(code),
        actions: [if (quote != null) _WatchlistToggle(code: code)],
      ),
      body: CurrencyDetailView(code: code, heroTag: heroTag),
    );
  }
}

/// The body of Currency Detail, also used as the detail pane of the
/// Rates screen on wide layouts.
class CurrencyDetailView extends ConsumerWidget {
  const new({required this.code, super.key, this.heroTag});

  final String code;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(latestRatesViewModelProvider).value;
    final quote = snapshot?.quoteFor(code);
    if (snapshot == null || quote == null) {
      return EmptyStateView(
        icon: Icons.currency_exchange_rounded,
        message: context.l10n.errorNoData,
      );
    }
    return ListView(
      padding: AppSpacing.screen.add(
        const EdgeInsets.only(bottom: AppSpacing.xl),
      ),
      children: [
        _Header(quote: quote, heroTag: heroTag ?? 'detail-$code'),
        const SizedBox(height: AppSpacing.sm),
        RatesStatusLines(
          snapshot: snapshot,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DegradedDataBanner(snapshot: snapshot),
        const SizedBox(height: AppSpacing.md),
        CurrencyChartSection(
          code: code,
          compareCandidates: [
            for (final q in snapshot.quotes)
              if (q.currencyCode != code) q.currencyCode,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _RatesTable(quote: quote),
      ],
    );
  }
}

/// Star: adds [code] to the watchlist, or removes it (with undo).
class _WatchlistToggle extends ConsumerWidget {
  const new({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final listed = ref.watch(watchlistCodesProvider).contains(code);
    final viewModel = ref.read(watchlistViewModelProvider.notifier);
    return IconButton(
      isSelected: listed,
      tooltip: listed ? l10n.watchlistToggleRemove : l10n.watchlistToggleAdd,
      icon: const Icon(Icons.star_outline_rounded),
      selectedIcon: Icon(Icons.star_rounded, color: context.colors.primary),
      onPressed: () async {
        if (!listed) {
          await viewModel.add(code);
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        final removed = await viewModel.remove(code);
        if (removed == null) return;
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.watchlistRemoved(code)),
              persist: false,
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () => viewModel.undoRemove(removed),
              ),
            ),
          );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.quote, required this.heroTag});

  final RateQuote quote;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    final rate = quote.current;
    final mid = rate.mid;
    return Column(
      children: [
        CurrencyFlag(code: rate.currencyCode, size: 72, heroTag: heroTag),
        const SizedBox(height: AppSpacing.sm),
        Text(context.localizedName(quote), style: context.text.titleMedium),
        if (rate.unit != 1)
          Text(
            context.l10n.perUnits('${rate.unit}', rate.currencyCode),
            style: context.text.bodySmall,
          ),
        const SizedBox(height: AppSpacing.xs),
        if (mid != null)
          AnimatedDecimalText(
            value: mid,
            countUp: true,
            style: context.text.displaySmall,
          ),
        const SizedBox(height: AppSpacing.xs),
        ChangeIndicator(
          percent: quote.changePercent(RateType.mid),
          change: quote.change(RateType.mid),
        ),
      ],
    );
  }
}

class _RatesTable extends StatelessWidget {
  const new({required this.quote});

  final RateQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.detailRates, style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final type in RateType.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: Text(type.label(l10n))),
                  Text(switch (quote.current.valueOf(type)) {
                    null => '—',
                    final v => context.decimals.format(v),
                  }, style: context.text.titleMedium?.tabular),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

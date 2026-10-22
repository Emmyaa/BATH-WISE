import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/core/widgets/entrance.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/loan_rates/presentation/average_loan_rates_provider.dart';
import 'package:bath_wise/features/loan_rates/presentation/loan_rates_view_model.dart';
import 'package:bath_wise/features/loan_rates/presentation/widgets/loan_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// MOR / MLR / MRR per bank, sortable and filterable by bank type, with
/// BOT's market average on top.
class LoanRatesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loanRatesViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.loanRatesTitle),
        actions: [if (loans.hasValue) const _SortMenu()],
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: switch (loans) {
          AsyncValue(hasValue: true, :final value) => _LoanRatesContent(value!),
          AsyncValue(error: final error?) => ErrorStateView(
            error: error,
            title: context.l10n.loanErrorTitle,
            onRetry: ref.read(loanRatesViewModelProvider.notifier).retry,
          ),
          _ => const _LoanRatesSkeleton(),
        },
      ),
    );
  }
}

extension on LoanSort {
  LoanMetric? get metric => switch (this) {
    LoanSort.name => null,
    LoanSort.mor => LoanMetric.mor,
    LoanSort.mlr => LoanMetric.mlr,
    LoanSort.mrr => LoanMetric.mrr,
  };
}

class _LoanRatesContent extends ConsumerWidget {
  const new(this.snapshot);

  final LoanRatesSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final listState = ref.watch(loanRatesListViewModelProvider);
    final banks = filterAndSortLoanRates(snapshot.rates, listState, thai: thai);
    final average = ref.watch(averageLoanRatesProvider).value?.rates.first;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(averageLoanRatesProvider);
        final failure = await ref
            .read(loanRatesViewModelProvider.notifier)
            .refresh();
        if (failure != null && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.localized(l10n))));
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (average != null)
                SliverPadding(
                  padding: AppSpacing.screen.copyWith(top: AppSpacing.xs),
                  sliver: SliverToBoxAdapter(
                    child: _AverageCard(average: average, sort: listState.sort),
                  ),
                ),
              SliverToBoxAdapter(
                child: _BankTypeFilter(
                  types: bankTypesOf(snapshot.rates),
                  selected: listState.bankType,
                ),
              ),
              SliverPadding(
                padding: AppSpacing.screen.copyWith(bottom: AppSpacing.sm),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(
                        l10n.loanAsOf(context.dates.date(snapshot.asOf)),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      _StaleBanner(snapshot: snapshot),
                    ],
                  ),
                ),
              ),
              if (banks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateView(
                    icon: Icons.account_balance_outlined,
                    message: l10n.loanNoBanks,
                  ),
                )
              else
                SliverPadding(
                  padding: AppSpacing.screen,
                  sliver: SliverList.separated(
                    itemCount: banks.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) => KeyedSubtree(
                      key: ValueKey(banks[i].nameEn),
                      child: _BankTile(
                        rate: banks[i],
                        highlight: listState.sort.metric,
                      ).entrance(context, i),
                    ),
                  ),
                ),
              SliverPadding(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.lg,
                  bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.loanGlossary,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  const new({required this.average, required this.sort});

  final LoanRate average;
  final LoanSort sort;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.l10n.loanAverageTitle,
              style: context.text.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LoanMetricsRow(rate: average, highlight: sort.metric, large: true),
        ],
      ),
    );
  }
}

class _BankTypeFilter extends ConsumerWidget {
  const new({required this.types, required this.selected});

  final List<BankType> types;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One type (or none) leaves nothing to filter.
    if (types.length < 2) return const SizedBox(height: AppSpacing.sm);
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final viewModel = ref.read(loanRatesListViewModelProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppSpacing.screen.add(
        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      ),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          ChoiceChip(
            label: Text(context.l10n.loanFilterAll),
            selected: selected == null,
            onSelected: (_) => viewModel.filterBankType(null),
          ),
          for (final type in types)
            ChoiceChip(
              label: Text(thai ? type.th : type.en),
              selected: selected == type.en,
              onSelected: (_) => viewModel.filterBankType(type.en),
            ),
        ],
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const new({required this.rate, required this.highlight});

  final LoanRate rate;
  final LoanMetric? highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final name = thai && rate.nameTh.isNotEmpty ? rate.nameTh : rate.nameEn;
    final type = (thai ? rate.bankTypeTh : rate.bankTypeEn) ?? '';
    return Semantics(
      label: l10n.a11yLoanBank(
        name,
        type,
        formatLoanRate(context, rate.mor),
        formatLoanRate(context, rate.mlr),
        formatLoanRate(context, rate.mrr),
      ),
      excludeSemantics: true,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: context.text.titleMedium),
            if (type.isNotEmpty)
              Text(
                type,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            LoanMetricsRow(rate: rate, highlight: highlight),
          ],
        ),
      ),
    );
  }
}

/// Explains cached data after a failed refresh.
class _StaleBanner extends ConsumerWidget {
  const new({required this.snapshot});

  final LoanRatesSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = snapshot.refreshFailure;
    if (failure == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final saved = context.dates.updatedAt(
      snapshot.fetchedAt,
      now: ref.watch(clockProvider).now(),
    );
    return failure is NetworkFailure
        ? StatusBanner(
            icon: Icons.wifi_off_rounded,
            message: l10n.bannerOffline(saved),
          )
        : StatusBanner(
            icon: Icons.history_rounded,
            message: l10n.bannerStale(saved),
          );
  }
}

class _SortMenu extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(
      loanRatesListViewModelProvider.select((s) => s.sort),
    );
    return PopupMenuButton<LoanSort>(
      tooltip: l10n.sortTooltip,
      icon: const Icon(Icons.sort_rounded),
      initialValue: current,
      onSelected: ref.read(loanRatesListViewModelProvider.notifier).sortBy,
      itemBuilder: (_) => [
        for (final sort in LoanSort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == current,
            child: Text(switch (sort.metric) {
              null => l10n.loanSortName,
              final metric => l10n.loanSortLowest(metric.label),
            }),
          ),
      ],
    );
  }
}

class _LoanRatesSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.screen,
        children: [
          const SkeletonBox(height: 96, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 5; i++) ...[
            const SkeletonBox(height: 104, radius: AppRadius.lg),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/router/app_routes.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/entrance.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/rates_list_view_model.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_type_selector.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rates_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RatesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(latestRatesViewModelProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(context.l10n.tabRates),
        actions: const [_SortMenu()],
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: switch (rates) {
          AsyncValue(hasValue: true, :final value) => _RatesContent(value!),
          AsyncValue(error: final error?) => ErrorStateView(
            error: error,
            onRetry: ref.read(latestRatesViewModelProvider.notifier).retry,
          ),
          _ => const _RatesSkeleton(),
        },
      ),
    );
  }
}

class _RatesContent extends ConsumerWidget {
  const new(this.snapshot);

  final RatesSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(ratesListViewModelProvider);
    final quotes = ref.watch(visibleQuotesProvider) ?? const <RateQuote>[];
    final midOnly = snapshot.source == RateSource.ecb;
    final rateType = midOnly ? RateType.mid : listState.rateType;
    final viewModel = ref.read(ratesListViewModelProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async {
        final failure = await ref
            .read(latestRatesViewModelProvider.notifier)
            .refresh();
        if (failure != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.localized(context.l10n))),
          );
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _SearchField()),
          SliverToBoxAdapter(
            child: RateTypeSelector(
              selected: rateType,
              midOnly: midOnly,
              onSelected: viewModel.showRateType,
            ),
          ),
          SliverPadding(
            padding: AppSpacing.screen.add(
              const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  RatesStatusLines(
                    snapshot: snapshot,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  DegradedDataBanner(snapshot: snapshot),
                ],
              ),
            ),
          ),
          if (quotes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.search_off_rounded,
                message: context.l10n.noResults(listState.query.trim()),
              ),
            )
          else
            SliverPadding(
              padding: AppSpacing.screen,
              sliver: SliverList.separated(
                itemCount: quotes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final code = quotes[i].currencyCode;
                  final heroTag = 'rates-flag-$code';
                  return KeyedSubtree(
                    key: ValueKey(code),
                    child: RateTile(
                      quote: quotes[i],
                      rateType: rateType,
                      heroTag: heroTag,
                      onTap: () => context.push(
                        AppRoutes.currency(code),
                        extra: heroTag,
                      ),
                    ).entrance(context, i),
                  );
                },
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final _controller = TextEditingController(
    text: ref.read(ratesListViewModelProvider).query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(ratesListViewModelProvider.notifier).search(value);
    setState(() {}); // toggles the clear button
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.screen.add(
        const EdgeInsets.only(bottom: AppSpacing.sm),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.searchCurrencies,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(ratesListViewModelProvider.select((s) => s.sort));
    return PopupMenuButton<RatesSort>(
      tooltip: l10n.sortTooltip,
      icon: const Icon(Icons.sort_rounded),
      initialValue: current,
      onSelected: ref.read(ratesListViewModelProvider.notifier).sortBy,
      itemBuilder: (_) => [
        for (final (sort, label) in [
          (RatesSort.defaultOrder, l10n.sortDefault),
          (RatesSort.code, l10n.sortCode),
          (RatesSort.gainers, l10n.sortGainers),
          (RatesSort.losers, l10n.sortLosers),
        ])
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == current,
            child: Text(label),
          ),
      ],
    );
  }
}

class _RatesSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.screen,
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, _) => const Row(
          children: [
            SkeletonBox(width: 40, height: 40, radius: 20),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  SkeletonBox(width: 56),
                  SkeletonBox(width: 120, height: 10),
                ],
              ),
            ),
            SkeletonBox(width: 72, height: 18),
          ],
        ),
      ),
    );
  }
}

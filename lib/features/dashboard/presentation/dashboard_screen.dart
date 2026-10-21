import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/router/app_routes.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/widgets/entrance.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/dashboard/presentation/widgets/hero_rate_card.dart';
import 'package:bath_wise/features/dashboard/presentation/widgets/loan_rate_card.dart';
import 'package:bath_wise/features/dashboard/presentation/widgets/watchlist_carousel.dart';
import 'package:bath_wise/features/loan_rates/presentation/average_loan_rates_provider.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/rates_list_view_model.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rates_status.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_codes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(latestRatesViewModelProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(context.l10n.appTitle)),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: switch (rates) {
          AsyncValue(hasValue: true, :final value) => _DashboardContent(value!),
          AsyncValue(error: final error?) => ErrorStateView(
            error: error,
            onRetry: ref.read(latestRatesViewModelProvider.notifier).retry,
          ),
          _ => const _DashboardSkeleton(),
        },
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const new(this.snapshot);

  final RatesSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final watchlist = [
      for (final code in ref.watch(watchlistCodesProvider))
        ?snapshot.quoteFor(code),
    ];
    final movers = topMovers(snapshot.quotes);
    void openDetail(String code, Object heroTag) =>
        context.push(AppRoutes.currency(code), extra: heroTag);

    final sections = <Widget>[
      Padding(
        padding: AppSpacing.screen,
        child: HeroRateCard(
          snapshot: snapshot,
          heroTag: 'dashboard-hero-USD',
          onTap: () => openDetail('USD', 'dashboard-hero-USD'),
        ),
      ),
      if (snapshot.isDegraded)
        Padding(
          padding: AppSpacing.screen.add(
            const EdgeInsets.only(top: AppSpacing.sm),
          ),
          child: DegradedDataBanner(snapshot: snapshot),
        ),
      if (watchlist.isNotEmpty) ...[
        Padding(
          padding: AppSpacing.screen,
          child: SectionHeader(
            title: l10n.dashboardWatchlist,
            actionLabel: l10n.seeAll,
            onAction: () => context.go(AppRoutes.watchlist),
          ),
        ),
        WatchlistCarousel(
          quotes: watchlist,
          onTap: (quote, tag) => openDetail(quote.currencyCode, tag),
        ),
      ],
      if (movers.isNotEmpty) ...[
        Padding(
          padding: AppSpacing.screen,
          child: SectionHeader(
            title: l10n.dashboardTopMovers,
            actionLabel: l10n.seeAll,
            onAction: () {
              ref
                  .read(ratesListViewModelProvider.notifier)
                  .sortBy(RatesSort.gainers);
              context.go(AppRoutes.rates);
            },
          ),
        ),
        for (final quote in movers)
          Padding(
            padding: AppSpacing.screen.add(
              const EdgeInsets.only(bottom: AppSpacing.xs),
            ),
            child: RateTile(
              quote: quote,
              rateType: RateType.mid,
              heroTag: 'dashboard-mover-${quote.currencyCode}',
              onTap: () => openDetail(
                quote.currencyCode,
                'dashboard-mover-${quote.currencyCode}',
              ),
            ),
          ),
      ],
      Padding(
        padding: AppSpacing.screen.add(
          const EdgeInsets.only(top: AppSpacing.lg),
        ),
        child: LoanRateCard(onTap: () => context.push(AppRoutes.loanRates)),
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(averageLoanRatesProvider);
        final failure = await ref
            .read(latestRatesViewModelProvider.notifier)
            .refresh();
        if (failure != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.localized(context.l10n))),
          );
        }
      },
      child: Center(
        // Comfortable reading width on tablets.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
            children: [
              for (final (i, section) in sections.indexed)
                section.entrance(context, i),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.screen,
        children: const [
          SkeletonBox(height: 200, radius: AppRadius.xl),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(width: 120, height: 18),
          SizedBox(height: AppSpacing.sm),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(child: SkeletonBox(height: 140, radius: AppRadius.lg)),
              Expanded(child: SkeletonBox(height: 140, radius: AppRadius.lg)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 64, radius: AppRadius.lg),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(height: 64, radius: AppRadius.lg),
        ],
      ),
    );
  }
}

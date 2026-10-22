import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/router/app_routes.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/widgets/currency_picker_sheet.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rates_status.dart';
import 'package:bath_wise/features/watchlist/presentation/rate_alerts_view_model.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_view_model.dart';
import 'package:bath_wise/features/watchlist/presentation/widgets/rate_alerts_sheet.dart';
import 'package:bath_wise/features/watchlist/presentation/widgets/watchlist_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Watchlist: reorder by dragging, swipe to remove (with undo), rate
/// alerts per currency.
class WatchlistScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(latestRatesViewModelProvider);
    final codes = ref.watch(watchlistViewModelProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(context.l10n.tabWatchlist),
        actions: [
          if (rates.value case final snapshot?)
            IconButton(
              tooltip: context.l10n.watchlistAdd,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => addToWatchlist(context, ref, snapshot),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: switch ((rates, codes)) {
          (AsyncValue(hasValue: true, value: final snapshot?), AsyncData()) =>
            _WatchlistContent(snapshot),
          (AsyncValue(error: final error?), _) => ErrorStateView(
            error: error,
            onRetry: ref.read(latestRatesViewModelProvider.notifier).retry,
          ),
          (_, AsyncError(:final error)) => ErrorStateView(
            error: error,
            onRetry: () => ref.invalidate(watchlistViewModelProvider),
          ),
          _ => const _WatchlistSkeleton(),
        },
      ),
    );
  }
}

/// Lets the user pick a currency that isn't listed yet and appends it.
@visibleForTesting
Future<void> addToWatchlist(
  BuildContext context,
  WidgetRef ref,
  RatesSnapshot snapshot,
) async {
  final listed = ref.read(watchlistViewModelProvider).value ?? const [];
  final candidates = [
    for (final q in snapshot.quotes)
      if (!listed.contains(q.currencyCode)) q.currencyCode,
  ];
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.l10n.watchlistAllAdded)));
    return;
  }
  final code = await showCurrencyPicker(
    context,
    codes: candidates,
    selected: '',
    title: context.l10n.watchlistAddTitle,
  );
  if (code == null) return;
  await ref.read(watchlistViewModelProvider.notifier).add(code);
}

class _WatchlistContent extends ConsumerWidget {
  const new(this.snapshot);

  final RatesSnapshot snapshot;

  Future<void> _remove(BuildContext context, WidgetRef ref, String code) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(watchlistViewModelProvider.notifier);
    final removed = await viewModel.remove(code);
    if (removed == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.watchlistRemoved(code)),
          // Auto-hide like any other snackbar; undo is a convenience.
          persist: false,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => viewModel.undoRemove(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final codes = ref.watch(watchlistViewModelProvider).value ?? const [];
    final alerts = ref.watch(rateAlertsViewModelProvider).value ?? const [];

    if (codes.isEmpty) {
      return EmptyStateView(
        icon: Icons.star_outline_rounded,
        message: l10n.watchlistEmpty,
        action: FilledButton.icon(
          onPressed: () => addToWatchlist(context, ref, snapshot),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.watchlistAdd),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final failure = await ref
            .read(latestRatesViewModelProvider.notifier)
            .refresh();
        if (failure != null && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.localized(l10n))));
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ReorderableListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: AppSpacing.screen.copyWith(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
            header: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            // The dragged card keeps its own rounded shadow.
            proxyDecorator: (child, _, _) =>
                Material(type: MaterialType.transparency, child: child),
            onReorderItem: ref.read(watchlistViewModelProvider.notifier).move,
            itemCount: codes.length,
            itemBuilder: (context, i) {
              final code = codes[i];
              final heroTag = 'watchlist-flag-$code';
              final activeAlerts = alerts
                  .where((a) => a.currencyCode == code && a.enabled)
                  .length;
              return Padding(
                key: ValueKey(code),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Dismissible(
                  key: ValueKey('dismiss-$code'),
                  direction: DismissDirection.endToStart,
                  background: const _RemoveBackground(),
                  onDismissed: (_) => _remove(context, ref, code),
                  child: WatchlistTile(
                    code: code,
                    quote: snapshot.quoteFor(code),
                    index: i,
                    activeAlerts: activeAlerts,
                    heroTag: heroTag,
                    onTap: () =>
                        context.push(AppRoutes.currency(code), extra: heroTag),
                    onAlerts: () => showRateAlertsSheet(context, code),
                    // Swiping isn't available to screen reader users.
                    onRemove: () => _remove(context, ref, code),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.error;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.card,
      ),
      child: Icon(Icons.delete_outline_rounded, color: color),
    );
  }
}

class _WatchlistSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.screen,
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (_, _) =>
            const SkeletonBox(height: 64, radius: AppRadius.lg),
      ),
    );
  }
}

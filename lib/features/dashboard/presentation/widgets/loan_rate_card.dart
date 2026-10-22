import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/loan_rates/presentation/average_loan_rates_provider.dart';
import 'package:bath_wise/features/loan_rates/presentation/widgets/loan_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Average MOR / MLR / MRR. Tapping opens the Loan Rates screen.
class LoanRateCard extends ConsumerWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loans = ref.watch(averageLoanRatesProvider);

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                color: context.colors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.loanCardTitle, style: context.text.titleSmall),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (loans) {
            AsyncValue(hasValue: true, :final value) => _Metrics(value!),
            AsyncValue(:final error?) => _Unavailable(error),
            _ => const Shimmer(
              label: '',
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(child: SkeletonBox(height: 36)),
                  Expanded(child: SkeletonBox(height: 36)),
                  Expanded(child: SkeletonBox(height: 36)),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const new(this.snapshot);

  final LoanRatesSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final average = snapshot.rates.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoanMetricsRow(rate: average, large: true),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${context.l10n.loanCardSubtitle} · '
          '${context.dates.date(snapshot.asOf)}',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const new(this.error);

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = error is Failure
        ? (error as Failure).localized(l10n)
        : l10n.errorGeneric;
    return Text(
      '${l10n.loanCardUnavailable} $reason',
      style: context.text.bodySmall?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

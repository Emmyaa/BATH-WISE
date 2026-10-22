import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// The three headline loan rates.
enum LoanMetric { mor, mlr, mrr }

extension LoanMetricInfo on LoanMetric {
  String get label => name.toUpperCase();

  /// Spelled out, for screen readers and the glossary.
  String fullName(AppLocalizations l10n) => switch (this) {
    LoanMetric.mor => l10n.loanMorFull,
    LoanMetric.mlr => l10n.loanMlrFull,
    LoanMetric.mrr => l10n.loanMrrFull,
  };

  Decimal? of(LoanRate rate) => switch (this) {
    LoanMetric.mor => rate.mor,
    LoanMetric.mlr => rate.mlr,
    LoanMetric.mrr => rate.mrr,
  };
}

/// "6.95%", or "—" when missing.
String formatLoanRate(BuildContext context, Decimal? value) =>
    value == null ? '—' : '${context.decimals.format(value, digits: 2)}%';

/// MOR / MLR / MRR side by side. [highlight] (the sort column) is drawn
/// in the primary color.
class LoanMetricsRow extends StatelessWidget {
  const new({
    required this.rate,
    super.key,
    this.highlight,
    this.large = false,
  });

  final LoanRate rate;
  final LoanMetric? highlight;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metric in LoanMetric.values)
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    semanticsLabel: metric.fullName(context.l10n),
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatLoanRate(context, metric.of(rate)),
                    style:
                        (large
                                ? context.text.titleLarge
                                : context.text.titleMedium)
                            ?.tabular
                            .copyWith(
                              color: metric == highlight
                                  ? context.colors.primary
                                  : null,
                            ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

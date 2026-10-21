import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/animated_decimal_text.dart';
import 'package:bath_wise/core/widgets/change_indicator.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rates_status.dart';
import 'package:flutter/material.dart';

/// Gradient card with the USD/THB mid rate, its daily change and why the
/// data is for the date it is.
class HeroRateCard extends StatelessWidget {
  const new({
    required this.snapshot,
    required this.onTap,
    super.key,
    this.currencyCode = 'USD',
    this.heroTag,
  });

  final RatesSnapshot snapshot;
  final String currencyCode;
  final VoidCallback onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final quote = snapshot.quoteFor(currencyCode) ?? snapshot.quotes.first;
    final code = quote.currencyCode;
    final mid = quote.current.mid;
    final percent = quote.changePercent(RateType.mid);
    final l10n = context.l10n;
    const onHero = Colors.white;
    final caption = context.text.bodySmall?.copyWith(
      color: onHero.withValues(alpha: 0.85),
    );

    return Semantics(
      button: true,
      label: l10n.a11yHeroRate(
        mid == null ? '—' : context.decimals.format(mid),
        describeChange(context, percent),
        ratesStatusText(context, snapshot, null),
      ),
      excludeSemantics: true,
      child: GlassCard(
        gradient: context.bw.heroGradient,
        borderRadius: AppRadius.hero,
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CurrencyFlag(code: code, size: 32, heroTag: heroTag),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$code / THB',
                    style: context.text.titleMedium?.copyWith(color: onHero),
                  ),
                ),
                _SourceChip(source: snapshot.source),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (mid != null)
              AnimatedDecimalText(
                value: mid,
                countUp: true,
                style: context.text.displayMedium?.copyWith(color: onHero),
              ),
            const SizedBox(height: AppSpacing.xs),
            ChangeIndicator(
              percent: percent,
              change: quote.change(RateType.mid),
              onGradient: true,
            ),
            const SizedBox(height: AppSpacing.md),
            RatesStatusLines(snapshot: snapshot, style: caption),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const new({required this.source});

  final RateSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            source == RateSource.bot
                ? Icons.verified_rounded
                : Icons.public_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            source == RateSource.bot ? l10n.sourceBot : l10n.sourceEcb,
            style: context.text.labelSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

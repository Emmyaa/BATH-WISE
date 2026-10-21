import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/change_indicator.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/core/widgets/sparkline.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:flutter/material.dart';

/// Horizontally scrolling watchlist cards with sparklines.
class WatchlistCarousel extends StatelessWidget {
  const new({required this.quotes, required this.onTap, super.key});

  final List<RateQuote> quotes;
  final void Function(RateQuote quote, Object heroTag) onTap;

  @override
  Widget build(BuildContext context) {
    // Grow with the user's text size instead of clipping.
    final height = MediaQuery.textScalerOf(context).scale(172);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: quotes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final quote = quotes[i];
          final heroTag = 'dashboard-watch-${quote.currencyCode}';
          return SizedBox(
            width: 152,
            child: _WatchCard(
              quote: quote,
              heroTag: heroTag,
              onTap: () => onTap(quote, heroTag),
            ),
          );
        },
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const new({required this.quote, required this.heroTag, required this.onTap});

  final RateQuote quote;
  final Object heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mid = quote.current.mid;
    final percent = quote.changePercent(RateType.mid);
    final valueText = mid == null ? '—' : context.decimals.format(mid);
    return Semantics(
      button: true,
      label: context.l10n.a11yRate(
        context.localizedName(quote),
        valueText,
        quote.current.unit == 1
            ? ''
            : context.l10n.perUnits(
                '${quote.current.unit}',
                quote.currencyCode,
              ),
        describeChange(context, percent),
      ),
      excludeSemantics: true,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CurrencyFlag(
                  code: quote.currencyCode,
                  size: 28,
                  heroTag: heroTag,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(quote.currencyCode, style: context.text.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(valueText, style: context.text.titleLarge?.tabular),
            const SizedBox(height: AppSpacing.xxs),
            ChangeIndicator(percent: percent),
            const SizedBox(height: AppSpacing.xs),
            // Takes whatever height is left, so larger text never clips.
            Expanded(
              child: Sparkline(
                values: [
                  for (final r in quote.recent)
                    if (r.mid case final v?) v.toDouble(),
                ],
                color: context.bw.changeColor(percent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

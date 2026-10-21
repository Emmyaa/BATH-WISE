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
import 'package:flutter/material.dart';

/// One currency row: flag, code/name, sparkline, rate and change.
///
/// Read as a single sentence by screen readers.
class RateTile extends StatelessWidget {
  const new({
    required this.quote,
    required this.rateType,
    required this.heroTag,
    required this.onTap,
    super.key,
  });

  final RateQuote quote;
  final RateType rateType;
  final Object heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = quote.current;
    final value = rate.valueOf(rateType);
    final percent = quote.changePercent(rateType);
    final name = context.localizedName(quote);
    final perUnit = rate.unit == 1
        ? ''
        : context.l10n.perUnits('${rate.unit}', rate.currencyCode);
    final valueText = value == null ? '—' : context.decimals.format(value);
    final sparkValues = [
      for (final r in quote.recent)
        // Drawing only; see Sparkline.
        if (r.valueOf(rateType) case final v?) v.toDouble(),
    ];

    return Semantics(
      button: true,
      label: context.l10n.a11yRate(
        name,
        valueText,
        perUnit,
        describeChange(context, percent),
      ),
      excludeSemantics: true,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CurrencyFlag(code: rate.currencyCode, heroTag: heroTag),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rate.currencyCode, style: context.text.titleMedium),
                  Text(
                    perUnit.isEmpty ? name : '$name · $perUnit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 32,
                child: Sparkline(
                  values: sparkValues,
                  color: context.bw.changeColor(percent),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(valueText, style: context.text.titleMedium?.tabular),
                const SizedBox(height: AppSpacing.xxs),
                ChangeIndicator(percent: percent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension LocalizedCurrencyName on BuildContext {
  String localizedName(RateQuote quote) {
    final thai = Localizations.localeOf(this).languageCode == 'th';
    final rate = quote.current;
    return thai && rate.nameTh.isNotEmpty ? rate.nameTh : rate.nameEn;
  }
}

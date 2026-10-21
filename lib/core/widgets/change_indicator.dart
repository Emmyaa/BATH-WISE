import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// "▲ +0.30%" pill in gain/loss color. Shows "—" when unknown.
///
/// Arrows double as a non-color cue for color-blind users.
class ChangeIndicator extends StatelessWidget {
  const new({
    required this.percent,
    super.key,
    this.change,
    this.changeDigits = 4,
    this.onGradient = false,
  });

  final Decimal? percent;

  /// Absolute change, shown before the percent when given.
  final Decimal? change;
  final int changeDigits;

  /// On the hero gradient: white pill instead of tinted.
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final color = onGradient ? Colors.white : context.bw.changeColor(percent);
    final arrow = switch (percent?.sign) {
      null || 0 => '•',
      > 0 => '▲',
      _ => '▼',
    };
    final text = switch (percent) {
      null => '—',
      final p => [
        if (change case final c?)
          context.decimals.format(c, digits: changeDigits, signed: true),
        if (change != null)
          '(${context.decimals.percent(p)})'
        else
          context.decimals.percent(p),
      ].join(' '),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onGradient ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$arrow $text',
        style: context.text.labelMedium?.tabular.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// Spoken form of a percent change for screen readers.
String describeChange(BuildContext context, Decimal? percent) {
  final l10n = context.l10n;
  if (percent == null || percent.sign == 0) return l10n.a11yUnchanged;
  final magnitude = context.decimals.percent(percent.abs()).substring(1);
  return percent.sign > 0 ? l10n.a11yUp(magnitude) : l10n.a11yDown(magnitude);
}

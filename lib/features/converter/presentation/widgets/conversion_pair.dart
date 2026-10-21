import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/animated_decimal_text.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// The typed amount (glass card) above the result (gradient card), with a
/// swap button where they meet.
///
/// The cards have the same layout, hence the same height, so the swap
/// button centered in the stack sits exactly on the seam.
class ConversionPair extends StatelessWidget {
  const new({
    required this.from,
    required this.to,
    required this.typed,
    required this.amount,
    required this.result,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
    super.key,
  });

  final String from;
  final String to;

  /// The keypad text, shown as typed ("12." stays "12.").
  final String typed;
  final Decimal amount;
  final Decimal? result;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amountText = context.decimals.formatTyped(typed);
    final resultText = result == null
        ? '—'
        : context.decimals.format(result!, digits: 2);
    final numberStyle = context.text.displaySmall;

    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          spacing: AppSpacing.xs,
          children: [
            GlassCard(
              blur: true,
              child: _CardBody(
                label: l10n.converterFrom,
                code: from,
                // New "from" currency slides in from the result's side.
                slideFrom: 1,
                onPick: onPickFrom,
                value: Text(
                  amountText,
                  maxLines: 1,
                  style: numberStyle?.tabular,
                  semanticsLabel: '$amountText $from',
                ),
              ),
            ),
            GlassCard(
              gradient: context.bw.heroGradient,
              child: _CardBody(
                label: l10n.converterTo,
                code: to,
                slideFrom: -1,
                onGradient: true,
                onPick: onPickTo,
                value: Semantics(
                  container: true,
                  liveRegion: true,
                  label: l10n.a11yConversion(
                    context.decimals.format(amount, digits: 2),
                    from,
                    resultText,
                    to,
                  ),
                  excludeSemantics: true,
                  child: result == null
                      ? Text(
                          resultText,
                          style: numberStyle?.copyWith(color: Colors.white),
                        )
                      : AnimatedDecimalText(
                          value: result!,
                          digits: 2,
                          // Short: it follows every keypress.
                          duration: AppDurations.medium,
                          style: numberStyle?.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
        _SwapButton(onSwap: onSwap),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  const new({
    required this.label,
    required this.code,
    required this.value,
    required this.onPick,
    required this.slideFrom,
    this.onGradient = false,
  });

  final String label;
  final String code;
  final Widget value;
  final VoidCallback onPick;

  /// Vertical direction the currency enters from after a swap (1 = below).
  final double slideFrom;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final color = onGradient ? Colors.white : context.colors.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: onGradient
                ? Colors.white.withValues(alpha: 0.85)
                : context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _SwapSwitcher(
              slideFrom: slideFrom,
              child: _CurrencyButton(
                key: ValueKey(code),
                label: label,
                code: code,
                color: color,
                onTap: onPick,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                // Long amounts shrink instead of overflowing.
                child: FittedBox(fit: BoxFit.scaleDown, child: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  const new({
    required this.label,
    required this.code,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final String code;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: context.l10n.converterChangeCurrency(
        label,
        code,
        context.currencyName(code),
      ),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CurrencyFlag(code: code, size: 32),
              const SizedBox(width: AppSpacing.xs),
              Text(
                code,
                style: context.text.titleLarge?.copyWith(color: color),
              ),
              Icon(Icons.expand_more_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides the new currency in vertically when the pair is swapped.
class _SwapSwitcher extends StatelessWidget {
  const new({required this.slideFrom, required this.child});

  final double slideFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.medium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        final offset = Tween(
          begin: Offset(0, incoming ? slideFrom : -slideFrom),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}

class _SwapButton extends StatefulWidget {
  const new({required this.onSwap});

  final VoidCallback onSwap;

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> {
  var _turns = 0.0;

  void _swap() {
    setState(() => _turns += 0.5);
    widget.onSwap();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.converterSwap,
      child: Semantics(
        container: true,
        button: true,
        onTap: _swap,
        label: context.l10n.converterSwap,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: context.bw.brandGradient,
            border: Border.all(color: context.colors.surface, width: 3),
            boxShadow: context.bw.cardShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _swap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: AnimatedRotation(
                  turns: _turns,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppDurations.medium,
                  curve: Curves.easeOutBack,
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

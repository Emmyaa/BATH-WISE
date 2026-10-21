import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// Counts from the previous value to [value] when it changes (and from
/// zero on first build when [countUp] is set).
///
/// Intermediate frames use doubles (display only); the final frame shows
/// the exact Decimal. Respects the system "reduce motion" setting.
class AnimatedDecimalText extends StatelessWidget {
  const new({
    required this.value,
    super.key,
    this.digits = 4,
    this.style,
    this.countUp = false,
    this.duration = AppDurations.countUp,
  });

  final Decimal value;
  final int digits;
  final TextStyle? style;
  final bool countUp;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.toDouble();
    final textStyle = (style ?? DefaultTextStyle.of(context).style).tabular;
    Text render(Decimal shown) =>
        Text(context.decimals.format(shown, digits: digits), style: textStyle);

    if (MediaQuery.disableAnimationsOf(context)) return render(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: countUp ? 0 : target, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => render(
        current == target
            ? value
            : Decimal.parse(current.toStringAsFixed(digits)),
      ),
    );
  }
}

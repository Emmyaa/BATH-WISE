import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:flutter/material.dart';

/// Round flag badge for a currency, falling back to its code.
class CurrencyFlag extends StatelessWidget {
  const new({required this.code, super.key, this.size = 40, this.heroTag});

  final String code;
  final double size;

  /// Wraps the flag in a [Hero] when set (list → detail transition).
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final flag = Currencies.byCode(code)?.flag ?? '';
    Widget badge = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colors.surfaceContainerHigh,
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: flag.isEmpty
            ? Text(
                code.substring(0, code.length.clamp(0, 2)),
                style: context.text.labelMedium,
              )
            : Text(
                flag,
                // Emoji ignore font weight; size relative to the badge.
                style: TextStyle(fontSize: size * 0.55, height: 1),
                textScaler: TextScaler.noScaling,
              ),
      ),
    );
    if (heroTag case final tag?) badge = Hero(tag: tag, child: badge);
    return badge;
  }
}

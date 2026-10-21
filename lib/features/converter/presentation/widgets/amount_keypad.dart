import 'dart:async';

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Calculator-style keypad: 1–9, decimal point, 0 and delete (long-press
/// clears). Used instead of the system keyboard so the amount and results
/// stay visible while typing.
class AmountKeypad extends StatelessWidget {
  const new({
    required this.onDigit,
    required this.onDecimalPoint,
    required this.onBackspace,
    required this.onClear,
    super.key,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDecimalPoint;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  static const _keyHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final decimalSeparator = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).symbols.DECIMAL_SEP;

    Widget digit(int d) => _Key(label: '$d', onTap: () => onDigit(d));
    final rows = [
      [digit(1), digit(2), digit(3)],
      [digit(4), digit(5), digit(6)],
      [digit(7), digit(8), digit(9)],
      [
        _Key(
          label: decimalSeparator,
          semanticsLabel: l10n.keypadDecimalPoint,
          onTap: onDecimalPoint,
        ),
        digit(0),
        _Key(
          icon: Icons.backspace_outlined,
          semanticsLabel: l10n.keypadDelete,
          longPressHint: l10n.keypadClear,
          onTap: onBackspace,
          onLongPress: onClear,
        ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xs,
      children: [
        for (final row in rows)
          Row(
            spacing: AppSpacing.xs,
            children: [
              for (final key in row)
                Expanded(
                  child: SizedBox(height: _keyHeight, child: key),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const new({
    required this.onTap,
    this.label,
    this.icon,
    this.semanticsLabel,
    this.longPressHint,
    this.onLongPress,
  });

  final String? label;
  final IconData? icon;
  final String? semanticsLabel;
  final String? longPressHint;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    void tap() {
      unawaited(HapticFeedback.selectionClick());
      onTap();
    }

    void longPress() {
      unawaited(HapticFeedback.mediumImpact());
      onLongPress!();
    }

    // The actions are repeated here because excludeSemantics drops the
    // InkWell's own.
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel ?? label,
      onTap: tap,
      onLongPress: onLongPress == null ? null : longPress,
      onLongPressHint: longPressHint,
      excludeSemantics: true,
      child: Material(
        color: context.bw.glassFill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: context.bw.glassBorder),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: tap,
          onLongPress: onLongPress == null ? null : longPress,
          child: Center(
            child: icon != null
                ? Icon(icon, color: context.colors.onSurface)
                // Scales with text size, but never past the key height.
                : FittedBox(
                    child: Text(
                      label!,
                      style: context.text.headlineSmall?.tabular,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:flutter/material.dart';

/// Frosted-glass surface used for every card in the app.
///
/// [blur] adds a real backdrop blur. It costs a render pass, so enable it
/// only on a few prominent cards, not on every list item.
/// When [gradient] is set the card is filled with it instead of glass
/// (e.g. the dashboard hero card).
class GlassCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppRadius.card,
    this.gradient,
    this.blur = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final bool blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.bw;

    Widget surface = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? tokens.glassFill : null,
            gradient: gradient,
            borderRadius: borderRadius,
            border: Border.all(
              color: gradient == null
                  ? tokens.glassBorder
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (blur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.glassBlurSigma,
          sigmaY: tokens.glassBlurSigma,
        ),
        child: surface,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: tokens.cardShadow,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: surface),
    );
  }
}

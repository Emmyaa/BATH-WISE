import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:flutter/material.dart';

/// Surface color with two soft brand-colored glows, giving glass cards
/// something to frost against.
class AppBackground extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glows = context.bw.backgroundGlows;
    return DecoratedBox(
      decoration: BoxDecoration(color: context.colors.surface),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1.1, -1),
                    radius: 1.2,
                    colors: [glows[0], glows[0].withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.2, 0.9),
                    radius: 1.1,
                    colors: [glows[1], glows[1].withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

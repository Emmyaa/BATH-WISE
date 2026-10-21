import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Placeholder block shown while content loads.
class SkeletonBox extends StatelessWidget {
  const new({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.onSurface.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Sweeps a highlight across [child] in a loop; static under reduce
/// motion. Announced once as "loading" instead of reading every block.
class Shimmer extends StatelessWidget {
  const new({required this.child, required this.label, super.key});

  final Widget child;

  /// Screen reader label, e.g. "Loading rates".
  final String label;

  @override
  Widget build(BuildContext context) {
    final content = ExcludeSemantics(child: child);
    return Semantics(
      label: label,
      liveRegion: true,
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : content
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  duration: 1200.ms,
                  color: context.colors.surface.withValues(alpha: 0.6),
                ),
    );
  }
}

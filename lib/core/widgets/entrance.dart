import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

extension EntranceAnimation on Widget {
  /// Staggered fade/slide-in for list items. Off under "reduce motion";
  /// the stagger is capped so long lists don't wait.
  Widget entrance(BuildContext context, int index) {
    if (MediaQuery.disableAnimationsOf(context)) return this;
    return animate(delay: (35 * index.clamp(0, 10)).ms)
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

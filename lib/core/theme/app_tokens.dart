import 'package:flutter/widgets.dart';

/// 4-pt spacing scale.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal padding for screen content.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: md);
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(xl));
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 600);

  /// Animated number counters (hero rate).
  static const countUp = Duration(milliseconds: 900);
}

/// Width breakpoints (Material 3 window size classes).
abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
}

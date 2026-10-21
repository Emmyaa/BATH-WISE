import 'package:flutter/material.dart';

abstract final class AppTypography {
  /// Bundled (not fetched at runtime) so the app works offline and golden
  /// tests are deterministic. Covers Thai + Latin and ships the ฿ glyph.
  static const fontFamily = 'IBMPlexSansThai';

  static TextTheme textTheme(TextTheme base) {
    // Thai stacks vowels and tone marks above and below the line, so body
    // text needs more line height than Material's Latin defaults.
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
          bodySmall: base.bodySmall?.copyWith(height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(fontFamily: fontFamily);
  }
}

extension TabularFigures on TextStyle {
  /// Fixed-width digits so changing numbers don't jiggle and columns align.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

import 'package:bath_wise/core/theme/app_colors.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// Design tokens that [ColorScheme] has no slot for: gradients, gain/loss
/// colors and glass card styling.
@immutable
class BathWiseTheme extends ThemeExtension<BathWiseTheme> {
  const new({
    required this.brandGradient,
    required this.heroGradient,
    required this.backgroundGlows,
    required this.gain,
    required this.loss,
    required this.neutral,
    required this.glassFill,
    required this.glassBorder,
    required this.glassBlurSigma,
    required this.cardShadow,
  });

  static const light = BathWiseTheme(
    brandGradient: LinearGradient(colors: [AppColors.indigo, AppColors.teal]),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.indigo, AppColors.violet, AppColors.teal],
      stops: [0, 0.45, 1],
    ),
    backgroundGlows: [Color(0x264F46E5), Color(0x1F0D9488)],
    gain: AppColors.gainLight,
    loss: AppColors.lossLight,
    neutral: AppColors.neutralLight,
    glassFill: Color(0xB3FFFFFF),
    glassBorder: Color(0x99FFFFFF),
    glassBlurSigma: 18,
    cardShadow: [
      BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  static const dark = BathWiseTheme(
    brandGradient: LinearGradient(
      colors: [AppColors.indigoBright, AppColors.tealBright],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3730A3), Color(0xFF5B21B6), Color(0xFF0F766E)],
      stops: [0, 0.5, 1],
    ),
    backgroundGlows: [Color(0x404F46E5), Color(0x2E14B8A6)],
    gain: AppColors.gainDark,
    loss: AppColors.lossDark,
    neutral: AppColors.neutralDark,
    glassFill: Color(0x991E2849),
    glassBorder: Color(0x1FFFFFFF),
    glassBlurSigma: 22,
    cardShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 32,
        offset: Offset(0, 12),
      ),
    ],
  );

  /// Accent gradient for buttons, chart fills and highlights.
  final LinearGradient brandGradient;

  /// Background of the dashboard hero card.
  final LinearGradient heroGradient;

  /// Soft blurred color blobs behind content, so glass cards have something
  /// to frost. Exactly two: top-start and bottom-end.
  final List<Color> backgroundGlows;

  final Color gain;
  final Color loss;
  final Color neutral;

  final Color glassFill;
  final Color glassBorder;
  final double glassBlurSigma;
  final List<BoxShadow> cardShadow;

  /// Color for a signed change: green up, red down, grey when flat/unknown.
  Color changeColor(Decimal? change) => switch (change?.sign) {
    null || 0 => neutral,
    > 0 => gain,
    _ => loss,
  };

  @override
  BathWiseTheme copyWith({
    LinearGradient? brandGradient,
    LinearGradient? heroGradient,
    List<Color>? backgroundGlows,
    Color? gain,
    Color? loss,
    Color? neutral,
    Color? glassFill,
    Color? glassBorder,
    double? glassBlurSigma,
    List<BoxShadow>? cardShadow,
  }) {
    return BathWiseTheme(
      brandGradient: brandGradient ?? this.brandGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      backgroundGlows: backgroundGlows ?? this.backgroundGlows,
      gain: gain ?? this.gain,
      loss: loss ?? this.loss,
      neutral: neutral ?? this.neutral,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  // Lerped so the light/dark switch animates smoothly via AnimatedTheme.
  @override
  BathWiseTheme lerp(BathWiseTheme? other, double t) {
    if (other == null) return this;
    return BathWiseTheme(
      brandGradient: LinearGradient.lerp(
        brandGradient,
        other.brandGradient,
        t,
      )!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      backgroundGlows: [
        for (var i = 0; i < backgroundGlows.length; i++)
          Color.lerp(backgroundGlows[i], other.backgroundGlows[i], t)!,
      ],
      gain: Color.lerp(gain, other.gain, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBlurSigma:
          glassBlurSigma + (other.glassBlurSigma - glassBlurSigma) * t,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}

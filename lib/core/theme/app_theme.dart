import 'package:bath_wise/core/theme/app_colors.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/bath_wise_theme.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.indigo).copyWith(
      primary: AppColors.indigo,
      secondary: AppColors.teal,
      surface: AppColors.mist50,
      onSurface: AppColors.ink900,
      onSurfaceVariant: AppColors.ink600,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: AppColors.mist100,
      surfaceContainerHigh: AppColors.mist100,
      surfaceContainerHighest: AppColors.mist200,
      outlineVariant: AppColors.mist200,
      error: AppColors.lossLight,
    );
    return _build(scheme, BathWiseTheme.light);
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.indigo,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.indigoBright,
          onPrimary: Colors.white,
          secondary: AppColors.tealBright,
          surface: AppColors.navy950,
          onSurface: const Color(0xFFE6E9F5),
          onSurfaceVariant: AppColors.neutralDark,
          surfaceContainerLowest: AppColors.navy950,
          surfaceContainerLow: AppColors.navy900,
          surfaceContainer: AppColors.navy800,
          surfaceContainerHigh: AppColors.navy700,
          surfaceContainerHighest: AppColors.navy600,
          outlineVariant: AppColors.navy700,
          error: AppColors.lossDark,
        );
    return _build(scheme, BathWiseTheme.dark);
  }

  static ThemeData _build(ColorScheme scheme, BathWiseTheme tokens) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = AppTypography.textTheme(base.textTheme);
    const roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: roundedMd,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary.withValues(alpha: 0.14),
          selectedForegroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: roundedMd,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: roundedMd,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}

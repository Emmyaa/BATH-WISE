import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/bath_wise_theme.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    for (final (name, theme, brightness) in [
      ('light', AppTheme.light(), Brightness.light),
      ('dark', AppTheme.dark(), Brightness.dark),
    ]) {
      test('$name has the right brightness, font and tokens', () {
        expect(theme.brightness, brightness);
        expect(theme.useMaterial3, isTrue);
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          AppTypography.fontFamily,
        );
        expect(theme.extension<BathWiseTheme>(), isNotNull);
      });
    }
  });

  group('BathWiseTheme', () {
    const light = BathWiseTheme.light;
    const dark = BathWiseTheme.dark;

    test('changeColor maps the sign of a change', () {
      expect(light.changeColor(Decimal.parse('1.5')), light.gain);
      expect(light.changeColor(Decimal.parse('-0.2')), light.loss);
      expect(light.changeColor(Decimal.zero), light.neutral);
      expect(light.changeColor(null), light.neutral);
    });

    test('lerp returns the endpoints at t = 0 and t = 1', () {
      expect(light.lerp(dark, 0).gain, light.gain);
      expect(light.lerp(dark, 1).gain, dark.gain);
      expect(light.lerp(dark, 1).glassBlurSigma, dark.glassBlurSigma);
    });
  });

  test('tabular adds the tnum feature', () {
    expect(
      const TextStyle().tabular.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}

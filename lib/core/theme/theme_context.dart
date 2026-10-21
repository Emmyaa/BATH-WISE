import 'package:bath_wise/core/theme/bath_wise_theme.dart';
import 'package:flutter/material.dart';

extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// App-specific tokens. Always registered by `AppTheme`.
  BathWiseTheme get bw => Theme.of(this).extension<BathWiseTheme>()!;
}

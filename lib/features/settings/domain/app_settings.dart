import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// The user's preferences, persisted across launches.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory({
    @Default(ThemeMode.system) ThemeMode themeMode,

    /// `en` or `th`; null follows the device language.
    String? languageCode,

    /// Rate type the Rates and Converter screens start with.
    @Default(RateType.mid) RateType defaultRateType,

    /// Ask for biometrics / device passcode when opening the app.
    @Default(false) bool appLock,
  }) = _AppSettings;
}

/// Loads and saves [AppSettings].
abstract interface class SettingsStore {
  /// Synchronous so the first frame already has the right theme and
  /// language.
  AppSettings read();

  Future<void> write(AppSettings settings);
}

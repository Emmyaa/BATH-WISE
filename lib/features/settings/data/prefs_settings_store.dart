import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SettingsStore] on shared_preferences. Values are stored as enum
/// names; an unknown or missing value falls back to the default, so a
/// renamed enum never breaks startup.
class PrefsSettingsStore implements SettingsStore {
  const new(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const _theme = 'settings.themeMode';
  static const _language = 'settings.languageCode';
  static const _rateType = 'settings.defaultRateType';
  static const _appLock = 'settings.appLock';
  static const Set<String> keys = {_theme, _language, _rateType, _appLock};

  /// Loads the stored values once; reads are then synchronous.
  static Future<PrefsSettingsStore> open() async => PrefsSettingsStore(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: keys),
    ),
  );

  @override
  AppSettings read() {
    const defaults = AppSettings();
    T byName<T extends Enum>(List<T> values, String key, T fallback) {
      final name = _prefs.getString(key);
      return values.where((v) => v.name == name).firstOrNull ?? fallback;
    }

    return AppSettings(
      themeMode: byName(ThemeMode.values, _theme, defaults.themeMode),
      languageCode: switch (_prefs.getString(_language)) {
        final code? when code == 'en' || code == 'th' => code,
        _ => null,
      },
      defaultRateType: byName(
        RateType.values,
        _rateType,
        defaults.defaultRateType,
      ),
      appLock: _prefs.getBool(_appLock) ?? defaults.appLock,
    );
  }

  @override
  Future<void> write(AppSettings settings) async {
    await _prefs.setString(_theme, settings.themeMode.name);
    if (settings.languageCode case final code?) {
      await _prefs.setString(_language, code);
    } else {
      await _prefs.remove(_language);
    }
    await _prefs.setString(_rateType, settings.defaultRateType.name);
    await _prefs.setBool(_appLock, settings.appLock);
  }
}

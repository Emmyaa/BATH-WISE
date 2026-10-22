import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/settings/data/local_device_auth.dart';
import 'package:bath_wise/features/settings/domain/app_settings.dart';
import 'package:bath_wise/features/settings/domain/device_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// Opened before `runApp` (see main.dart) and overridden there, so
/// settings are readable synchronously from the first frame.
@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) =>
    throw UnimplementedError('Override settingsStoreProvider in main()');

@Riverpod(keepAlive: true)
DeviceAuth deviceAuth(Ref ref) => LocalDeviceAuth();

/// The user's settings; every change is saved.
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).read();

  Future<void> _update(AppSettings settings) async {
    state = settings;
    await ref.read(settingsStoreProvider).write(settings);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  /// Null follows the device language.
  Future<void> setLanguage(String? languageCode) =>
      _update(state.copyWith(languageCode: languageCode));

  Future<void> setDefaultRateType(RateType type) =>
      _update(state.copyWith(defaultRateType: type));

  /// Turning the lock on or off needs the device's authentication first,
  /// so someone holding an unlocked phone can't quietly disable it.
  /// Returns whether the change was made.
  Future<bool> setAppLock({
    required bool enabled,
    required String reason,
  }) async {
    if (enabled == state.appLock) return true;
    final auth = ref.read(deviceAuthProvider);
    if (!await auth.isAvailable() || !await auth.authenticate(reason)) {
      return false;
    }
    await _update(state.copyWith(appLock: enabled));
    return true;
  }
}

/// Whether the device can lock the app at all (biometrics or passcode).
@riverpod
Future<bool> deviceAuthAvailable(Ref ref) =>
    ref.watch(deviceAuthProvider).isAvailable();

/// Whether the app is locked behind the device's authentication.
///
/// Locked at launch when the lock is on, and again after the app has
/// been in the background for [lockAfter] or longer. A short trip away
/// (copying a number, a notification) doesn't ask again.
@Riverpod(keepAlive: true)
class AppLockController extends _$AppLockController {
  static const lockAfter = Duration(minutes: 1);

  DateTime? _backgroundedAt;
  bool _authenticating = false;

  @override
  bool build() {
    // Turning the lock off unlocks; turning it on doesn't lock until the
    // next launch or background trip.
    ref.listen(settingsControllerProvider.select((s) => s.appLock), (
      _,
      enabled,
    ) {
      if (!enabled) state = false;
    });
    return ref.read(settingsControllerProvider).appLock;
  }

  bool get _enabled => ref.read(settingsControllerProvider).appLock;
  DateTime _now() => ref.read(clockProvider).now();

  void onBackgrounded() => _backgroundedAt ??= _now();

  void onResumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (_enabled && since != null && _now().difference(since) >= lockAfter) {
      state = true;
    }
  }

  /// Shows the system prompt; unlocks on success. Repeated calls while a
  /// prompt is up are ignored.
  Future<void> unlock(String reason) async {
    if (!state || _authenticating) return;
    _authenticating = true;
    try {
      if (await ref.read(deviceAuthProvider).authenticate(reason)) {
        state = false;
      }
    } finally {
      _authenticating = false;
    }
  }
}

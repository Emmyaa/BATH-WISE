import 'package:bath_wise/app.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/converter/presentation/converter_view_model.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/rates_list_view_model.dart';
import 'package:bath_wise/features/settings/data/prefs_settings_store.dart';
import 'package:bath_wise/features/settings/domain/app_settings.dart';
import 'package:bath_wise/features/settings/presentation/settings_controller.dart';
import 'package:bath_wise/features/settings/presentation/settings_screen.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('PrefsSettingsStore', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('defaults when nothing is saved', () async {
      expect((await PrefsSettingsStore.open()).read(), const AppSettings());
    });

    test('round-trips every field across a reopen', () async {
      const settings = AppSettings(
        themeMode: ThemeMode.dark,
        languageCode: 'th',
        defaultRateType: RateType.selling,
        appLock: true,
      );
      await (await PrefsSettingsStore.open()).write(settings);
      expect((await PrefsSettingsStore.open()).read(), settings);

      await (await PrefsSettingsStore.open()).write(
        settings.copyWith(languageCode: null),
      );
      expect((await PrefsSettingsStore.open()).read().languageCode, isNull);
    });
  });

  group('SettingsController', () {
    late InMemorySettingsStore store;
    late FakeDeviceAuth auth;
    late ProviderContainer container;

    setUp(() {
      store = InMemorySettingsStore();
      auth = FakeDeviceAuth();
      container = ProviderContainer.test(
        overrides: appOverrides(
          fx: FakeFxRepository(Ok(sampleSnapshot())),
          settings: store,
          deviceAuth: auth,
        ),
      );
    });

    SettingsController controller() =>
        container.read(settingsControllerProvider.notifier);

    test('saves every change', () async {
      await controller().setThemeMode(ThemeMode.light);
      await controller().setLanguage('en');
      expect(store.saved.themeMode, ThemeMode.light);
      expect(store.saved.languageCode, 'en');
    });

    test('the default rate type reaches Rates and Converter', () async {
      container
        ..listen(ratesListViewModelProvider, (_, _) {})
        ..listen(converterViewModelProvider, (_, _) {});
      await controller().setDefaultRateType(RateType.selling);
      expect(
        container.read(ratesListViewModelProvider).rateType,
        RateType.selling,
      );
      expect(
        container.read(converterViewModelProvider).rateType,
        RateType.selling,
      );
    });

    test('app lock changes only after authenticating', () async {
      auth.succeeds = false;
      expect(await controller().setAppLock(enabled: true, reason: 'r'), false);
      expect(store.saved.appLock, isFalse);

      auth.succeeds = true;
      expect(await controller().setAppLock(enabled: true, reason: 'r'), true);
      expect(store.saved.appLock, isTrue);
      expect(auth.reasons, hasLength(2));
    });

    test('app lock cannot be turned on without device security', () async {
      auth.available = false;
      expect(await controller().setAppLock(enabled: true, reason: 'r'), false);
      expect(auth.reasons, isEmpty);
    });
  });

  group('AppLockController', () {
    late FakeClock clock;
    late FakeDeviceAuth auth;
    late ProviderContainer container;

    setUp(() {
      auth = FakeDeviceAuth();
      container = ProviderContainer.test(
        overrides: appOverrides(
          fx: FakeFxRepository(Ok(sampleSnapshot())),
          settings: InMemorySettingsStore(const AppSettings(appLock: true)),
          deviceAuth: auth,
        ),
      )..listen(appLockControllerProvider, (_, _) {});
      clock = container.read(clockProvider) as FakeClock;
    });

    bool locked() => container.read(appLockControllerProvider);
    AppLockController lock() =>
        container.read(appLockControllerProvider.notifier);

    test('starts locked and unlocks after authenticating', () async {
      expect(locked(), isTrue);
      auth.succeeds = false;
      await lock().unlock('r');
      expect(locked(), isTrue);
      auth.succeeds = true;
      await lock().unlock('r');
      expect(locked(), isFalse);
    });

    test('locks again only after a minute in the background', () async {
      await lock().unlock('r');

      lock().onBackgrounded();
      clock.advance(const Duration(seconds: 30));
      lock().onResumed();
      expect(locked(), isFalse);

      lock().onBackgrounded();
      clock.advance(AppLockController.lockAfter);
      lock().onResumed();
      expect(locked(), isTrue);
    });

    test('turning the lock off unlocks', () async {
      await container
          .read(settingsControllerProvider.notifier)
          .setAppLock(enabled: false, reason: 'r');
      expect(locked(), isFalse);
    });
  });

  group('screens', () {
    Future<InMemorySettingsStore> pumpSettings(
      WidgetTester tester, {
      FakeDeviceAuth? auth,
    }) async {
      tester.view
        ..physicalSize = const Size(420, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = InMemorySettingsStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(
            fx: FakeFxRepository(Ok(sampleSnapshot())),
            settings: store,
            deviceAuth: auth,
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('settings screen saves choices', (tester) async {
      final store = await pumpSettings(tester);

      await tester.tap(find.text('Dark'));
      await tester.tap(find.text('ไทย'));
      await tester.tap(find.text('Sell'));
      await tester.pumpAndSettle();

      expect(store.saved.themeMode, ThemeMode.dark);
      expect(store.saved.languageCode, 'th');
      expect(store.saved.defaultRateType, RateType.selling);
      expect(find.text('Data sources'), findsOneWidget);
    });

    testWidgets('app lock switch explains a failed confirmation', (
      tester,
    ) async {
      final store = await pumpSettings(
        tester,
        auth: FakeDeviceAuth(succeeds: false),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(store.saved.appLock, isFalse);
      expect(find.textContaining("Couldn't confirm it's you"), findsOneWidget);
    });

    testWidgets('app lock is unavailable without device security', (
      tester,
    ) async {
      await pumpSettings(tester, auth: FakeDeviceAuth(available: false));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
    });

    testWidgets('a locked app hides its content until unlocked', (
      tester,
    ) async {
      final auth = FakeDeviceAuth(succeeds: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(
            fx: FakeFxRepository(Ok(sampleSnapshot())),
            settings: InMemorySettingsStore(
              const AppSettings(appLock: true, languageCode: 'en'),
            ),
            deviceAuth: auth,
          ),
          child: const BathWiseApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BathWise is locked'), findsOneWidget);
      expect(auth.reasons, ['Unlock BathWise'], reason: 'prompts at once');
      expect(find.bySemanticsLabel(RegExp('US dollar')), findsNothing);

      auth.succeeds = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('BathWise is locked'), findsNothing);
    });

    testWidgets('the app follows the language setting', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appOverrides(
            fx: FakeFxRepository(Ok(sampleSnapshot())),
            settings: InMemorySettingsStore(
              const AppSettings(languageCode: 'th'),
            ),
          ),
          child: const BathWiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('หน้าหลัก'), findsWidgets);
    });
  });
}

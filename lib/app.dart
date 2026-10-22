import 'dart:async';

import 'package:bath_wise/core/router/app_router.dart';
import 'package:bath_wise/core/router/app_routes.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/features/settings/presentation/app_lock_gate.dart';
import 'package:bath_wise/features/settings/presentation/settings_controller.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_providers.dart';
import 'package:bath_wise/features/watchlist/presentation/rate_alerts_view_model.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BathWiseApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BathWiseApp> createState() => _BathWiseAppState();
}

class _BathWiseAppState extends ConsumerState<BathWiseApp> {
  // Built once: ThemeData construction isn't free and never changes.
  static final ThemeData _light = AppTheme.light();
  static final ThemeData _dark = AppTheme.dark();

  @override
  void initState() {
    super.initState();
    unawaited(_openTappedAlerts());
  }

  /// A tapped alert notification opens its currency, whether the app was
  /// running or the tap launched it.
  Future<void> _openTappedAlerts() async {
    final router = ref.read(appRouterProvider);
    void open(String code) => unawaited(router.push(AppRoutes.currency(code)));
    final notifications = ref.read(alertNotificationsProvider);
    try {
      await notifications.initialize(onTap: open);
      if (await notifications.launchedFromCode() case final code?) open(code);
    } on Exception catch (e) {
      // Not fatal: alerts still show in the app.
      debugPrint('Notifications unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen rather than watch: keeps alert checks and scheduling alive
    // for the session without rebuilding the app on every run.
    ref.listen(alertMonitorProvider, (_, _) {});
    final (themeMode, languageCode) = ref.watch(
      settingsControllerProvider.select((s) => (s.themeMode, s.languageCode)),
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _light,
      darkTheme: _dark,
      themeMode: themeMode,
      themeAnimationDuration: AppDurations.slow,
      themeAnimationCurve: Curves.easeInOutCubic,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Null follows the device language.
      locale: languageCode == null ? null : Locale(languageCode),
      routerConfig: ref.watch(appRouterProvider),
      builder: (_, child) => AppLockGate(child: child ?? const SizedBox()),
    );
  }
}

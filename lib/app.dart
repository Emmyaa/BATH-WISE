import 'package:bath_wise/core/router/app_router.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_mode_controller.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BathWiseApp extends ConsumerWidget {
  const new({super.key});

  // Built once: ThemeData construction isn't free and never changes.
  static final ThemeData _light = AppTheme.light();
  static final ThemeData _dark = AppTheme.dark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _light,
      darkTheme: _dark,
      themeMode: ref.watch(themeModeControllerProvider),
      themeAnimationDuration: AppDurations.slow,
      themeAnimationCurve: Curves.easeInOutCubic,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

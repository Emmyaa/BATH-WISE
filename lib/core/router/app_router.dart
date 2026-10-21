import 'package:bath_wise/core/router/app_routes.dart';
import 'package:bath_wise/core/router/app_shell.dart';
import 'package:bath_wise/features/converter/presentation/converter_screen.dart';
import 'package:bath_wise/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bath_wise/features/loan_rates/presentation/loan_rates_screen.dart';
import 'package:bath_wise/features/rates/presentation/currency_detail_screen.dart';
import 'package:bath_wise/features/rates/presentation/rates_screen.dart';
import 'package:bath_wise/features/settings/presentation/settings_screen.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Detail routes (Currency Detail, Loan Rates) push onto this navigator so
/// they cover the bottom bar.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: kDebugMode,
    routes: [
      // Each branch keeps its own navigation stack and scroll position.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(AppRoutes.dashboard, const DashboardScreen()),
          _branch(AppRoutes.rates, const RatesScreen()),
          _branch(AppRoutes.converter, const ConverterScreen()),
          _branch(AppRoutes.watchlist, const WatchlistScreen()),
          _branch(AppRoutes.settings, const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.currencyPattern,
        // `extra` carries the Hero tag of the tapped flag, so Dashboard and
        // Rates (alive at once in the shell) never share a tag.
        builder: (_, state) => CurrencyDetailScreen(
          code: state.pathParameters['code']!.toUpperCase(),
          heroTag: state.extra,
        ),
      ),
      GoRoute(
        path: AppRoutes.loanRates,
        builder: (_, _) => const LoanRatesScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

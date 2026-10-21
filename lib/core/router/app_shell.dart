import 'dart:ui';

import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/app_background.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root scaffold for the 5 tabs: a bottom [NavigationBar] on phones and a
/// [NavigationRail] from the medium breakpoint (tablets, landscape).
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onSelect(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab pops it back to its root.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(AppLocalizations.of(context));
    final useRail = MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    if (useRail) {
      return Scaffold(
        body: AppBackground(
          child: Row(
            children: [
              SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onSelect,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: 0,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      );
    }

    final blur = context.bw.glassBlurSigma;
    return Scaffold(
      extendBody: true,
      body: AppBackground(child: navigationShell),
      // Frosted bar: content scrolls underneath (extendBody) and is
      // blurred, not just tinted.
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelect,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Order must match the branches in `appRouter`.
  static List<_Destination> _destinations(AppLocalizations l10n) => [
    _Destination(
      l10n.tabDashboard,
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
    ),
    _Destination(
      l10n.tabRates,
      Icons.format_list_bulleted_rounded,
      Icons.view_list_rounded,
    ),
    _Destination(
      l10n.tabConverter,
      Icons.currency_exchange_outlined,
      Icons.currency_exchange_rounded,
    ),
    _Destination(
      l10n.tabWatchlist,
      Icons.star_outline_rounded,
      Icons.star_rounded,
    ),
    _Destination(
      l10n.tabSettings,
      Icons.settings_outlined,
      Icons.settings_rounded,
    ),
  ];
}

class _Destination {
  const new(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

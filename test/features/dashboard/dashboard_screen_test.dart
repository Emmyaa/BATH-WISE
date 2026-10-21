import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_helpers.dart';

void main() {
  final chula = Holiday(
    date: DateTime.utc(2026, 10, 23),
    nameEn: 'Chulalongkorn Day',
    nameTh: 'วันปิยมหาราช',
  );

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required DateTime now,
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = const Size(420, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(
          fx: FakeFxRepository(Ok(sampleSnapshot())),
          now: now,
          holidays: [chula],
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hero shows USD/THB, change and status', (tester) async {
    await pumpDashboard(tester, now: bkk(2026, 10, 20, 9));

    expect(find.text('USD / THB'), findsOneWidget);
    // Hero counter settles on the exact value (also in the watchlist).
    expect(find.text('33.4859'), findsWidgets);
    expect(find.text('BOT official'), findsOneWidget);
    expect(find.text('Official BOT rate as of Oct 19, 2026'), findsOneWidget);
  });

  testWidgets('bank holiday explains the missing data', (tester) async {
    await pumpDashboard(tester, now: bkk(2026, 10, 23, 10));

    expect(
      find.text(
        'Bank holiday (Chulalongkorn Day) — showing rates as of Oct 19, 2026',
      ),
      findsOneWidget,
    );
    expect(find.text('Next update Mon at 18:00'), findsOneWidget);
  });

  testWidgets('Thai locale: Thai holiday name and Buddhist-era date', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      now: bkk(2026, 10, 23, 10),
      locale: const Locale('th'),
    );

    expect(
      find.text('วันหยุดธนาคาร (วันปิยมหาราช) — แสดงอัตรา ณ 19 ต.ค. 2569'),
      findsOneWidget,
    );
  });

  testWidgets('watchlist, top movers and loan card sections', (tester) async {
    await pumpDashboard(tester, now: bkk(2026, 10, 20, 9));

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Top movers'), findsOneWidget);
    expect(find.text('Average loan rates'), findsOneWidget);
    // The fake loan repository answers 403, as the real token does today.
    expect(
      find.textContaining('Loan rates are unavailable right now.'),
      findsOneWidget,
    );
  });
}

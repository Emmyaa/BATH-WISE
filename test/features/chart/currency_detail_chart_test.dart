import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/features/chart/presentation/widgets/chart_stats_card.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/currency_detail_screen.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeFxRepository repo;

  setUp(() {
    repo = FakeFxRepository(Ok(sampleSnapshot()))
      ..history = (r) => Ok(switch (r.code) {
        'USD' => fakeSeries('USD', [
          33.1,
          33.5,
          32.9,
          33.3,
        ], periodicity: r.periodicity),
        final code => fakeSeries(code, [
          38,
          38.38,
          37.62,
        ], periodicity: r.periodicity),
      });
  });

  Future<void> pumpDetail(WidgetTester tester, {ThemeData? theme}) async {
    tester.view
      ..physicalSize = const Size(420, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(fx: repo),
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CurrencyDetailScreen(code: 'USD'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inStats(String text) => find.descendant(
    of: find.byType(ChartStatsCard),
    matching: find.text(text),
  );

  testWidgets('shows the 1M chart, its source and stats', (tester) async {
    await pumpDetail(tester);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('BOT official · daily mid rates'), findsOneWidget);
    expect(inStats('33.5000'), findsOneWidget);
    expect(inStats('32.9000'), findsOneWidget);
    expect(inStats('33.2000'), findsOneWidget);
    expect(inStats('▲ +0.2000 (+0.60%)'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^US Dollar, 1 month chart\. From 33\.1000 to 33\.3000'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('1Y switches to monthly averages', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.text('1Y'));
    await tester.pumpAndSettle();

    expect(repo.historyRequests.last.periodicity, Periodicity.monthly);
    expect(
      find.text('BOT official · monthly average mid rates'),
      findsOneWidget,
    );
    expect(find.text('σ of monthly changes'), findsOneWidget);
  });

  testWidgets('compare overlays a second currency as % change', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('Compare with'), findsOneWidget);
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();

    expect(find.text('vs EUR'), findsOneWidget);
    expect(find.textContaining('% change since'), findsOneWidget);
    // Legend: each currency's change over the range.
    expect(find.text('▲ +0.60%'), findsOneWidget);
    expect(find.text('▼ −1.00%'), findsOneWidget);
    expect({for (final r in repo.historyRequests) r.code}, {'USD', 'EUR'});

    await tester.tap(find.byTooltip('Stop comparing with EUR'));
    await tester.pumpAndSettle();
    expect(find.text('vs EUR'), findsNothing);
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('a failed load shows an inline error that retries', (
    tester,
  ) async {
    final ok = repo.history;
    repo.history = (_) => const Err(NetworkFailure());
    await pumpDetail(tester);

    expect(find.textContaining("Couldn't load the chart"), findsOneWidget);
    expect(find.byType(ChartStatsCard), findsNothing);
    // Today's rates still show.
    expect(find.text("Today's rates"), findsOneWidget);

    repo.history = ok;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('saved history from a failed refresh is labelled', (
    tester,
  ) async {
    repo.history = (r) =>
        Ok(fakeSeries('USD', [1, 2], refreshFailure: const NetworkFailure()));
    await pumpDetail(tester);

    expect(
      find.textContaining("Couldn't refresh. Showing saved history."),
      findsOneWidget,
    );
  });

  testWidgets('a single point is not enough for a chart', (tester) async {
    repo.history = (r) => Ok(fakeSeries('USD', [33]));
    await pumpDetail(tester);

    expect(find.text('Not enough data for this range yet.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders in dark theme too', (tester) async {
    await pumpDetail(tester, theme: AppTheme.dark());
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

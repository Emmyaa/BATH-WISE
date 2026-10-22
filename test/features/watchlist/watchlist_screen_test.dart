import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/theme/app_theme.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/features/watchlist/presentation/rate_alerts_view_model.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_screen.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_view_model.dart';
import 'package:bath_wise/features/watchlist/presentation/widgets/watchlist_tile.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeWatchlistRepository watchlist;
  late FakeAlertNotifier notifier;

  setUp(() {
    watchlist = FakeWatchlistRepository();
    notifier = FakeAlertNotifier();
  });

  Future<void> pumpWatchlist(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(420, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(
          fx: FakeFxRepository(Ok(sampleSnapshot())),
          watchlist: watchlist,
          notifier: notifier,
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WatchlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> shownCodes(WidgetTester tester) => [
    for (final tile in tester.widgetList<WatchlistTile>(
      find.byType(WatchlistTile),
    ))
      tile.code,
  ];

  testWidgets('lists the watchlist in order with rates and alert counts', (
    tester,
  ) async {
    watchlist.alerts = [testAlert(target: '40'), testAlert(id: 2)];
    await pumpWatchlist(tester);

    expect(shownCodes(tester), ['USD', 'EUR', 'JPY', 'GBP', 'CNY', 'SGD']);
    expect(find.text('33.4859'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'USD alerts badge');
    expect(find.bySemanticsLabel(RegExp('2 active alerts')), findsOneWidget);
  });

  testWidgets('swipe removes; undo puts it back in place', (tester) async {
    await pumpWatchlist(tester);

    await tester.drag(
      find.byKey(const ValueKey('dismiss-EUR')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(shownCodes(tester), isNot(contains('EUR')));
    expect(find.text('EUR removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(shownCodes(tester), ['USD', 'EUR', 'JPY', 'GBP', 'CNY', 'SGD']);
  });

  testWidgets('adds a currency that is not listed yet', (tester) async {
    await pumpWatchlist(tester);

    await tester.tap(find.byTooltip('Add currency'));
    await tester.pumpAndSettle();
    expect(find.text('Add to watchlist'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('USD')),
      findsNothing,
      reason: 'already listed',
    );

    await tester.tap(find.text('CHF'));
    await tester.pumpAndSettle();
    expect(shownCodes(tester).last, 'CHF');
  });

  testWidgets('empty watchlist offers to add', (tester) async {
    watchlist.codes = [];
    await pumpWatchlist(tester);

    expect(find.textContaining('Your watchlist is empty'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add currency'), findsOneWidget);
  });

  testWidgets('creates an alert from the sheet', (tester) async {
    await pumpWatchlist(tester);

    await tester.tap(find.byTooltip('Rate alerts for USD'));
    await tester.pumpAndSettle();
    expect(find.text('Now 33.4859'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create alert'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '33.4859');
    await tester.pump();
    expect(find.text('Enter a rate above or below the current one.'), findsOne);

    await tester.enterText(find.byType(TextField), '32.5');
    await tester.pump();
    expect(find.text('Notify me when Mid falls to 32.5000'), findsOneWidget);

    await tester.tap(find.text('Create alert'));
    await tester.pumpAndSettle();
    final saved = watchlist.alerts.single;
    expect(saved.direction, AlertDirection.below);
    expect(saved.target, Decimal.parse('32.5'));
    expect(saved.rateType, RateType.mid);
    expect(notifier.permissionRequests, 1);
    expect(find.text('Mid ≤ 32.5000'), findsOneWidget);
  });

  testWidgets('explains when notifications are denied', (tester) async {
    notifier.permission = false;
    await pumpWatchlist(tester);

    await tester.tap(find.byTooltip('Rate alerts for USD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '40');
    await tester.pump();
    await tester.tap(find.text('Create alert'));
    await tester.pumpAndSettle();

    expect(watchlist.alerts, hasLength(1), reason: 'saved anyway');
    expect(find.textContaining('Notifications are turned off'), findsOne);
  });

  group('view models', () {
    late ProviderContainer container;
    late FakeAlertScheduler scheduler;

    setUp(() {
      scheduler = FakeAlertScheduler();
      container =
          ProviderContainer.test(
              overrides: appOverrides(
                fx: FakeFxRepository(Ok(sampleSnapshot())),
                watchlist: watchlist,
                notifier: notifier,
                scheduler: scheduler,
              ),
            )
            // Like the app does: unlistened providers are paused.
            ..listen(watchlistViewModelProvider, (_, _) {})
            ..listen(alertMonitorProvider, (_, _) {});
    });

    test('move reorders immediately and persists', () async {
      await container.read(watchlistViewModelProvider.future);
      final pending = container
          .read(watchlistViewModelProvider.notifier)
          .move(0, 2);
      expect(container.read(watchlistViewModelProvider).value!.take(3), [
        'EUR',
        'JPY',
        'USD',
      ]);
      await pending;
      expect(watchlist.codes.take(3), ['EUR', 'JPY', 'USD']);
    });

    test('alertMonitor schedules only while alerts are active', () async {
      await container.read(alertMonitorProvider.future);
      expect(scheduler.syncs, [false]);

      await container.read(rateAlertsViewModelProvider.notifier).add((
        currencyCode: 'USD',
        direction: AlertDirection.above,
        target: Decimal.fromInt(40),
        rateType: RateType.mid,
      ));
      await pumpEventQueue();
      await container.read(alertMonitorProvider.future);
      expect(scheduler.syncs.last, isTrue);
    });

    test('alertMonitor checks alerts against loaded rates', () async {
      await container.read(latestRatesViewModelProvider.future);
      await watchlist.addAlert((
        currencyCode: 'USD',
        direction: AlertDirection.above,
        target: Decimal.fromInt(33),
        rateType: RateType.mid,
      ));
      await pumpEventQueue();
      await container.read(alertMonitorProvider.future);

      expect(notifier.shown.single.alert.currencyCode, 'USD');
      expect(watchlist.alerts.single.isTriggered, isTrue);
    });
  });
}

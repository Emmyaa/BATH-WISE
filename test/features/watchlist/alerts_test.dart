import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/money/formatters.dart';
import 'package:bath_wise/core/time/date_formatters.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/watchlist/data/local_alert_notifier.dart';
import 'package:bath_wise/features/watchlist/domain/alert_check.dart';
import 'package:bath_wise/features/watchlist/domain/alert_evaluator.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_helpers.dart';

void main() {
  final snapshot = sampleSnapshot();
  final usd = snapshot.quoteFor('USD')!.current;
  final usdMid = usd.mid!;
  final usdSelling = usd.selling!;
  String plus(Decimal value, String delta) =>
      (value + Decimal.parse(delta)).toString();

  group('RateAlert', () {
    test('above fires at or over the target; below at or under', () {
      final above = testAlert(target: '33');
      final below = testAlert(direction: AlertDirection.below, target: '33');
      expect(above.isMetBy(Decimal.parse('33')), isTrue);
      expect(above.isMetBy(Decimal.parse('32.99')), isFalse);
      expect(below.isMetBy(Decimal.parse('33')), isTrue);
      expect(below.isMetBy(Decimal.parse('33.01')), isFalse);
    });

    test('alertDirectionFor makes the target a future event', () {
      final now = Decimal.parse('32.5');
      expect(
        alertDirectionFor(current: now, target: Decimal.parse('33')),
        AlertDirection.above,
      );
      expect(
        alertDirectionFor(current: now, target: Decimal.parse('32')),
        AlertDirection.below,
      );
      expect(alertDirectionFor(current: now, target: now), isNull);
    });
  });

  group('evaluateAlerts', () {
    test('fires met alerts with the rate and period that met them', () {
      final met = testAlert(target: plus(usdMid, '-0.5'));
      final notMet = testAlert(id: 2, target: plus(usdMid, '0.5'));
      final triggers = evaluateAlerts([met, notMet], snapshot);
      expect(triggers, hasLength(1));
      expect(triggers.single.alert, met);
      expect(triggers.single.rate, usdMid);
      expect(triggers.single.period, DateTime.utc(2026, 10, 19));
    });

    test('reads the alert rate type', () {
      final alert = testAlert(
        rateType: RateType.selling,
        target: usdSelling.toString(),
      );
      expect(evaluateAlerts([alert], snapshot).single.rate, usdSelling);
    });

    test('skips disabled, triggered and unknown-currency alerts', () {
      final alerts = [
        testAlert(target: '1', enabled: false),
        testAlert(id: 2, target: '1', triggeredAt: DateTime.utc(2026)),
        testAlert(id: 3, code: 'XXX', target: '1'),
      ];
      expect(evaluateAlerts(alerts, snapshot), isEmpty);
    });

    test('ECB reference rates never fire an alert', () {
      final ecb = sampleSnapshot(source: RateSource.ecb);
      expect(evaluateAlerts([testAlert(target: '1')], ecb), isEmpty);
    });
  });

  group('AlertCheck', () {
    late FakeWatchlistRepository watchlist;
    late FakeFxRepository fx;
    late FakeAlertNotifier notifier;
    late AlertCheck check;

    setUp(() {
      watchlist = FakeWatchlistRepository();
      fx = FakeFxRepository(Ok(snapshot));
      notifier = FakeAlertNotifier();
      check = AlertCheck(
        watchlist,
        fx,
        notifier,
        FakeClock(bkk(2026, 10, 20, 19)),
      );
    });

    test('without active alerts it never asks for rates', () async {
      watchlist.alerts = [testAlert(target: '1', enabled: false)];
      expect(await check.run(), isEmpty);
      expect(fx.latestCalls, 0);
    });

    test('notifies met alerts once and records them', () async {
      watchlist.alerts = [
        testAlert(target: plus(usdMid, '-1')),
        testAlert(id: 2, target: plus(usdMid, '1')),
      ];
      expect(await check.run(), hasLength(1));
      expect(fx.lastForceRefresh, isFalse, reason: 'respects the cache rules');
      expect(notifier.shown.single.alert.id, 1);
      expect(watchlist.alerts.first.isTriggered, isTrue);

      expect(await check.run(), isEmpty);
      expect(notifier.shown, hasLength(1));
    });

    test('uses a given snapshot without fetching', () async {
      watchlist.alerts = [testAlert(target: plus(usdMid, '-1'))];
      await check.run(snapshot);
      expect(fx.latestCalls, 0);
      expect(notifier.shown, hasLength(1));
    });

    test('a failed fetch notifies nothing', () async {
      watchlist.alerts = [testAlert(target: '1')];
      fx.latest = const Err(NetworkFailure());
      expect(await check.run(), isEmpty);
      expect(notifier.shown, isEmpty);
    });
  });

  group('AlertNotificationText', () {
    setUpAll(initializeDateFormatting);

    final trigger = (
      alert: testAlert(rateType: RateType.selling, target: '33'),
      rate: Decimal.parse('33.125'),
      period: DateTime.utc(2026, 10, 20),
    );

    test('English', () {
      final text = AlertNotificationText(
        lookupAppLocalizations(const Locale('en')),
        DecimalFormatter('en'),
        DateFormatters('en'),
      );
      expect(text.title(trigger), 'USD rose to 33.1250 baht');
      expect(text.body(trigger), contains('Sell alert at 33.0000'));
    });

    test('Thai, falling', () {
      final text = AlertNotificationText(
        lookupAppLocalizations(const Locale('th')),
        DecimalFormatter('th'),
        DateFormatters('th'),
      );
      final falling = (
        alert: trigger.alert.copyWith(direction: AlertDirection.below),
        rate: trigger.rate,
        period: trigger.period,
      );
      expect(text.title(falling), startsWith('USD ลงถึง'));
    });
  });
}

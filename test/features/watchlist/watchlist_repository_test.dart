import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_repository_impl.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late AppDatabase db;
  late WatchlistRepositoryImpl repo;

  setUp(() {
    db = inMemoryDatabase();
    repo = WatchlistRepositoryImpl(db, FakeClock(bkk(2026, 10, 20, 9)));
  });
  tearDown(() => db.close());

  Future<List<String>> codes() => repo.watchCodes().first;

  NewRateAlert alert(String code, [String target = '35']) => (
    currencyCode: code,
    direction: AlertDirection.above,
    target: Decimal.parse(target),
    rateType: RateType.selling,
  );

  group('watchlist', () {
    test('a new database starts with the starter list', () async {
      expect(await codes(), AppDatabase.starterWatchlist);
    });

    test('add appends once', () async {
      await repo.add('CHF');
      await repo.add('CHF');
      expect(await codes(), [...AppDatabase.starterWatchlist, 'CHF']);
    });

    test('remove takes the alerts along; restore puts both back', () async {
      await repo.addAlert(alert('JPY'));
      await repo.addAlert(alert('USD'));
      final removed = (await repo.remove('JPY'))!;

      expect(removed.index, 2);
      expect(removed.alerts.single.currencyCode, 'JPY');
      expect(await codes(), ['USD', 'EUR', 'GBP', 'CNY', 'SGD']);
      expect((await repo.watchAlerts().first).map((a) => a.currencyCode), [
        'USD',
      ]);

      await repo.restore(removed);
      expect(await codes(), AppDatabase.starterWatchlist);
      final alerts = await repo.watchAlerts().first;
      expect(alerts.map((a) => a.currencyCode), ['JPY', 'USD']);
      expect(alerts.first, removed.alerts.single, reason: 'same id and data');
    });

    test('remove of an unlisted code is a no-op', () async {
      expect(await repo.remove('CHF'), isNull);
      expect(await codes(), AppDatabase.starterWatchlist);
    });

    test('reorder persists the new order', () async {
      await repo.reorder(['SGD', 'USD', 'EUR', 'JPY', 'GBP', 'CNY']);
      expect(await codes(), ['SGD', 'USD', 'EUR', 'JPY', 'GBP', 'CNY']);
    });

    test('watchCodes emits after each change', () async {
      final emitted = repo.watchCodes().take(2).toList();
      await pumpEventQueue();
      await repo.add('CHF');
      expect((await emitted).last.last, 'CHF');
    });
  });

  group('alerts', () {
    test('adding an alert adds its currency to the watchlist', () async {
      await repo.addAlert(alert('CHF'));
      expect(await codes(), contains('CHF'));
      final saved = (await repo.watchAlerts().first).single;
      expect(saved.target, Decimal.parse('35'));
      expect(saved.rateType, RateType.selling);
      expect(saved.createdAt, bkk(2026, 10, 20, 9));
      expect(saved.enabled, isTrue);
    });

    test('markTriggered records once, then skips', () async {
      await repo.addAlert(alert('USD'));
      final saved = (await repo.activeAlerts()).single;
      final trigger = (
        alert: saved,
        rate: Decimal.parse('35.5'),
        period: DateTime.utc(2026, 10, 20),
      );
      final at = bkk(2026, 10, 20, 19);

      expect(await repo.markTriggered([trigger], at), [trigger]);
      expect(await repo.markTriggered([trigger], at), isEmpty);
      expect(await repo.activeAlerts(), isEmpty);

      final triggered = (await repo.watchAlerts().first).single;
      expect(triggered.enabled, isFalse);
      expect(triggered.triggeredRate, Decimal.parse('35.5'));
      expect(triggered.triggeredPeriod, DateTime.utc(2026, 10, 20));
    });

    test('re-enabling clears the trigger; disabling keeps it', () async {
      await repo.addAlert(alert('USD'));
      final saved = (await repo.activeAlerts()).single;
      await repo.markTriggered([
        (alert: saved, rate: Decimal.parse('36'), period: DateTime.utc(2026)),
      ], bkk(2026, 10, 20, 19));

      await repo.setAlertEnabled(saved.id, enabled: true);
      final rearmed = (await repo.watchAlerts().first).single;
      expect(rearmed.isTriggered, isFalse);
      expect(rearmed.triggeredRate, isNull);
      expect(await repo.activeAlerts(), hasLength(1));

      await repo.setAlertEnabled(saved.id, enabled: false);
      expect(await repo.activeAlerts(), isEmpty);
    });

    test('deleteAlert removes it', () async {
      await repo.addAlert(alert('USD'));
      final saved = (await repo.activeAlerts()).single;
      await repo.deleteAlert(saved.id);
      expect(await repo.watchAlerts().first, isEmpty);
    });
  });
}

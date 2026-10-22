import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/features/watchlist/domain/watchlist_repository.dart';
import 'package:drift/drift.dart';

class WatchlistRepositoryImpl implements WatchlistRepository {
  const new(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  $WatchlistItemsTable get _items => _db.watchlistItems;
  $RateAlertsTable get _alerts => _db.rateAlerts;

  SimpleSelectStatement<$WatchlistItemsTable, WatchlistRow> _ordered() =>
      _db.select(_items)..orderBy([(t) => OrderingTerm.asc(t.position)]);

  // --- Watchlist -------------------------------------------------------------

  @override
  Stream<List<String>> watchCodes() =>
      _ordered().watch().map((rows) => [for (final r in rows) r.currencyCode]);

  @override
  Future<void> add(String code) => _db.transaction(() async {
    final last = _items.position.max();
    final row = await (_db.selectOnly(_items)..addColumns([last])).getSingle();
    await _db
        .into(_items)
        .insert(
          WatchlistItemsCompanion.insert(
            currencyCode: code,
            position: (row.read(last) ?? -1) + 1,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  @override
  Future<RemovedWatchItem?> remove(String code) => _db.transaction(() async {
    final codes = [for (final r in await _ordered().get()) r.currencyCode];
    final index = codes.indexOf(code);
    if (index < 0) return null;
    final alerts = await (_db.select(
      _alerts,
    )..where((t) => t.currencyCode.equals(code))).get();
    await (_db.delete(_alerts)..where((t) => t.currencyCode.equals(code))).go();
    await _writeOrder(codes..removeAt(index));
    return (
      currencyCode: code,
      index: index,
      alerts: [for (final a in alerts) _toAlert(a)],
    );
  });

  @override
  Future<void> restore(RemovedWatchItem item) => _db.transaction(() async {
    final codes = [for (final r in await _ordered().get()) r.currencyCode];
    if (codes.contains(item.currencyCode)) return;
    codes.insert(item.index.clamp(0, codes.length), item.currencyCode);
    await _writeOrder(codes);
    await _db.batch(
      (b) => b.insertAll(_alerts, [
        for (final a in item.alerts) _toRow(a),
      ], mode: InsertMode.insertOrReplace),
    );
  });

  @override
  Future<void> reorder(List<String> codes) =>
      _db.transaction(() => _writeOrder(codes));

  /// Rewrites the whole list: it's a handful of rows, and it keeps
  /// positions dense (0..n-1) whatever happened before.
  Future<void> _writeOrder(List<String> codes) async {
    await _db.delete(_items).go();
    await _db.batch(
      (b) => b.insertAll(_items, [
        for (final (i, code) in codes.indexed)
          WatchlistItemsCompanion.insert(currencyCode: code, position: i),
      ]),
    );
  }

  // --- Alerts ----------------------------------------------------------------

  @override
  Stream<List<RateAlert>> watchAlerts() =>
      (_db.select(_alerts)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch()
          .map((rows) => [for (final r in rows) _toAlert(r)]);

  @override
  Future<List<RateAlert>> activeAlerts() async {
    final rows = await (_db.select(
      _alerts,
    )..where((t) => t.enabled.equals(true) & t.triggeredAt.isNull())).get();
    return [for (final r in rows) _toAlert(r)];
  }

  @override
  Future<void> addAlert(NewRateAlert alert) => _db.transaction(() async {
    await add(alert.currencyCode);
    await _db
        .into(_alerts)
        .insert(
          RateAlertsCompanion.insert(
            currencyCode: alert.currencyCode,
            direction: alert.direction.name,
            target: alert.target,
            rateType: alert.rateType.name,
            createdAt: _clock.now(),
          ),
        );
  });

  @override
  Future<void> deleteAlert(int id) =>
      (_db.delete(_alerts)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> setAlertEnabled(int id, {required bool enabled}) =>
      (_db.update(_alerts)..where((t) => t.id.equals(id))).write(
        RateAlertsCompanion(
          enabled: Value(enabled),
          // Re-arming forgets the last trigger so the alert can fire again.
          triggeredAt: enabled ? const Value(null) : const Value.absent(),
          triggeredRate: enabled ? const Value(null) : const Value.absent(),
          triggeredPeriod: enabled ? const Value(null) : const Value.absent(),
        ),
      );

  @override
  Future<List<AlertTrigger>> markTriggered(
    List<AlertTrigger> triggers,
    DateTime at,
  ) => _db.transaction(() async {
    final recorded = <AlertTrigger>[];
    for (final trigger in triggers) {
      final updated =
          await (_db.update(_alerts)..where(
                (t) => t.id.equals(trigger.alert.id) & t.triggeredAt.isNull(),
              ))
              .write(
                RateAlertsCompanion(
                  enabled: const Value(false),
                  triggeredAt: Value(at.toUtc()),
                  triggeredRate: Value(trigger.rate),
                  triggeredPeriod: Value(trigger.period),
                ),
              );
      if (updated > 0) recorded.add(trigger);
    }
    return recorded;
  });

  // --- Mapping ---------------------------------------------------------------

  static RateAlert _toAlert(RateAlertRow r) => RateAlert(
    id: r.id,
    currencyCode: r.currencyCode,
    direction: AlertDirection.values.byName(r.direction),
    target: r.target,
    rateType: RateType.values.byName(r.rateType),
    createdAt: r.createdAt,
    enabled: r.enabled,
    triggeredAt: r.triggeredAt,
    triggeredRate: r.triggeredRate,
    triggeredPeriod: r.triggeredPeriod,
  );

  static RateAlertRow _toRow(RateAlert a) => RateAlertRow(
    id: a.id,
    currencyCode: a.currencyCode,
    direction: a.direction.name,
    target: a.target,
    rateType: a.rateType.name,
    enabled: a.enabled,
    createdAt: a.createdAt,
    triggeredAt: a.triggeredAt,
    triggeredRate: a.triggeredRate,
    triggeredPeriod: a.triggeredPeriod,
  );
}

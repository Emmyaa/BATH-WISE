import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:drift/drift.dart';

/// Drift-backed cache of exchange rates.
class RatesLocalDataSource {
  const new(this._db);

  final AppDatabase _db;

  Future<void> upsert(List<ExchangeRate> rates, Periodicity periodicity) =>
      _db.batch(
        (b) => b.insertAllOnConflictUpdate(_db.rateRows, [
          for (final r in rates)
            RateRowsCompanion.insert(
              source: r.source.name,
              periodicity: periodicity.name,
              periodStart: r.period,
              currencyCode: r.currencyCode,
              unit: r.unit,
              nameEn: r.nameEn,
              nameTh: r.nameTh,
              buyingSight: Value(r.buyingSight),
              buyingTransfer: Value(r.buyingTransfer),
              selling: Value(r.selling),
              midRate: Value(r.mid),
            ),
        ]),
      );

  /// Daily rows from the newest cached day back [lookback] days: the
  /// latest/previous pair plus about a month of sparkline history.
  Future<List<ExchangeRate>> recentDaily(
    RateSource source, {
    Duration lookback = const Duration(days: 35),
  }) async {
    final newest = _db.rateRows.periodStart.max();
    final latest =
        await (_db.selectOnly(_db.rateRows)
              ..addColumns([newest])
              ..where(_daily(source)))
            .map((row) => row.read(newest))
            .getSingleOrNull();
    if (latest == null) return const [];

    final rows =
        await (_db.select(_db.rateRows)..where(
              (t) =>
                  _daily(source) &
                  t.periodStart.isBiggerOrEqualValue(latest.subtract(lookback)),
            ))
            .get();
    return rows.map(_toEntity).toList();
  }

  /// [currencyCode]'s rows in `[start, end]`, oldest first.
  Future<List<ExchangeRate>> series({
    required String currencyCode,
    required Periodicity periodicity,
    required RateSource source,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows =
        await (_db.select(_db.rateRows)
              ..where(
                (t) =>
                    t.source.equals(source.name) &
                    t.periodicity.equals(periodicity.name) &
                    t.currencyCode.equals(currencyCode) &
                    t.periodStart.isBetweenValues(start, end),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.periodStart)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  Expression<bool> _daily(RateSource source) =>
      _db.rateRows.source.equals(source.name) &
      _db.rateRows.periodicity.equals(Periodicity.daily.name);

  static ExchangeRate _toEntity(RateRow row) => ExchangeRate(
    currencyCode: row.currencyCode,
    period: row.periodStart,
    source: RateSource.values.byName(row.source),
    unit: row.unit,
    nameEn: row.nameEn,
    nameTh: row.nameTh,
    buyingSight: row.buyingSight,
    buyingTransfer: row.buyingTransfer,
    selling: row.selling,
    mid: row.midRate,
  );
}

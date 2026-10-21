import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:drift/drift.dart';

class LoanRatesLocalDataSource {
  const new(this._db);

  final AppDatabase _db;

  Future<void> upsert(List<LoanRate> rates) => _db.batch(
    (b) => b.insertAllOnConflictUpdate(_db.loanRateRows, [
      for (final r in rates)
        LoanRateRowsCompanion.insert(
          kind: r.kind.name,
          period: r.period,
          nameEn: r.nameEn,
          nameTh: r.nameTh,
          bankTypeEn: Value(r.bankTypeEn),
          bankTypeTh: Value(r.bankTypeTh),
          mor: Value(r.mor),
          mlr: Value(r.mlr),
          mrr: Value(r.mrr),
          ceilingRate: Value(r.ceilingRate),
          defaultRate: Value(r.defaultRate),
          creditCardMin: Value(r.creditCardMin),
          creditCardMax: Value(r.creditCardMax),
        ),
    ]),
  );

  /// All rows of the newest cached period for [kind].
  Future<List<LoanRate>> latest(LoanRateKind kind) async {
    final newest = _db.loanRateRows.period.max();
    final period =
        await (_db.selectOnly(_db.loanRateRows)
              ..addColumns([newest])
              ..where(_db.loanRateRows.kind.equals(kind.name)))
            .map((row) => row.read(newest))
            .getSingleOrNull();
    if (period == null) return const [];

    final rows =
        await (_db.select(_db.loanRateRows)
              ..where((t) => t.kind.equals(kind.name) & t.period.equals(period))
              ..orderBy([(t) => OrderingTerm.asc(t.nameEn)]))
            .get();
    return [
      for (final r in rows)
        LoanRate(
          kind: kind,
          period: r.period,
          nameEn: r.nameEn,
          nameTh: r.nameTh,
          bankTypeEn: r.bankTypeEn,
          bankTypeTh: r.bankTypeTh,
          mor: r.mor,
          mlr: r.mlr,
          mrr: r.mrr,
          ceilingRate: r.ceilingRate,
          defaultRate: r.defaultRate,
          creditCardMin: r.creditCardMin,
          creditCardMax: r.creditCardMax,
        ),
    ];
  }
}

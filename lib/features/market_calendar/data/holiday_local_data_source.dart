import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:drift/drift.dart';

class HolidayLocalDataSource {
  const new(this._db);

  final AppDatabase _db;

  Future<List<Holiday>> holidaysFor(int year) async {
    final rows =
        await (_db.select(_db.holidayRows)
              ..where((t) => t.year.equals(year))
              ..orderBy([(t) => OrderingTerm.asc(t.date)]))
            .get();
    return [
      for (final r in rows)
        Holiday(date: r.date, nameEn: r.nameEn, nameTh: r.nameTh),
    ];
  }

  /// Replaces the whole year: BOT may add or move holidays mid-year.
  Future<void> replaceYear(int year, List<Holiday> holidays) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.holidayRows,
        )..where((t) => t.year.equals(year))).go();
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(_db.holidayRows, [
            for (final h in holidays)
              HolidayRowsCompanion.insert(
                date: h.date,
                year: year,
                nameEn: h.nameEn,
                nameTh: h.nameTh,
              ),
          ]),
        );
      });
}

import 'package:bath_wise/core/database/decimal_converter.dart';
import 'package:bath_wise/core/database/tables.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [RateRows, LoanRateRows, HolidayRows, FetchLogs])
class AppDatabase extends _$AppDatabase {
  /// Pass `NativeDatabase.memory()` in tests.
  new(super.e);

  @override
  int get schemaVersion => 1;

  // --- Fetch log -----------------------------------------------------------

  Future<DateTime?> fetchedAt(String key) async {
    final row = await (select(
      fetchLogs,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.at;
  }

  Future<void> markFetched(String key, DateTime at) => into(
    fetchLogs,
  ).insertOnConflictUpdate(FetchLogsCompanion.insert(key: key, at: at.toUtc()));
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(driftDatabase(name: 'bath_wise'));
  ref.onDispose(db.close);
  return db;
}

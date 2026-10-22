import 'package:bath_wise/core/database/decimal_converter.dart';
import 'package:bath_wise/core/database/tables.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    RateRows,
    LoanRateRows,
    HolidayRows,
    FetchLogs,
    WatchlistItems,
    RateAlerts,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Pass `NativeDatabase.memory()` in tests.
  new(super.e);

  /// What a new install (or an upgrade from before the watchlist was
  /// stored) starts with. Plain codes, so core needn't import features.
  static const starterWatchlist = ['USD', 'EUR', 'JPY', 'GBP', 'CNY', 'SGD'];

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedWatchlist();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(watchlistItems);
        await m.createTable(rateAlerts);
        await _seedWatchlist();
      }
    },
  );

  Future<void> _seedWatchlist() => batch(
    (b) => b.insertAll(watchlistItems, [
      for (final (i, code) in starterWatchlist.indexed)
        WatchlistItemsCompanion.insert(currencyCode: code, position: i),
    ]),
  );

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
  final db = AppDatabase(
    driftDatabase(
      name: 'bath_wise',
      // The rate-alert worker opens the database from a background isolate.
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );
  ref.onDispose(db.close);
  return db;
}

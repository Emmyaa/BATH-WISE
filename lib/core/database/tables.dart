import 'package:bath_wise/core/database/decimal_converter.dart';
import 'package:drift/drift.dart';

// Enum-like columns (source, periodicity, kind) are stored as their
// domain enum's `name`; features map them so core never imports features.

/// Exchange rates at any periodicity, from any source.
@DataClassName('RateRow')
class RateRows extends Table {
  /// `RateSource.name`: `bot` or `ecb`.
  TextColumn get source => text()();

  /// `Periodicity.name`: `daily`, `monthly`, `quarterly`, `annual`.
  TextColumn get periodicity => text()();

  /// First day of the period, for range queries and sorting.
  DateTimeColumn get periodStart => dateTime()();

  TextColumn get currencyCode => text()();

  /// Foreign units the rate is quoted per (JPY 100, IDR 1000, else 1).
  IntColumn get unit => integer()();

  TextColumn get nameEn => text()();
  TextColumn get nameTh => text()();
  TextColumn get buyingSight =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get buyingTransfer =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get selling => text().map(const DecimalConverter()).nullable()();
  TextColumn get midRate => text().map(const DecimalConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {
    source,
    periodicity,
    periodStart,
    currencyCode,
  };
}

/// Per-bank rates and BOT's averages, told apart by [kind].
@DataClassName('LoanRateRow')
class LoanRateRows extends Table {
  /// `LoanRateKind.name`: `bank` or `average`.
  TextColumn get kind => text()();
  DateTimeColumn get period => dateTime()();
  TextColumn get nameEn => text()();
  TextColumn get nameTh => text()();
  TextColumn get bankTypeEn => text().nullable()();
  TextColumn get bankTypeTh => text().nullable()();
  TextColumn get mor => text().map(const DecimalConverter()).nullable()();
  TextColumn get mlr => text().map(const DecimalConverter()).nullable()();
  TextColumn get mrr => text().map(const DecimalConverter()).nullable()();
  TextColumn get ceilingRate =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get defaultRate =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get creditCardMin =>
      text().map(const DecimalConverter()).nullable()();
  TextColumn get creditCardMax =>
      text().map(const DecimalConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {kind, period, nameEn};
}

@DataClassName('HolidayRow')
class HolidayRows extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get year => integer()();
  TextColumn get nameEn => text()();
  TextColumn get nameTh => text()();

  @override
  Set<Column<Object>> get primaryKey => {date};
}

/// When each cached resource was last fetched (or last failed), driving
/// the release-time refresh rules.
@DataClassName('FetchLogRow')
class FetchLogs extends Table {
  TextColumn get key => text()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

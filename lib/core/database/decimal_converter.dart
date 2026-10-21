import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

/// Stores [Decimal] as TEXT so no precision is lost to SQLite's REAL.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const new();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toString();
}

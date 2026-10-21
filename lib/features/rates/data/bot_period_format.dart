import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';

/// BOT period strings per the specs: `YYYY-MM-DD`, `YYYY-MM`, `YYYY-QN`,
/// `YYYY`. Periods map to their first day.
abstract final class BotPeriodFormat {
  static String format(Periodicity periodicity, DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    return switch (periodicity) {
      Periodicity.daily => formatYmd(date),
      Periodicity.monthly => '$year-${date.month.toString().padLeft(2, '0')}',
      Periodicity.quarterly => '$year-Q${(date.month - 1) ~/ 3 + 1}',
      Periodicity.annual => year,
    };
  }

  /// Throws [FormatException] on a malformed period.
  static DateTime parse(Periodicity periodicity, String value) {
    final v = value.trim();
    switch (periodicity) {
      case Periodicity.daily:
        return parseYmd(v);
      case Periodicity.monthly:
        final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(v);
        if (m == null) throw FormatException('Expected YYYY-MM', value);
        return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!));
      case Periodicity.quarterly:
        final m = RegExp(r'^(\d{4})-Q([1-4])$').firstMatch(v);
        if (m == null) throw FormatException('Expected YYYY-QN', value);
        return DateTime.utc(int.parse(m[1]!), (int.parse(m[2]!) - 1) * 3 + 1);
      case Periodicity.annual:
        final m = RegExp(r'^(\d{4})$').firstMatch(v);
        if (m == null) throw FormatException('Expected YYYY', value);
        return DateTime.utc(int.parse(m[1]!));
    }
  }
}

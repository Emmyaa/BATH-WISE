/// Asia/Bangkok helpers. Thailand is UTC+7 with no DST, so a fixed offset is
/// exact and no timezone database is needed.
///
/// Conventions used across the app:
/// - An *instant* is a UTC [DateTime].
/// - A *date* (calendar day, no time) is `DateTime.utc(y, m, d)`.
abstract final class Bangkok {
  static const utcOffset = Duration(hours: 7);

  /// Bangkok wall-clock time of [instant], as a UTC DateTime whose fields
  /// read as Bangkok local time. Use only to read fields, never as an
  /// instant.
  static DateTime wallClock(DateTime instant) => instant.toUtc().add(utcOffset);

  /// The Bangkok calendar date of [instant].
  static DateTime dateOf(DateTime instant) => dateOnly(wallClock(instant));

  /// The instant [date] at [hour]:[minute] Bangkok time.
  static DateTime instantAt(DateTime date, {int hour = 0, int minute = 0}) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      ).subtract(utcOffset);
}

/// Strips the time; the result follows the date convention above.
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// `YYYY-MM-DD`.
String formatYmd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Parses `YYYY-MM-DD` into a date. Throws [FormatException].
DateTime parseYmd(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) throw FormatException('Expected YYYY-MM-DD', value);
  return DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

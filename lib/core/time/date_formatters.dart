import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:intl/intl.dart';

/// User-facing dates. Thai uses the Buddhist era (พ.ศ. = CE + 543), which
/// intl doesn't apply by itself.
class DateFormatters {
  new(this.locale);

  final String locale;

  bool get _thai => locale.startsWith('th');

  /// A calendar date: "Oct 19, 2026" / "19 ต.ค. 2569".
  String date(DateTime date) => _thai
      ? '${DateFormat('d MMM', locale).format(date)} ${date.year + 543}'
      : DateFormat.yMMMd(locale).format(date);

  /// Short weekday of a Bangkok date: "Mon" / "จ.".
  String weekday(DateTime date) => DateFormat.E(locale).format(date);

  /// Bangkok wall-clock time of an instant: "18:00".
  String bangkokTime(DateTime instant) =>
      DateFormat.Hm(locale).format(Bangkok.wallClock(instant));

  /// An instant in the device's time zone, for "last updated": "14:05"
  /// today, otherwise "19 Oct 14:05".
  String updatedAt(DateTime instant, {required DateTime now}) {
    final local = instant.toLocal();
    final time = DateFormat.Hm(locale).format(local);
    final today = now.toLocal();
    final sameDay =
        local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    return sameDay ? time : '${DateFormat.MMMd(locale).format(local)} $time';
  }
}

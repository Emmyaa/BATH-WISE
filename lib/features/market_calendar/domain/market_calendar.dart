import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';

/// When BOT publishes each dataset, Bangkok time, on business days.
enum ReleaseTime {
  exchangeRates(hour: 18),
  loanRates(hour: 14);

  new({required this.hour});

  final int hour;
}

/// Business-day and release-time rules for BOT data.
///
/// A business day is Monday–Friday and not a BOT financial-institution
/// holiday. If the holiday list couldn't be loaded the calendar degrades to
/// weekends-only, which at worst causes an extra refresh on a holiday.
class MarketCalendar {
  new([Iterable<Holiday> holidays = const []])
    : _holidays = {for (final h in holidays) dateOnly(h.date): h};

  final Map<DateTime, Holiday> _holidays;

  /// Holidays plus weekends could never span this many days; it only
  /// guards against an infinite loop on corrupt data.
  static const _maxScanDays = 60;

  bool get hasHolidayData => _holidays.isNotEmpty;

  Holiday? holidayOn(DateTime date) => _holidays[dateOnly(date)];

  bool isWeekend(DateTime date) => date.weekday >= DateTime.saturday;

  bool isBusinessDay(DateTime date) =>
      !isWeekend(date) && holidayOn(date) == null;

  /// The closest business day strictly before [date].
  DateTime previousBusinessDay(DateTime date) => _scan(date, -1);

  /// The closest business day strictly after [date].
  DateTime nextBusinessDay(DateTime date) => _scan(date, 1);

  /// The most recent release at or before [now] (an instant).
  DateTime latestRelease(DateTime now, ReleaseTime release) {
    final today = Bangkok.dateOf(now);
    final todayRelease = Bangkok.instantAt(today, hour: release.hour);
    final day = isBusinessDay(today) && !now.isBefore(todayRelease)
        ? today
        : previousBusinessDay(today);
    return Bangkok.instantAt(day, hour: release.hour);
  }

  /// The first release strictly after [now] (an instant).
  DateTime nextRelease(DateTime now, ReleaseTime release) {
    final today = Bangkok.dateOf(now);
    final todayRelease = Bangkok.instantAt(today, hour: release.hour);
    final day = isBusinessDay(today) && now.isBefore(todayRelease)
        ? today
        : nextBusinessDay(today);
    return Bangkok.instantAt(day, hour: release.hour);
  }

  /// The business date whose data the latest release carries.
  DateTime latestReleaseDate(DateTime now, ReleaseTime release) =>
      Bangkok.dateOf(latestRelease(now, release));

  DateTime _scan(DateTime from, int step) {
    var day = dateOnly(from);
    for (var i = 0; i < _maxScanDays; i++) {
      day = DateTime.utc(day.year, day.month, day.day + step);
      if (isBusinessDay(day)) return day;
    }
    throw StateError('No business day within $_maxScanDays days of $from');
  }
}

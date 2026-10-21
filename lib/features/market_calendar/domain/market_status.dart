import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';

enum MarketStatusKind {
  /// Data is for today.
  upToDate,

  /// Business day, today's release hasn't happened yet.
  awaitingRelease,

  /// Today is Saturday or Sunday.
  weekend,

  /// A bank holiday is why today's (or a recent day's) data is missing.
  holiday,

  /// The release time has passed but BOT hasn't published yet.
  delayed,
}

/// Why the shown data is for [asOf], and when new data is expected.
class MarketStatus {
  const new({
    required this.kind,
    required this.asOf,
    required this.nextRelease,
    this.holiday,
  });

  final MarketStatusKind kind;

  /// Date of the data being shown.
  final DateTime asOf;

  /// Next expected release (instant).
  final DateTime nextRelease;

  /// Set when [kind] is [MarketStatusKind.holiday].
  final Holiday? holiday;
}

/// Explains missing data: "Bank holiday ({name}) — showing rates as of
/// {date}" and the next expected update.
class ResolveMarketStatus {
  const new();

  MarketStatus call({
    required DateTime now,
    required DateTime asOf,
    required MarketCalendar calendar,
    ReleaseTime release = ReleaseTime.exchangeRates,
  }) {
    final today = Bangkok.dateOf(now);
    final shown = dateOnly(asOf);
    final next = calendar.nextRelease(now, release);
    MarketStatus status(MarketStatusKind kind, [Holiday? holiday]) =>
        MarketStatus(
          kind: kind,
          asOf: shown,
          nextRelease: next,
          holiday: holiday,
        );

    if (!shown.isBefore(today)) return status(MarketStatusKind.upToDate);

    final holiday =
        calendar.holidayOn(today) ?? _holidayBetween(calendar, shown, today);
    if (holiday != null) return status(MarketStatusKind.holiday, holiday);
    if (calendar.isWeekend(today)) return status(MarketStatusKind.weekend);

    final expected = calendar.latestReleaseDate(now, release);
    return shown.isBefore(expected)
        ? status(MarketStatusKind.delayed)
        : status(MarketStatusKind.awaitingRelease);
  }

  /// The most recent holiday strictly after [from] and before [to].
  static Holiday? _holidayBetween(
    MarketCalendar calendar,
    DateTime from,
    DateTime to,
  ) {
    for (
      var day = DateTime.utc(to.year, to.month, to.day - 1);
      day.isAfter(from);
      day = DateTime.utc(day.year, day.month, day.day - 1)
    ) {
      if (calendar.holidayOn(day) case final holiday?) return holiday;
    }
    return null;
  }
}

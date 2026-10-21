import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';

/// Builds a [MarketCalendar] covering the days around a given instant.
class MarketCalendarService {
  const new(this._holidays);

  final HolidayRepository _holidays;

  /// Loads the current Bangkok year, plus the previous one in January
  /// (look-backs cross New Year) and the next one in December. Failed
  /// years are skipped: the calendar falls back to weekends-only.
  Future<MarketCalendar> calendarAround(DateTime now) async {
    final today = Bangkok.dateOf(now);
    final years = {
      if (today.month == DateTime.january) today.year - 1,
      today.year,
      if (today.month == DateTime.december) today.year + 1,
    };
    final results = await Future.wait(years.map(_holidays.getHolidays));
    return MarketCalendar([
      for (final result in results) ...?result.valueOrNull,
    ]);
  }
}

import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';

abstract interface class HolidayRepository {
  /// BOT holidays for [year], cached per year.
  Future<Result<List<Holiday>>> getHolidays(int year);
}

import 'package:bath_wise/features/rates/domain/rate_enums.dart';

/// Time spans of the Currency Detail chart.
///
/// Short ranges use daily rates; 1Y/5Y use BOT's monthly averages, which
/// cost one call instead of 12 or 60 daily chunks (200 calls/hour quota).
enum ChartRange {
  week(Periodicity.daily),
  month(Periodicity.daily),
  threeMonths(Periodicity.daily),
  year(Periodicity.monthly),
  fiveYears(Periodicity.monthly);

  new(this.periodicity);

  final Periodicity periodicity;

  /// First day of the range that ends on [today] (a Bangkok date).
  /// Monthly ranges start on the first of a month.
  DateTime startFor(DateTime today) => switch (this) {
    week => DateTime.utc(today.year, today.month, today.day - 7),
    // 31 days inclusive: BOT's daily limit, so a single call.
    month => DateTime.utc(today.year, today.month, today.day - 30),
    threeMonths => DateTime.utc(today.year, today.month - 3, today.day),
    year => DateTime.utc(today.year - 1, today.month),
    fiveYears => DateTime.utc(today.year - 5, today.month),
  };
}

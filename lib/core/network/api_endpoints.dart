/// Endpoints from docs/api-specs/*.json. Frankfurter has no spec file; its
/// shapes are verified against docs/api-samples/frankfurter_*.json.
abstract final class BotEndpoints {
  static const baseUrl = 'https://gateway.api.bot.or.th';

  static const dailyExchangeRate = '/Stat-ExchangeRate/v2/DAILY_AVG_EXG_RATE/';
  static const monthlyExchangeRate =
      '/Stat-ExchangeRate/v2/MONTHLY_AVG_EXG_RATE/';
  static const quarterlyExchangeRate =
      '/Stat-ExchangeRate/v2/QUARTERLY_AVG_EXG_RATE/';
  static const annualExchangeRate =
      '/Stat-ExchangeRate/v2/ANNUAL_AVG_EXG_RATE/';

  static const loanRate = '/LoanRate/v2/loan_rate/';
  static const averageLoanRate = '/LoanRate/v2/avg_loan_rate/';

  static const holidays = '/financial-institutions-holidays/';

  /// Daily endpoints reject longer ranges with 400 "Exceed limit period.
  /// Limit period is 31 days" (docs/api-samples/error_range_limit.json).
  static const maxDailyRangeDays = 31;
}

abstract final class FrankfurterEndpoints {
  static const baseUrl = 'https://api.frankfurter.dev/v1';

  static const latest = '/latest';

  /// `/{start}..{end}`, both `YYYY-MM-DD`.
  static String timeSeries(String start, String end) => '/$start..$end';
}

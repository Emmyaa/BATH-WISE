import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_providers.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rates_repository.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_dto.dart';
import 'package:bath_wise/features/rates/data/rates_providers.dart';
import 'package:bath_wise/features/rates/domain/fx_repository.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:flutter_riverpod/misc.dart';

import 'test_helpers.dart';

/// Snapshot built from the real daily sample (as of Mon 19 Oct 2026).
RatesSnapshot sampleSnapshot({
  RateSource source = RateSource.bot,
  Failure? refreshFailure,
}) {
  final rates = [
    for (final row in botDataDetail(loadApiSample('exchange_daily_all')))
      ?BotExchangeRateDto.fromJson(row).toEntity(Periodicity.daily),
  ];
  return RatesSnapshot(
    asOf: DateTime.utc(2026, 10, 19),
    source: source,
    quotes: RateQuote.fromRates(rates),
    fetchedAt: bkk(2026, 10, 19, 18, 5),
    refreshFailure: refreshFailure,
  );
}

class FakeFxRepository implements FxRepository {
  new(this.latest);

  /// What [getLatestRates] returns; replace between calls.
  Result<RatesSnapshot> latest;
  int latestCalls = 0;
  bool? lastForceRefresh;

  @override
  Future<Result<RatesSnapshot>> getLatestRates({
    bool forceRefresh = false,
  }) async {
    latestCalls++;
    lastForceRefresh = forceRefresh;
    return latest;
  }

  @override
  Future<Result<RateSeries>> getHistory({
    required String currencyCode,
    required Periodicity periodicity,
    required DateTime start,
    required DateTime end,
  }) async => const Err(NoDataFailure());

  @override
  Future<Result<CrossRate>> getCrossRate({
    required String base,
    required String quote,
  }) async => const Err(NoDataFailure());
}

class FakeHolidayRepository implements HolidayRepository {
  new([this.holidays = const []]);

  final List<Holiday> holidays;

  @override
  Future<Result<List<Holiday>>> getHolidays(int year) async => Ok([
    for (final h in holidays)
      if (h.date.year == year) h,
  ]);
}

class FakeLoanRatesRepository implements LoanRatesRepository {
  new([this.result = const Err(UnauthorizedFailure('403'))]);

  final Result<LoanRatesSnapshot> result;

  @override
  Future<Result<LoanRatesSnapshot>> getLatest(
    LoanRateKind kind, {
    bool forceRefresh = false,
  }) async => result;
}

/// Overrides every provider that would touch the network, disk or clock.
List<Override> appOverrides({
  required FxRepository fx,
  DateTime? now,
  List<Holiday> holidays = const [],
  LoanRatesRepository? loans,
}) {
  final holidayRepo = FakeHolidayRepository(holidays);
  return [
    fxRepositoryProvider.overrideWithValue(fx),
    holidayRepositoryProvider.overrideWithValue(holidayRepo),
    marketCalendarServiceProvider.overrideWithValue(
      MarketCalendarService(holidayRepo),
    ),
    loanRatesRepositoryProvider.overrideWithValue(
      loans ?? FakeLoanRatesRepository(),
    ),
    clockProvider.overrideWithValue(FakeClock(now ?? bkk(2026, 10, 20, 9))),
  ];
}

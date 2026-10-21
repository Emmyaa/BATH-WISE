import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate_models.freezed.dart';

/// The latest rates for all currencies, as shown on Dashboard and Rates.
@freezed
abstract class RatesSnapshot with _$RatesSnapshot {
  const factory({
    /// Newest period in `quotes`, i.e. "rates as of".
    required DateTime asOf,
    required RateSource source,
    required List<RateQuote> quotes,

    /// When this data was downloaded (UTC), for "last updated".
    required DateTime fetchedAt,

    /// Why this isn't freshly fetched BOT data: the refresh failed and this
    /// is cache, or BOT failed and `source` is the ECB fallback.
    /// Null when the data is current.
    Failure? refreshFailure,
  }) = _RatesSnapshot;

  const new _();

  bool get isDegraded => refreshFailure != null;

  RateQuote? quoteFor(String currencyCode) {
    for (final quote in quotes) {
      if (quote.currencyCode == currencyCode) return quote;
    }
    return null;
  }
}

/// Historical rates for one currency, oldest first.
@freezed
abstract class RateSeries with _$RateSeries {
  const factory({
    required String currencyCode,
    required Periodicity periodicity,
    required RateSource source,
    required List<ExchangeRate> points,

    /// Set when the series came from cache because the refresh failed.
    Failure? refreshFailure,
  }) = _RateSeries;
}

/// `1 base = rate quote`, for pairs that don't involve THB (ECB data).
@freezed
abstract class CrossRate with _$CrossRate {
  const factory({
    required String base,
    required String quote,
    required Decimal rate,

    /// ECB reference date the rate is for.
    required DateTime date,
    required DateTime fetchedAt,
    @Default(RateSource.ecb) RateSource source,
  }) = _CrossRate;
}

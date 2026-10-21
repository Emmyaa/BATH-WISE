import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate_quote.freezed.dart';

/// A currency's latest rate, the one before it (daily change) and its
/// recent history (sparkline).
@freezed
abstract class RateQuote with _$RateQuote {
  const factory({
    required ExchangeRate current,
    ExchangeRate? previous,

    /// Recent daily rates, oldest first (including `current`), for
    /// sparklines.
    @Default(<ExchangeRate>[]) List<ExchangeRate> recent,
  }) = _RateQuote;

  const new _();

  String get currencyCode => current.currencyCode;

  /// Absolute change vs. the previous period, or null if either is missing.
  Decimal? change(RateType type) {
    final now = current.valueOf(type);
    final before = previous?.valueOf(type);
    if (now == null || before == null) return null;
    return now - before;
  }

  /// Change in percent (e.g. `0.25` = +0.25%), 4 decimal places.
  Decimal? changePercent(RateType type) {
    final delta = change(type);
    final before = previous?.valueOf(type);
    if (delta == null || before == null || before == Decimal.zero) return null;
    return (delta * Decimal.fromInt(100)).dividedBy(before, scale: 4);
  }

  /// Builds one quote per currency from a set of daily rates: the newest
  /// row is `current`, the next newest `previous`, all rows `recent`.
  /// Each currency is paired independently, since BOT can skip a currency
  /// on some days.
  /// Sorted in BOT's currency order.
  static List<RateQuote> fromRates(Iterable<ExchangeRate> rates) {
    final byCode = <String, List<ExchangeRate>>{};
    for (final rate in rates) {
      (byCode[rate.currencyCode] ??= []).add(rate);
    }
    final quotes = <RateQuote>[];
    for (final list in byCode.values) {
      list.sort((a, b) => b.period.compareTo(a.period));
      quotes.add(
        RateQuote(
          current: list[0],
          previous: list.length > 1 ? list[1] : null,
          recent: list.reversed.toList(growable: false),
        ),
      );
    }
    return quotes..sort(
      (a, b) =>
          Currencies.orderOf(a.currencyCode)
              .compareTo(Currencies.orderOf(b.currencyCode)),
    );
  }
}

import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_rate.freezed.dart';

/// THB per `unit` of a foreign currency for one period.
///
/// BOT values may be missing (null). ECB rates only carry `mid`.
@freezed
abstract class ExchangeRate with _$ExchangeRate {
  const factory({
    required String currencyCode,

    /// First day of the period (`DateTime.utc(y, m, d)`).
    required DateTime period,
    required RateSource source,
    @Default(1) int unit,
    @Default('') String nameEn,
    @Default('') String nameTh,
    Decimal? buyingSight,
    Decimal? buyingTransfer,
    Decimal? selling,
    Decimal? mid,
  }) = _ExchangeRate;

  const new _();

  /// THB per `unit` foreign units, as published.
  Decimal? valueOf(RateType type) => switch (type) {
    RateType.buyingSight => buyingSight,
    RateType.buyingTransfer => buyingTransfer,
    RateType.selling => selling,
    RateType.mid => mid,
  };

  /// THB per *one* foreign unit, for conversion math.
  Decimal? perUnit(RateType type) {
    final value = valueOf(type);
    if (value == null || unit == 1) return value;
    return value.dividedBy(Decimal.fromInt(unit));
  }
}

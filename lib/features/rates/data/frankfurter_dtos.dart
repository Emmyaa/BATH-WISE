import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

part 'frankfurter_dtos.g.dart';

/// `GET /latest` (docs/api-samples/frankfurter_latest_thb.json).
@JsonSerializable()
class FrankfurterLatestDto {
  const new({required this.base, required this.date, required this.rates});

  factory fromJson(Map<String, dynamic> json) =>
      _$FrankfurterLatestDtoFromJson(json);

  final String base;
  final String date;
  final Map<String, num> rates;
}

/// `GET /{start}..{end}`
/// (docs/api-samples/frankfurter_series_usd_thb.json).
@JsonSerializable()
class FrankfurterSeriesDto {
  const new({required this.base, required this.rates});

  factory fromJson(Map<String, dynamic> json) =>
      _$FrankfurterSeriesDtoFromJson(json);

  final String base;

  /// `{"2026-10-19": {"THB": 33.555}, ...}`; business days only.
  final Map<String, Map<String, num>> rates;

  /// With base THB: converts "foreign per 1 THB" into BOT's convention,
  /// THB per `unit` foreign units (`unit / rate`). Only BOT's currencies
  /// are kept so the fallback list matches the normal one.
  List<ExchangeRate> toThbRates() => [
    for (final MapEntry(key: day, value: perThb) in rates.entries)
      for (final info in Currencies.bot)
        if (_positive(perThb[info.code]) case final rate?)
          _ecbRate(
            info,
            parseYmd(day),
            Decimal.fromInt(info.unit).dividedBy(rate, scale: 7),
          ),
  ];

  /// With base = a foreign currency and symbol THB: THB per `unit`.
  List<ExchangeRate> toThbSeries(String currencyCode) {
    final info =
        Currencies.byCode(currencyCode) ??
        CurrencyInfo(currencyCode, currencyCode, currencyCode);
    return [
      for (final MapEntry(key: day, value: values) in rates.entries)
        if (_positive(values['THB']) case final thb?)
          _ecbRate(info, parseYmd(day), thb * Decimal.fromInt(info.unit)),
    ]..sort((a, b) => a.period.compareTo(b.period));
  }

  static Decimal? _positive(num? value) {
    final d = parseDecimalOrNull(value);
    return d == null || d <= Decimal.zero ? null : d;
  }

  static ExchangeRate _ecbRate(CurrencyInfo info, DateTime day, Decimal mid) =>
      ExchangeRate(
        currencyCode: info.code,
        period: day,
        source: RateSource.ecb,
        unit: info.unit,
        nameEn: info.nameEn,
        nameTh: info.nameTh,
        mid: mid,
      );
}

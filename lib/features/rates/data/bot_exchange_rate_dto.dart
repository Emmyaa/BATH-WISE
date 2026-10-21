import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/features/rates/data/bot_period_format.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bot_exchange_rate_dto.g.dart';

/// One `data_detail` row of any BOT exchange-rate endpoint.
/// Every field is a string and any may be empty
/// (see docs/api-samples/exchange_*.json).
@JsonSerializable()
class BotExchangeRateDto {
  const new({
    this.period,
    this.currencyId,
    this.currencyNameTh,
    this.currencyNameEng,
    this.buyingSight,
    this.buyingTransfer,
    this.selling,
    this.midRate,
  });

  factory fromJson(Map<String, dynamic> json) =>
      _$BotExchangeRateDtoFromJson(json);

  final String? period;
  final String? currencyId;
  final String? currencyNameTh;
  final String? currencyNameEng;
  final String? buyingSight;
  final String? buyingTransfer;
  final String? selling;
  final String? midRate;

  /// Matches the quotation unit inside a name, e.g. "(100 YEN)" or
  /// "(1,000 RUPIAH)".
  static final _unitPattern = RegExp(r'\((\d[\d,]*)\s+[^()]+\)');

  /// Maps to the domain, or returns null for BOT's "no data" placeholder:
  /// a range with no release (weekend, holiday) returns one row per
  /// currency with an empty `period` and empty values.
  ExchangeRate? toEntity(Periodicity periodicity) {
    final code = currencyId?.trim() ?? '';
    final rawPeriod = period?.trim() ?? '';
    if (code.isEmpty || rawPeriod.isEmpty) return null;

    final info = Currencies.byCode(code);
    final nameEn = currencyNameEng?.trim() ?? '';
    return ExchangeRate(
      currencyCode: code,
      period: BotPeriodFormat.parse(periodicity, rawPeriod),
      source: RateSource.bot,
      unit: _parseUnit(nameEn) ?? info?.unit ?? 1,
      nameEn: info?.nameEn ?? nameEn,
      nameTh: info?.nameTh ?? currencyNameTh?.trim() ?? '',
      buyingSight: parseDecimalOrNull(buyingSight),
      buyingTransfer: parseDecimalOrNull(buyingTransfer),
      selling: parseDecimalOrNull(selling),
      mid: parseDecimalOrNull(midRate),
    );
  }

  static int? _parseUnit(String name) {
    final match = _unitPattern.firstMatch(name);
    return match == null ? null : int.parse(match[1]!.replaceAll(',', ''));
  }
}

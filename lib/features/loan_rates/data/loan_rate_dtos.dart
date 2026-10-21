import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:json_annotation/json_annotation.dart';

part 'loan_rate_dtos.g.dart';

// Shapes per docs/api-specs/interest-rates.json. No real sample yet (the
// current token gets 403); numbers are strings and may be empty.

/// `/loan_rate/` row.
@JsonSerializable()
class BankLoanRateDto {
  const new({
    this.period,
    this.bankTypeNameTh,
    this.bankTypeNameEng,
    this.bankNameTh,
    this.bankNameEng,
    this.mor,
    this.mlr,
    this.mrr,
    this.ceilingRate,
    this.defaultRate,
    this.creditcardMin,
    this.creditcardMax,
  });

  factory fromJson(Map<String, dynamic> json) =>
      _$BankLoanRateDtoFromJson(json);

  final String? period;
  final String? bankTypeNameTh;
  final String? bankTypeNameEng;
  final String? bankNameTh;
  final String? bankNameEng;
  final String? mor;
  final String? mlr;
  final String? mrr;
  final String? ceilingRate;
  final String? defaultRate;
  final String? creditcardMin;
  final String? creditcardMax;

  /// Null for a placeholder row without period or bank name.
  LoanRate? toEntity() {
    final day = period?.trim() ?? '';
    final name = bankNameEng?.trim() ?? '';
    if (day.isEmpty || name.isEmpty) return null;
    return LoanRate(
      kind: LoanRateKind.bank,
      period: parseYmd(day),
      nameEn: name,
      nameTh: bankNameTh?.trim() ?? '',
      bankTypeEn: bankTypeNameEng?.trim(),
      bankTypeTh: bankTypeNameTh?.trim(),
      mor: parseDecimalOrNull(mor),
      mlr: parseDecimalOrNull(mlr),
      mrr: parseDecimalOrNull(mrr),
      ceilingRate: parseDecimalOrNull(ceilingRate),
      defaultRate: parseDecimalOrNull(defaultRate),
      creditCardMin: parseDecimalOrNull(creditcardMin),
      creditCardMax: parseDecimalOrNull(creditcardMax),
    );
  }
}

/// `/avg_loan_rate/` row.
@JsonSerializable()
class AverageLoanRateDto {
  const new({
    this.period,
    this.nameTh,
    this.nameEng,
    this.mor,
    this.mlr,
    this.mrr,
    this.ceilingRate,
    this.defaultRate,
    this.creditcardMin,
    this.creditcardMax,
  });

  factory fromJson(Map<String, dynamic> json) =>
      _$AverageLoanRateDtoFromJson(json);

  final String? period;
  final String? nameTh;
  final String? nameEng;
  final String? mor;
  final String? mlr;
  final String? mrr;
  final String? ceilingRate;
  final String? defaultRate;
  final String? creditcardMin;
  final String? creditcardMax;

  LoanRate? toEntity() {
    final day = period?.trim() ?? '';
    final name = nameEng?.trim() ?? '';
    if (day.isEmpty || name.isEmpty) return null;
    return LoanRate(
      kind: LoanRateKind.average,
      period: parseYmd(day),
      nameEn: name,
      nameTh: nameTh?.trim() ?? '',
      mor: parseDecimalOrNull(mor),
      mlr: parseDecimalOrNull(mlr),
      mrr: parseDecimalOrNull(mrr),
      ceilingRate: parseDecimalOrNull(ceilingRate),
      defaultRate: parseDecimalOrNull(defaultRate),
      creditCardMin: parseDecimalOrNull(creditcardMin),
      creditCardMax: parseDecimalOrNull(creditcardMax),
    );
  }
}

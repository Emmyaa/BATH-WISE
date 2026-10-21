import 'package:bath_wise/core/error/failure.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'loan_rate.freezed.dart';

enum LoanRateKind {
  /// One bank's rates (`/loan_rate/`).
  bank,

  /// BOT's average across bank groups (`/avg_loan_rate/`).
  average,
}

/// Loan interest rates, % per annum. Any value may be missing.
@freezed
abstract class LoanRate with _$LoanRate {
  const factory({
    required LoanRateKind kind,
    required DateTime period,

    /// Bank name, or the averaged group's name.
    required String nameEn,
    required String nameTh,

    /// Bank type (e.g. commercial / foreign branch); null for averages.
    String? bankTypeEn,
    String? bankTypeTh,

    /// Minimum Overdraft Rate.
    Decimal? mor,

    /// Minimum Loan Rate.
    Decimal? mlr,

    /// Minimum Retail Rate.
    Decimal? mrr,
    Decimal? ceilingRate,
    Decimal? defaultRate,
    Decimal? creditCardMin,
    Decimal? creditCardMax,
  }) = _LoanRate;
}

@freezed
abstract class LoanRatesSnapshot with _$LoanRatesSnapshot {
  const factory({
    required LoanRateKind kind,

    /// Period of `rates` (the most recent one available).
    required DateTime asOf,
    required List<LoanRate> rates,
    required DateTime fetchedAt,

    /// Set when serving cache because the refresh failed.
    Failure? refreshFailure,
  }) = _LoanRatesSnapshot;
}

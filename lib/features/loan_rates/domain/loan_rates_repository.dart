import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';

abstract interface class LoanRatesRepository {
  /// Latest per-bank rates (Loan Rates screen) or BOT averages (Dashboard
  /// card). Refetched only after a release (business days 14:00 Bangkok).
  Future<Result<LoanRatesSnapshot>> getLatest(
    LoanRateKind kind, {
    bool forceRefresh = false,
  });
}

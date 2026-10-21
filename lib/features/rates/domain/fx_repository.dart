import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';

/// Single entry point for exchange rates. Merges BOT (official) and
/// Frankfurter/ECB (fallback and cross rates) behind one interface.
abstract interface class FxRepository {
  /// Latest rates for all BOT currencies.
  ///
  /// Served from cache unless a BOT release (business days 18:00 Bangkok)
  /// happened since the last fetch. If BOT fails, falls back to cached BOT
  /// data, then ECB rates, each marked with `refreshFailure`.
  /// [forceRefresh] (pull-to-refresh) skips the release check but is still
  /// throttled.
  Future<Result<RatesSnapshot>> getLatestRates({bool forceRefresh = false});

  /// Rates for [currencyCode] between [start] and [end] (inclusive dates).
  /// Monthly/quarterly/annual use the first day of each period.
  Future<Result<RateSeries>> getHistory({
    required String currencyCode,
    required Periodicity periodicity,
    required DateTime start,
    required DateTime end,
  });

  /// ECB cross rate for a pair of non-THB currencies.
  Future<Result<CrossRate>> getCrossRate({
    required String base,
    required String quote,
  });
}

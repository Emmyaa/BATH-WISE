import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/no_auto_retry.dart';
import 'package:bath_wise/features/rates/data/rates_providers.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'latest_rates_view_model.g.dart';

/// Latest rates shared by Dashboard, Rates and (later) Converter and
/// Watchlist. Kept alive so switching tabs never refetches.
@Riverpod(keepAlive: true, retry: noAutoRetry)
class LatestRatesViewModel extends _$LatestRatesViewModel {
  @override
  Future<RatesSnapshot> build() async =>
      (await ref.watch(fxRepositoryProvider).getLatestRates()).getOrThrow();

  /// Pull-to-refresh. Current data stays on screen while it runs (the
  /// RefreshIndicator shows progress). Returns the failure, if any, so the
  /// caller can show a snackbar; the repository already falls back to
  /// cached data, so an error only replaces the state when there was none.
  Future<Failure?> refresh() async {
    final result = await ref
        .read(fxRepositoryProvider)
        .getLatestRates(forceRefresh: true);
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
        return value.refreshFailure;
      case Err(:final failure):
        if (!state.hasValue) state = AsyncError(failure, StackTrace.current);
        return failure;
    }
  }

  /// Retry after a full-screen error.
  Future<void> retry() async {
    ref.invalidateSelf();
    await future.then((_) {}, onError: (_) {});
  }
}

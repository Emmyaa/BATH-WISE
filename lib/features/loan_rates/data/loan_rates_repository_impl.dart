import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/database/guard_cache.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/guard_request.dart';
import 'package:bath_wise/core/network/request_deduper.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rate_api.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_local_data_source.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rates_repository.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:bath_wise/features/market_calendar/domain/refresh_policy.dart';

class LoanRatesRepositoryImpl implements LoanRatesRepository {
  new(
    this._api,
    this._local,
    this._db,
    this._calendar,
    this._clock, {
    this.minForceRefreshInterval = const Duration(minutes: 1),
  });

  final LoanRateApi _api;
  final LoanRatesLocalDataSource _local;
  final AppDatabase _db;
  final MarketCalendarService _calendar;
  final Clock _clock;
  final Duration minForceRefreshInterval;
  final _deduper = RequestDeduper();

  /// Banks change these rates rarely, so a wide window still finds the
  /// latest period. Revisit once a real sample is available.
  static const _window = Duration(days: 31);

  /// We don't yet know whether a 14:00 release carries that day's period,
  /// so no "expected period missing" retries: refresh once per release.
  static const _policy = RefreshPolicy(
    release: ReleaseTime.loanRates,
    expectsReleaseDatePeriod: false,
  );

  static String _key(LoanRateKind kind) => 'loan_rates:${kind.name}';

  @override
  Future<Result<LoanRatesSnapshot>> getLatest(
    LoanRateKind kind, {
    bool forceRefresh = false,
  }) => _deduper.run(
    _key(kind),
    () => guardCache(() async {
      final now = _clock.now();
      final lastFetchedAt = await _db.fetchedAt(_key(kind));
      final cached = _snapshot(kind, await _local.latest(kind), lastFetchedAt);

      if (cached != null && lastFetchedAt != null) {
        final stale = forceRefresh
            ? now.difference(lastFetchedAt) >= minForceRefreshInterval
            : _policy.needsRefresh(
                now: now,
                calendar: await _calendar.calendarAround(now),
                lastFetchedAt: lastFetchedAt,
                latestCachedPeriod: cached.asOf,
              );
        if (!stale) return Ok(cached);
      }

      final today = Bangkok.dateOf(now);
      final remote = await guardRequest(
        () => _api.fetchRates(kind, start: today.subtract(_window), end: today),
      );
      switch (remote) {
        case Ok(value: final rates):
          await _local.upsert(rates);
          await _db.markFetched(_key(kind), now);
          final fresh = _snapshot(kind, await _local.latest(kind), now);
          return fresh == null
              ? const Err(NoDataFailure('BOT returned no loan rates'))
              : Ok(fresh);
        case Err(:final failure):
          return cached == null
              ? Err(failure)
              : Ok(cached.copyWith(refreshFailure: failure));
      }
    }),
  );

  static LoanRatesSnapshot? _snapshot(
    LoanRateKind kind,
    List<LoanRate> rates,
    DateTime? fetchedAt,
  ) {
    if (rates.isEmpty) return null;
    return LoanRatesSnapshot(
      kind: kind,
      asOf: rates.first.period,
      rates: rates,
      fetchedAt: fetchedAt ?? rates.first.period,
    );
  }
}

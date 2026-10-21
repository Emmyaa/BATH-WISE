import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/database/guard_cache.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/core/network/guard_request.dart';
import 'package:bath_wise/core/network/request_deduper.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:bath_wise/features/market_calendar/domain/refresh_policy.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_api.dart';
import 'package:bath_wise/features/rates/data/frankfurter_api.dart';
import 'package:bath_wise/features/rates/data/rates_local_data_source.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/fx_repository.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';

class FxRepositoryImpl implements FxRepository {
  new(
    this._bot,
    this._frankfurter,
    this._local,
    this._db,
    this._calendar,
    this._clock, {
    this.minForceRefreshInterval = const Duration(minutes: 1),
    this.crossRateTtl = const Duration(hours: 1),
  });

  final BotExchangeRateApi _bot;
  final FrankfurterApi _frankfurter;
  final RatesLocalDataSource _local;
  final AppDatabase _db;
  final MarketCalendarService _calendar;
  final Clock _clock;

  /// Pull-to-refresh can't hit BOT more often than this.
  final Duration minForceRefreshInterval;
  final Duration crossRateTtl;

  final _deduper = RequestDeduper();
  final _crossRates = <String, CrossRate>{};

  static const _latestKey = 'rates:latest:bot';
  static const _latestEcbKey = 'rates:latest:ecb';

  /// "Latest" = the last 10 days, newest period wins (long holiday runs
  /// still leave a previous day for the daily change).
  static const _latestWindow = Duration(days: 10);

  /// When the cache holds less than about a month, the same single call
  /// asks for [_historyWindow] instead, so sparklines have data. Same call
  /// count, just a bigger payload on first launch or after a long gap.
  /// 30 days back + today = 31 days, BOT's daily range limit.
  static const _historyWindow = Duration(days: 30);
  static const _sparklineSpan = Duration(days: 28);

  static const _dailyPolicy = RefreshPolicy(release: ReleaseTime.exchangeRates);
  static const _periodicPolicy = RefreshPolicy(
    release: ReleaseTime.exchangeRates,
    expectsReleaseDatePeriod: false,
  );

  // --- Latest ---------------------------------------------------------------

  @override
  Future<Result<RatesSnapshot>> getLatestRates({bool forceRefresh = false}) =>
      _deduper.run(
        _latestKey,
        () => guardCache(() async {
          final now = _clock.now();
          final lastFetchedAt = await _db.fetchedAt(_latestKey);
          final cached = _snapshot(
            await _local.recentDaily(RateSource.bot),
            RateSource.bot,
            fetchedAt: lastFetchedAt,
          );

          if (cached != null &&
              !await _latestNeedsRefresh(
                now,
                lastFetchedAt,
                cached.asOf,
                force: forceRefresh,
              )) {
            return Ok(cached);
          }

          final failure = await _refreshLatestFromBot(now, cached);
          if (failure == null) {
            final fresh = _snapshot(
              await _local.recentDaily(RateSource.bot),
              RateSource.bot,
              fetchedAt: now,
            );
            if (fresh != null) return Ok(fresh);
          }

          final reason =
              failure ?? const NoDataFailure('BOT returned no rates');
          if (cached != null) {
            return Ok(cached.copyWith(refreshFailure: reason));
          }
          return await _ecbFallback(now, reason);
        }),
      );

  Future<bool> _latestNeedsRefresh(
    DateTime now,
    DateTime? lastFetchedAt,
    DateTime asOf, {
    required bool force,
  }) async {
    if (lastFetchedAt == null) return true;
    if (force) return now.difference(lastFetchedAt) >= minForceRefreshInterval;
    return _dailyPolicy.needsRefresh(
      now: now,
      calendar: await _calendar.calendarAround(now),
      lastFetchedAt: lastFetchedAt,
      latestCachedPeriod: asOf,
    );
  }

  /// Fetches all currencies for the latest window into the cache.
  /// Returns null on success.
  Future<Failure?> _refreshLatestFromBot(
    DateTime now,
    RatesSnapshot? cached,
  ) async {
    final today = Bangkok.dateOf(now);
    final oldest = cached?.quotes.first.recent.firstOrNull?.period;
    final hasHistory =
        oldest != null && !oldest.isAfter(today.subtract(_sparklineSpan));
    final remote = await guardRequest(
      () => _bot.fetchRates(
        Periodicity.daily,
        start: today.subtract(hasHistory ? _latestWindow : _historyWindow),
        end: today,
      ),
    );
    switch (remote) {
      case Ok(value: final dtos):
        final rates = [
          for (final dto in dtos) ?dto.toEntity(Periodicity.daily),
        ];
        await _local.upsert(rates, Periodicity.daily);
        await _db.markFetched(_latestKey, now);
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  /// BOT is unavailable and nothing is cached: ECB reference rates, live or
  /// cached. The snapshot keeps [botFailure] so the UI can explain why.
  Future<Result<RatesSnapshot>> _ecbFallback(
    DateTime now,
    Failure botFailure,
  ) async {
    final today = Bangkok.dateOf(now);
    final remote = await guardRequest(
      () => _frankfurter.fetchSeries(
        base: 'THB',
        start: today.subtract(_latestWindow),
        end: today,
      ),
    );
    if (remote case Ok(value: final dto)) {
      await _local.upsert(dto.toThbRates(), Periodicity.daily);
      await _db.markFetched(_latestEcbKey, now);
    }
    final ecb = _snapshot(
      await _local.recentDaily(RateSource.ecb),
      RateSource.ecb,
      fetchedAt: await _db.fetchedAt(_latestEcbKey),
    );
    return ecb == null
        ? Err(botFailure)
        : Ok(ecb.copyWith(refreshFailure: botFailure));
  }

  RatesSnapshot? _snapshot(
    List<ExchangeRate> rates,
    RateSource source, {
    required DateTime? fetchedAt,
  }) {
    final quotes = RateQuote.fromRates(rates);
    if (quotes.isEmpty) return null;
    final asOf = quotes
        .map((q) => q.current.period)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return RatesSnapshot(
      asOf: asOf,
      source: source,
      quotes: quotes,
      fetchedAt: fetchedAt ?? asOf,
    );
  }

  // --- History --------------------------------------------------------------

  @override
  Future<Result<RateSeries>> getHistory({
    required String currencyCode,
    required Periodicity periodicity,
    required DateTime start,
    required DateTime end,
  }) {
    final from = dateOnly(start);
    final to = dateOnly(end);
    final key =
        'rates:history:${periodicity.name}:$currencyCode:'
        '${formatYmd(from)}:${formatYmd(to)}';

    return _deduper.run(
      key,
      () => guardCache(() async {
        final now = _clock.now();
        Future<List<ExchangeRate>> cached() => _local.series(
          currencyCode: currencyCode,
          periodicity: periodicity,
          source: RateSource.bot,
          start: from,
          end: to,
        );
        RateSeries series(List<ExchangeRate> points, {Failure? failure}) =>
            RateSeries(
              currencyCode: currencyCode,
              periodicity: periodicity,
              source: points.firstOrNull?.source ?? RateSource.bot,
              points: points,
              refreshFailure: failure,
            );

        final before = await cached();
        final lastFetchedAt = await _db.fetchedAt(key);
        if (before.isNotEmpty &&
            !await _historyNeedsRefresh(
              now,
              lastFetchedAt,
              periodicity,
              to,
              before.last.period,
            )) {
          return Ok(series(before));
        }

        final remote = await guardRequest(
          () => _bot.fetchRates(
            periodicity,
            start: from,
            end: to,
            currency: currencyCode,
          ),
        );
        if (remote case Ok(value: final dtos)) {
          await _local.upsert([
            for (final dto in dtos) ?dto.toEntity(periodicity),
          ], periodicity);
          await _db.markFetched(key, now);
          final after = await cached();
          return after.isEmpty
              ? const Err(NoDataFailure('No rates in range'))
              : Ok(series(after));
        }

        final failure = remote.failureOrNull!;
        if (before.isNotEmpty) return Ok(series(before, failure: failure));
        if (periodicity != Periodicity.daily) return Err(failure);

        // Daily only: ECB has no monthly/quarterly/annual averages.
        final ecb = await guardRequest(
          () => _frankfurter.fetchSeries(
            base: currencyCode,
            start: from,
            end: to,
            symbols: const ['THB'],
          ),
        );
        return switch (ecb) {
          Ok(value: final dto) when dto.toThbSeries(currencyCode).isNotEmpty =>
            Ok(series(dto.toThbSeries(currencyCode), failure: failure)),
          _ => Err(failure),
        };
      }),
    );
  }

  Future<bool> _historyNeedsRefresh(
    DateTime now,
    DateTime? lastFetchedAt,
    Periodicity periodicity,
    DateTime end,
    DateTime latestCachedPeriod,
  ) async {
    if (lastFetchedAt == null) return true;
    // A range that ended before the day it was fetched can't change.
    if (end.isBefore(Bangkok.dateOf(lastFetchedAt))) return false;
    final policy = periodicity == Periodicity.daily
        ? _dailyPolicy
        : _periodicPolicy;
    return policy.needsRefresh(
      now: now,
      calendar: await _calendar.calendarAround(now),
      lastFetchedAt: lastFetchedAt,
      latestCachedPeriod: latestCachedPeriod,
    );
  }

  // --- Cross rates ----------------------------------------------------------

  @override
  Future<Result<CrossRate>> getCrossRate({
    required String base,
    required String quote,
  }) {
    final key = '$base/$quote';
    return _deduper.run('cross:$key', () async {
      final now = _clock.now();
      final cached = _crossRates[key];
      if (cached != null && now.difference(cached.fetchedAt) < crossRateTtl) {
        return Ok(cached);
      }

      final remote = await guardRequest(
        () => _frankfurter.fetchLatest(base: base, symbols: [quote]),
      );
      switch (remote) {
        case Ok(value: final dto):
          final rate = parseDecimalOrNull(dto.rates[quote]);
          if (rate == null) {
            return cached != null
                ? Ok(cached)
                : Err(NoDataFailure('No ECB rate for $key'));
          }
          final cross = CrossRate(
            base: base,
            quote: quote,
            rate: rate,
            date: parseYmd(dto.date),
            fetchedAt: now,
          );
          _crossRates[key] = cross;
          return Ok(cross);
        case Err(:final failure):
          return cached != null ? Ok(cached) : Err(failure);
      }
    });
  }
}

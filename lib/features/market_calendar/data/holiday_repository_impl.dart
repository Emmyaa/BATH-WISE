import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/database/guard_cache.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/guard_request.dart';
import 'package:bath_wise/core/network/request_deduper.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_api.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_local_data_source.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';

/// Holidays cached per year.
///
/// - Refetched after [ttl], because Thailand sometimes declares special
///   holidays at short notice.
/// - After a failure, the network isn't retried for [failureBackoff]. Every
///   rates refresh asks for the calendar, so without this a 403 would cost
///   one extra BOT call per refresh.
class HolidayRepositoryImpl implements HolidayRepository {
  new(
    this._api,
    this._local,
    this._db,
    this._clock, {
    this.ttl = const Duration(days: 30),
    this.failureBackoff = const Duration(hours: 6),
  });

  final HolidayApi _api;
  final HolidayLocalDataSource _local;
  final AppDatabase _db;
  final Clock _clock;
  final Duration ttl;
  final Duration failureBackoff;
  final _deduper = RequestDeduper();

  static String _okKey(int year) => 'holidays:$year';
  static String _failedKey(int year) => 'holidays:$year:failed';

  @override
  Future<Result<List<Holiday>>> getHolidays(int year) => _deduper.run(
    _okKey(year),
    () => guardCache(() async {
      final now = _clock.now();
      final fetchedAt = await _db.fetchedAt(_okKey(year));
      if (fetchedAt != null && now.difference(fetchedAt) < ttl) {
        return Ok(await _local.holidaysFor(year));
      }

      final failedAt = await _db.fetchedAt(_failedKey(year));
      if (failedAt != null && now.difference(failedAt) < failureBackoff) {
        return fetchedAt != null
            ? Ok(await _local.holidaysFor(year))
            : const Err(NoDataFailure('Holidays unavailable; backing off'));
      }

      final remote = await guardRequest(() => _api.fetchHolidays(year));
      switch (remote) {
        case Ok(value: final dtos):
          final holidays = [for (final d in dtos) d.toEntity()];
          await _local.replaceYear(year, holidays);
          await _db.markFetched(_okKey(year), now);
          return Ok(holidays);
        case Err(:final failure):
          await _db.markFetched(_failedKey(year), now);
          return fetchedAt != null
              ? Ok(await _local.holidaysFor(year))
              : Err(failure);
      }
    }),
  );
}

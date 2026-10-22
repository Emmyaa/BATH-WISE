import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/env/env.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/api_endpoints.dart';
import 'package:bath_wise/core/network/dio_providers.dart';
import 'package:bath_wise/core/network/interceptors/call_budget_interceptor.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_local_data_source.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_providers.dart';
import 'package:bath_wise/features/watchlist/domain/alert_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

/// Unique name of the periodic rate-alert check. On iOS it is also the
/// BGTaskScheduler identifier, listed in Info.plist.
const alertCheckTask = 'bathwise.rateAlerts';

/// Workmanager entry point, run in a background isolate.
@pragma('vm:entry-point')
void alertWorkerDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != alertCheckTask) return true;
    await initializeDateFormatting();
    final container = ProviderContainer(overrides: alertWorkerOverrides());
    try {
      await container.read(alertCheckProvider).run();
    } on Object catch (e, s) {
      debugPrint('Rate alert check failed: $e\n$s');
    } finally {
      container.dispose();
    }
    // Always "success": a failed run would be retried with backoff,
    // spending more BOT calls. The next period checks again anyway.
    return true;
  });
}

/// Wiring that holds a run to one BOT call:
/// - the BOT client has a budget of one request and no retries;
/// - holidays come from cache only (the calendar would otherwise spend
///   the call on the holidays API).
/// ECB fallback (Frankfurter) isn't BOT and stays available.
List<Override> alertWorkerOverrides({int botCallBudget = 1}) => [
  botDioProvider.overrideWith((ref) {
    final dio = buildApiDio(
      baseUrl: BotEndpoints.baseUrl,
      authToken: () => Env.botApiToken,
      retryDelays: const [],
    );
    dio.interceptors.insert(0, CallBudgetInterceptor(botCallBudget));
    ref.onDispose(dio.close);
    return dio;
  }),
  holidayRepositoryProvider.overrideWith(
    (ref) => CachedHolidayRepository(
      HolidayLocalDataSource(ref.watch(appDatabaseProvider)),
    ),
  ),
];

/// Holidays from the local cache, never the network. An uncached year is
/// empty, so the calendar falls back to weekends only.
@visibleForTesting
class CachedHolidayRepository implements HolidayRepository {
  const new(this._local);

  final HolidayLocalDataSource _local;

  @override
  Future<Result<List<Holiday>>> getHolidays(int year) async =>
      Ok(await _local.holidaysFor(year));
}

/// Schedules [alertWorkerDispatcher] with Workmanager.
class WorkmanagerAlertScheduler implements AlertScheduler {
  Future<void>? _initialized;

  /// BOT publishes once a business day; hourly is plenty, and most runs
  /// cost no BOT call because the cache is already current.
  static const _frequency = Duration(hours: 1);

  @override
  Future<void> sync({required bool hasActiveAlerts}) async {
    final workmanager = Workmanager();
    await (_initialized ??= workmanager.initialize(alertWorkerDispatcher));
    if (!hasActiveAlerts) {
      await workmanager.cancelByUniqueName(alertCheckTask);
      return;
    }
    await workmanager.registerPeriodicTask(
      alertCheckTask,
      alertCheckTask,
      frequency: _frequency,
      // iOS ignores frequency; this is its earliest next run instead.
      initialDelay: _frequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }
}

import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/network/dio_providers.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_api.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_local_data_source.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_repository_impl.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'market_calendar_providers.g.dart';

@Riverpod(keepAlive: true)
HolidayRepository holidayRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return HolidayRepositoryImpl(
    HolidayApi(ref.watch(botDioProvider)),
    HolidayLocalDataSource(db),
    db,
    ref.watch(clockProvider),
  );
}

@Riverpod(keepAlive: true)
MarketCalendarService marketCalendarService(Ref ref) =>
    MarketCalendarService(ref.watch(holidayRepositoryProvider));

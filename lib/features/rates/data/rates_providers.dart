import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/network/dio_providers.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_api.dart';
import 'package:bath_wise/features/rates/data/frankfurter_api.dart';
import 'package:bath_wise/features/rates/data/fx_repository_impl.dart';
import 'package:bath_wise/features/rates/data/rates_local_data_source.dart';
import 'package:bath_wise/features/rates/domain/fx_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rates_providers.g.dart';

@Riverpod(keepAlive: true)
FxRepository fxRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return FxRepositoryImpl(
    BotExchangeRateApi(ref.watch(botDioProvider)),
    FrankfurterApi(ref.watch(frankfurterDioProvider)),
    RatesLocalDataSource(db),
    db,
    ref.watch(marketCalendarServiceProvider),
    ref.watch(clockProvider),
  );
}

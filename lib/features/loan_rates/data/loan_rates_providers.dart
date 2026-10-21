import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/network/dio_providers.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rate_api.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_local_data_source.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_repository_impl.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rates_repository.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'loan_rates_providers.g.dart';

@Riverpod(keepAlive: true)
LoanRatesRepository loanRatesRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return LoanRatesRepositoryImpl(
    LoanRateApi(ref.watch(botDioProvider)),
    LoanRatesLocalDataSource(db),
    db,
    ref.watch(marketCalendarServiceProvider),
    ref.watch(clockProvider),
  );
}

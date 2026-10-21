import 'package:bath_wise/core/network/no_auto_retry.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:bath_wise/features/market_calendar/domain/market_status.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'market_status_provider.g.dart';

/// Why the latest rates are for the date they are, and when the next
/// update is due. Recomputed whenever the rates change.
@Riverpod(retry: noAutoRetry)
Future<MarketStatus> marketStatus(Ref ref) async {
  final asOf = await ref.watch(
    latestRatesViewModelProvider.selectAsync((s) => s.asOf),
  );
  final now = ref.watch(clockProvider).now();
  final calendar = await ref
      .watch(marketCalendarServiceProvider)
      .calendarAround(now);
  return const ResolveMarketStatus()(now: now, asOf: asOf, calendar: calendar);
}

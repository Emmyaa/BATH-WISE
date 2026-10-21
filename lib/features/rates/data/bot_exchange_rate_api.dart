import 'package:bath_wise/core/network/api_endpoints.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_dto.dart';
import 'package:bath_wise/features/rates/data/bot_period_format.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:dio/dio.dart';

/// BOT Stat-ExchangeRate v2 (docs/api-specs/exchange-rates.json).
class BotExchangeRateApi {
  const new(this._dio);

  final Dio _dio;

  /// Omit [currency] to get every currency in one call.
  ///
  /// Daily ranges longer than BOT's 31-day limit are split into
  /// consecutive requests (one BOT call each), oldest first.
  Future<List<BotExchangeRateDto>> fetchRates(
    Periodicity periodicity, {
    required DateTime start,
    required DateTime end,
    String? currency,
  }) async {
    if (periodicity != Periodicity.daily) {
      return await _fetch(periodicity, start, end, currency);
    }
    return [
      for (final (from, to) in dailyChunks(start, end))
        ...await _fetch(periodicity, from, to, currency),
    ];
  }

  /// Splits `[start, end]` into inclusive windows of at most
  /// [BotEndpoints.maxDailyRangeDays] days.
  static List<(DateTime, DateTime)> dailyChunks(DateTime start, DateTime end) {
    const span = BotEndpoints.maxDailyRangeDays;
    final chunks = <(DateTime, DateTime)>[];
    var from = start;
    while (!from.isAfter(end)) {
      final last = DateTime.utc(from.year, from.month, from.day + span - 1);
      final to = last.isAfter(end) ? end : last;
      chunks.add((from, to));
      from = DateTime.utc(to.year, to.month, to.day + 1);
    }
    return chunks;
  }

  Future<List<BotExchangeRateDto>> _fetch(
    Periodicity periodicity,
    DateTime start,
    DateTime end,
    String? currency,
  ) async {
    final response = await _dio.get<Object?>(
      _path(periodicity),
      queryParameters: {
        'start_period': BotPeriodFormat.format(periodicity, start),
        'end_period': BotPeriodFormat.format(periodicity, end),
        'currency': ?currency,
      },
    );
    return [
      for (final row in botDataDetail(response.data))
        BotExchangeRateDto.fromJson(row),
    ];
  }

  static String _path(Periodicity periodicity) => switch (periodicity) {
    Periodicity.daily => BotEndpoints.dailyExchangeRate,
    Periodicity.monthly => BotEndpoints.monthlyExchangeRate,
    Periodicity.quarterly => BotEndpoints.quarterlyExchangeRate,
    Periodicity.annual => BotEndpoints.annualExchangeRate,
  };
}

import 'package:bath_wise/core/network/api_endpoints.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rate_dtos.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:dio/dio.dart';

/// BOT LoanRate v2 (docs/api-specs/interest-rates.json).
class LoanRateApi {
  const new(this._dio);

  final Dio _dio;

  Future<List<LoanRate>> fetchRates(
    LoanRateKind kind, {
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _dio.get<Object?>(
      switch (kind) {
        LoanRateKind.bank => BotEndpoints.loanRate,
        LoanRateKind.average => BotEndpoints.averageLoanRate,
      },
      queryParameters: {
        'start_period': formatYmd(start),
        'end_period': formatYmd(end),
      },
    );
    final rows = botDataDetail(response.data);
    return [
      for (final row in rows)
        ?switch (kind) {
          LoanRateKind.bank => BankLoanRateDto.fromJson(row).toEntity(),
          LoanRateKind.average => AverageLoanRateDto.fromJson(row).toEntity(),
        },
    ];
  }
}

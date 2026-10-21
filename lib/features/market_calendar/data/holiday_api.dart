import 'package:bath_wise/core/network/api_endpoints.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_dto.dart';
import 'package:dio/dio.dart';

/// BOT Financial Institutions' Holidays API.
class HolidayApi {
  const new(this._dio);

  final Dio _dio;

  Future<List<HolidayDto>> fetchHolidays(int year) async {
    final response = await _dio.get<Object?>(
      BotEndpoints.holidays,
      queryParameters: {'year': '$year'},
    );
    final body = response.data;
    if (body is! List) {
      throw FormatException('Expected a JSON array of holidays', body);
    }
    return [
      for (final item in body)
        HolidayDto.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }
}

import 'package:bath_wise/core/network/api_endpoints.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/rates/data/frankfurter_dtos.dart';
import 'package:dio/dio.dart';

/// Frankfurter v1: ECB reference rates, no key.
class FrankfurterApi {
  const new(this._dio);

  final Dio _dio;

  Future<FrankfurterLatestDto> fetchLatest({
    required String base,
    List<String>? symbols,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FrankfurterEndpoints.latest,
      queryParameters: {'base': base, 'symbols': ?symbols?.join(',')},
    );
    return FrankfurterLatestDto.fromJson(_body(response));
  }

  Future<FrankfurterSeriesDto> fetchSeries({
    required String base,
    required DateTime start,
    required DateTime end,
    List<String>? symbols,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      FrankfurterEndpoints.timeSeries(formatYmd(start), formatYmd(end)),
      queryParameters: {'base': base, 'symbols': ?symbols?.join(',')},
    );
    return FrankfurterSeriesDto.fromJson(_body(response));
  }

  static Map<String, dynamic> _body(Response<Map<String, dynamic>> r) =>
      r.data ?? (throw const FormatException('Empty Frankfurter response'));
}

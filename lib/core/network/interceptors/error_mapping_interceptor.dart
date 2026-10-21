import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/network/failure_mapper.dart';
import 'package:dio/dio.dart';

/// Attaches a typed [Failure] as [DioException.error] so callers can read
/// it without knowing Dio's error types (see `guardRequest`).
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is Failure) return handler.next(err);
    handler.next(err.copyWith(error: failureFromDioException(err)));
  }
}

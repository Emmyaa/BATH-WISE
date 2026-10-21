import 'dart:io';

import 'package:bath_wise/core/error/failure.dart';
import 'package:dio/dio.dart';

/// Maps a [DioException] to a typed [Failure].
///
/// BOT's gateway answers both a bad token and an API the token isn't
/// subscribed to with `403 {"error": "Access to this API has been
/// disallowed"}` (see docs/api-samples/error_unauthorized.json).
Failure failureFromDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return NetworkFailure(e.type.name);
    case DioExceptionType.cancel:
      return const UnexpectedFailure('Request cancelled');
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.unknown:
      return e.error is SocketException
          ? NetworkFailure(e.error.toString())
          : UnexpectedFailure(e.message ?? e.error?.toString());
  }
}

Failure _fromResponse(Response<dynamic>? response) {
  final status = response?.statusCode;
  final message = _errorMessage(response?.data) ?? 'HTTP $status';
  return switch (status) {
    401 || 403 => UnauthorizedFailure(message),
    429 => RateLimitFailure(
      retryAfter: _retryAfter(response?.headers.value('retry-after')),
      message: message,
    ),
    404 => NoDataFailure(message),
    _ => ServerFailure(statusCode: status, message: message),
  };
}

String? _errorMessage(Object? body) => switch (body) {
  {'error': final String error} => error,
  // Gateway validation errors (docs/api-samples/error_range_limit.json).
  {'moreInformation': [{'message': final String message}, ...]} => message,
  {'message': final String message} => message,
  {'moreInformation': final String info} => info,
  _ => null,
};

Duration? _retryAfter(String? header) {
  final seconds = int.tryParse(header ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}

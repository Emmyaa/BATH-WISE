import 'package:dio/dio.dart';

/// Retries transient failures (timeouts, connection errors, 502/503/504)
/// with backoff.
///
/// Never retries 4xx: a 403 won't fix itself and a 429 retry would burn
/// more of BOT's 200 calls/hour. Must be added *before* the error mapping
/// interceptor so it sees raw errors.
class RetryInterceptor extends Interceptor {
  new({
    required this._dio,
    this.delays = const [Duration(milliseconds: 500), Duration(seconds: 2)],
  });

  final Dio _dio;

  /// One entry per retry; its length is the max retry count.
  final List<Duration> delays;

  static const _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= delays.length || !_isTransient(err)) {
      return handler.next(err);
    }

    await Future<void>.delayed(delays[attempt]);
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static bool _isTransient(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => const {
      502,
      503,
      504,
    }.contains(e.response?.statusCode),
    _ => false,
  };
}

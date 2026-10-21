import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Logs one line per request: method, URL, status, duration and size.
///
/// Header values in [redactedHeaders] are masked and bodies are never
/// logged, so tokens can't leak into logs. Add it in debug builds only.
class RedactingLogInterceptor extends Interceptor {
  new({
    void Function(String message)? log,
    this.redactedHeaders = const {'authorization'},
  }) : _log = log ?? ((m) => developer.log(m, name: 'http'));

  final void Function(String message) _log;
  final Set<String> redactedHeaders;

  static const _startKey = 'log_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    _log('→ ${options.method} ${options.uri} ${_headers(options.headers)}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final size = response.headers.value(Headers.contentLengthHeader) ?? '?';
    _log(
      '← ${response.statusCode} ${response.requestOptions.uri} '
      '${_elapsed(response.requestOptions)} ($size bytes)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      '✕ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri} ${_elapsed(err.requestOptions)}',
    );
    handler.next(err);
  }

  String _headers(Map<String, dynamic> headers) {
    final masked = {
      for (final MapEntry(:key, :value) in headers.entries)
        key: redactedHeaders.contains(key.toLowerCase()) ? '***' : value,
    };
    return masked.toString();
  }

  String _elapsed(RequestOptions options) {
    final start = options.extra[_startKey];
    return start is DateTime
        ? '${DateTime.now().difference(start).inMilliseconds}ms'
        : '';
  }
}

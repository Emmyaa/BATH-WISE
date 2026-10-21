import 'dart:io';

import 'package:dio/dio.dart';

/// Adds `Authorization: <token>` (no scheme prefix, per the BOT specs).
/// Registered on the BOT client only, so the token never reaches other
/// hosts.
class BotAuthInterceptor extends Interceptor {
  new(this._token);

  /// Read lazily so tests can supply a fake token.
  final String Function() _token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[HttpHeaders.authorizationHeader] = _token();
    handler.next(options);
  }
}

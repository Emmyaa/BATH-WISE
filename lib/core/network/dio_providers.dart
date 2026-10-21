import 'package:bath_wise/core/env/env.dart';
import 'package:bath_wise/core/network/api_endpoints.dart';
import 'package:bath_wise/core/network/interceptors/bot_auth_interceptor.dart';
import 'package:bath_wise/core/network/interceptors/error_mapping_interceptor.dart';
import 'package:bath_wise/core/network/interceptors/redacting_log_interceptor.dart';
import 'package:bath_wise/core/network/interceptors/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio_providers.g.dart';

/// Client for all BOT gateway APIs; the only one carrying the token.
@Riverpod(keepAlive: true)
Dio botDio(Ref ref) {
  final dio = buildApiDio(
    baseUrl: BotEndpoints.baseUrl,
    authToken: () => Env.botApiToken,
  );
  ref.onDispose(dio.close);
  return dio;
}

/// Client for Frankfurter (ECB reference rates, no key).
@Riverpod(keepAlive: true)
Dio frankfurterDio(Ref ref) {
  final dio = buildApiDio(baseUrl: FrankfurterEndpoints.baseUrl);
  ref.onDispose(dio.close);
  return dio;
}

/// Builds a client with the app's interceptor chain. Public for tests.
///
/// Order matters: auth → log → retry (sees raw errors) → error mapping
/// (runs once, after retries are exhausted).
Dio buildApiDio({
  required String baseUrl,
  String Function()? authToken,
  bool log = kDebugMode,
  void Function(String message)? logSink,
  List<Duration>? retryDelays,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  dio.interceptors.addAll([
    if (authToken != null) BotAuthInterceptor(authToken),
    if (log) RedactingLogInterceptor(log: logSink),
    if (retryDelays != null)
      RetryInterceptor(dio: dio, delays: retryDelays)
    else
      RetryInterceptor(dio: dio),
    ErrorMappingInterceptor(),
  ]);
  return dio;
}

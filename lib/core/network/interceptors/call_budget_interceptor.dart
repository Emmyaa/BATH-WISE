import 'package:bath_wise/core/error/failure.dart';
import 'package:dio/dio.dart';

/// Lets a client send at most [maxCalls] requests; later ones fail fast
/// with a [RateLimitFailure] without touching the network.
///
/// The rate-alert worker uses it to guarantee one BOT call per run, so
/// background checks can never eat into the 200 calls/hour quota.
/// Add it first in the chain so retries count against the budget too.
class CallBudgetInterceptor extends Interceptor {
  new(this.maxCalls);

  final int maxCalls;
  int _used = 0;

  int get used => _used;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_used >= maxCalls) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: RateLimitFailure(
            message: 'Call budget of $maxCalls exhausted: ${options.path}',
          ),
        ),
      );
    }
    _used++;
    handler.next(options);
  }
}

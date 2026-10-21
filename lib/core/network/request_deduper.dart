import 'dart:async';

/// Collapses concurrent calls with the same key into one in-flight future.
///
/// When the dashboard, rates list and watchlist all ask for the latest
/// rates at startup, BOT gets one request, not three.
class RequestDeduper {
  final _inFlight = <String, Future<Object?>>{};

  Future<T> run<T>(String key, Future<T> Function() task) {
    final existing = _inFlight[key];
    if (existing != null) return existing as Future<T>;

    // `remove` returns this very future: returning it from the callback
    // would make whenComplete wait on itself forever, so discard it.
    final future = task().whenComplete(() {
      unawaited(_inFlight.remove(key));
    });
    _inFlight[key] = future;
    return future;
  }
}

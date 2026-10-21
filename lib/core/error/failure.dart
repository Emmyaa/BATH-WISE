/// Typed, UI-safe errors. Data sources map raw exceptions (DioException,
/// FormatException, …) to one of these; nothing else reaches the UI.
///
/// Implements [Exception] so a ViewModel can throw it into an `AsyncError`
/// and the UI can switch on the concrete type.
sealed class Failure implements Exception {
  const new([this.message]);

  /// Developer-facing detail for logs. Never shown to the user as is.
  final String? message;

  // Explicit names: runtimeType.toString() is unreliable under obfuscation.
  String get _name => switch (this) {
    NetworkFailure() => 'NetworkFailure',
    UnauthorizedFailure() => 'UnauthorizedFailure',
    RateLimitFailure() => 'RateLimitFailure',
    NoDataFailure() => 'NoDataFailure',
    ServerFailure() => 'ServerFailure',
    ParsingFailure() => 'ParsingFailure',
    CacheFailure() => 'CacheFailure',
    UnexpectedFailure() => 'UnexpectedFailure',
  };

  @override
  String toString() => message == null ? _name : '$_name: $message';
}

/// No connectivity, DNS failure or timeout.
final class NetworkFailure extends Failure {
  const new([super.message]);
}

/// 401/403: token missing, invalid or not subscribed to this API.
final class UnauthorizedFailure extends Failure {
  const new([super.message]);
}

/// 429: BOT allows 200 calls/hour per credential.
final class RateLimitFailure extends Failure {
  const new({this.retryAfter, String? message}) : super(message);

  final Duration? retryAfter;
}

/// The request succeeded but there is nothing to show (e.g. a holiday or a
/// range before the first release).
final class NoDataFailure extends Failure {
  const new([super.message]);
}

/// Other non-2xx responses.
final class ServerFailure extends Failure {
  const new({this.statusCode, String? message}) : super(message);

  final int? statusCode;
}

/// The response didn't match the expected shape.
final class ParsingFailure extends Failure {
  const new([super.message]);
}

/// Local database read/write failed.
final class CacheFailure extends Failure {
  const new([super.message]);
}

/// Anything not mapped above.
final class UnexpectedFailure extends Failure {
  const new([super.message]);
}

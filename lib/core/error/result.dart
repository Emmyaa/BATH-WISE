import 'package:bath_wise/core/error/failure.dart';
import 'package:flutter/foundation.dart';

/// Outcome of a repository or use case call: [Ok] with a value, or [Err]
/// with a typed [Failure]. Pattern-match with `switch`.
@immutable
sealed class Result<T> {
  const new();

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final failure) => Err(failure),
  };

  /// Returns the value or throws the [Failure], for use inside an
  /// AsyncNotifier where a thrown error becomes `AsyncError`.
  T getOrThrow() => switch (this) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}

final class Ok<T> extends Result<T> {
  const new(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const new(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}

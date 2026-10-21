import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const failure = NetworkFailure('timeout');

  group('Result', () {
    test('Ok exposes its value', () {
      const Result<int> result = Ok(42);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
      expect(result.getOrThrow(), 42);
    });

    test('Err exposes its failure', () {
      const Result<int> result = Err(failure);

      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('getOrThrow throws the typed failure', () {
      const Result<int> result = Err(failure);

      expect(result.getOrThrow, throwsA(isA<NetworkFailure>()));
    });

    test('fold picks the matching branch', () {
      const Result<int> ok = Ok(2);
      const Result<int> err = Err(failure);

      expect(ok.fold((v) => 'ok $v', (f) => 'err'), 'ok 2');
      expect(err.fold((v) => 'ok', (f) => 'err ${f.message}'), 'err timeout');
    });

    test('map transforms Ok and passes Err through', () {
      const Result<int> ok = Ok(2);
      const Result<int> err = Err(failure);

      expect(ok.map((v) => v * 10), const Ok(20));
      expect(err.map((v) => v * 10), const Err<int>(failure));
    });

    test('equality is by value', () {
      expect(const Ok(1), const Ok(1));
      expect(const Ok(1), isNot(const Ok(2)));
      expect(const Err<int>(failure), const Err<int>(failure));
    });
  });

  group('Failure', () {
    test('toString includes the type name and message', () {
      expect(
        const RateLimitFailure(message: '429').toString(),
        'RateLimitFailure: 429',
      );
      expect(const NoDataFailure().toString(), 'NoDataFailure');
    });
  });
}

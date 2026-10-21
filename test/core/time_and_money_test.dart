import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bangkok', () {
    test('dateOf crosses midnight at UTC+7', () {
      // 17:30 UTC on Oct 19 is 00:30 on Oct 20 in Bangkok.
      expect(
        Bangkok.dateOf(DateTime.utc(2026, 10, 19, 17, 30)),
        DateTime.utc(2026, 10, 20),
      );
      expect(
        Bangkok.dateOf(DateTime.utc(2026, 10, 19, 16, 59)),
        DateTime.utc(2026, 10, 19),
      );
    });

    test('instantAt converts Bangkok wall time to a UTC instant', () {
      expect(
        Bangkok.instantAt(DateTime.utc(2026, 10, 20), hour: 18),
        DateTime.utc(2026, 10, 20, 11),
      );
    });

    test('formatYmd / parseYmd round-trip', () {
      expect(formatYmd(DateTime.utc(2026, 1, 5)), '2026-01-05');
      expect(parseYmd(' 2026-01-05 '), DateTime.utc(2026, 1, 5));
      expect(() => parseYmd('2026/01/05'), throwsFormatException);
    });
  });

  group('parseDecimalOrNull', () {
    test('parses BOT strings exactly', () {
      expect(parseDecimalOrNull('33.4859000'), Decimal.parse('33.4859'));
    });

    test('empty, blank and null become null', () {
      expect(parseDecimalOrNull(''), isNull);
      expect(parseDecimalOrNull('  '), isNull);
      expect(parseDecimalOrNull(null), isNull);
    });

    test('JSON numbers keep their shortest decimal form', () {
      expect(parseDecimalOrNull(0.0298), Decimal.parse('0.0298'));
      expect(parseDecimalOrNull(537.71), Decimal.parse('537.71'));
    });

    test('rejects other types', () {
      expect(() => parseDecimalOrNull(true), throwsFormatException);
    });
  });

  test('dividedBy rounds non-terminating results', () {
    expect(
      Decimal.one.dividedBy(Decimal.fromInt(3), scale: 4),
      Decimal.parse('0.3333'),
    );
  });
}

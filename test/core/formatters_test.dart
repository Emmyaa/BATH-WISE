import 'package:bath_wise/core/money/formatters.dart';
import 'package:bath_wise/core/time/date_formatters.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/test_helpers.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('th');
  });

  group('DecimalFormatter', () {
    final en = DecimalFormatter('en');

    test('fixed digits with grouping', () {
      expect(en.format(d('33.4859')), '33.4859');
      expect(en.format(d('1234567.5'), digits: 2), '1,234,567.50');
      expect(en.format(d('0.5307')), '0.5307');
    });

    test('rounds half away from zero', () {
      expect(en.format(d('1.23455')), '1.2346');
      expect(en.format(d('-1.23455')), '−1.2346');
    });

    test('signed adds + to positives only', () {
      expect(en.format(d('0.0992'), signed: true), '+0.0992');
      expect(en.format(Decimal.zero, signed: true), '0.0000');
      expect(en.format(d('-0.1'), digits: 2, signed: true), '−0.10');
    });

    test('percent', () {
      expect(en.percent(d('0.2512')), '+0.25%');
      expect(en.percent(d('-1.5')), '−1.50%');
    });

    test('formatTyped groups keypad input and keeps it as typed', () {
      expect(en.formatTyped(''), '0');
      expect(en.formatTyped('1234567'), '1,234,567');
      expect(en.formatTyped('1234.'), '1,234.');
      expect(en.formatTyped('0.50'), '0.50');
    });

    test('Thai uses the same separators', () {
      expect(DecimalFormatter('th').format(d('1234.5'), digits: 2), '1,234.50');
    });
  });

  group('DateFormatters', () {
    final date = DateTime.utc(2026, 10, 19);

    test('English date', () {
      expect(DateFormatters('en').date(date), 'Oct 19, 2026');
    });

    test('Thai date uses the Buddhist era', () {
      expect(DateFormatters('th').date(date), '19 ต.ค. 2569');
    });

    test('Bangkok time regardless of device zone', () {
      expect(DateFormatters('en').bangkokTime(bkk(2026, 10, 20, 18)), '18:00');
    });

    test('weekday', () {
      expect(DateFormatters('en').weekday(DateTime.utc(2026, 10, 26)), 'Mon');
    });
  });
}

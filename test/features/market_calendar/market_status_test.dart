import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';
import 'package:bath_wise/features/market_calendar/domain/market_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final rama9 = Holiday(
    date: DateTime.utc(2026, 10, 13),
    nameEn: 'Rama IX Memorial Day',
    nameTh: 'วันนวมินทรมหาราช',
  );
  final chula = Holiday(
    date: DateTime.utc(2026, 10, 23),
    nameEn: 'Chulalongkorn Day',
    nameTh: 'วันปิยมหาราช',
  );
  final calendar = MarketCalendar([rama9, chula]);
  const resolve = ResolveMarketStatus();

  MarketStatus at(DateTime now, DateTime asOf) =>
      resolve(now: now, asOf: asOf, calendar: calendar);

  test('data for today → up to date', () {
    final status = at(bkk(2026, 10, 20, 19), DateTime.utc(2026, 10, 20));
    expect(status.kind, MarketStatusKind.upToDate);
  });

  test("business day before 18:00 → awaiting today's release", () {
    final status = at(bkk(2026, 10, 20, 9), DateTime.utc(2026, 10, 19));
    expect(status.kind, MarketStatusKind.awaitingRelease);
    expect(status.nextRelease, bkk(2026, 10, 20, 18));
  });

  test('weekend → next update Monday', () {
    final status = at(bkk(2026, 10, 17, 12), DateTime.utc(2026, 10, 16));
    expect(status.kind, MarketStatusKind.weekend);
    expect(status.nextRelease, bkk(2026, 10, 19, 18));
  });

  test('holiday today names it and skips to the next business day', () {
    final status = at(bkk(2026, 10, 23, 10), DateTime.utc(2026, 10, 22));
    expect(status.kind, MarketStatusKind.holiday);
    expect(status.holiday, chula);
    expect(status.nextRelease, bkk(2026, 10, 26, 18));
  });

  test('morning after a holiday still explains the gap', () {
    // Wed 14 09:00: shown data is Mon 12 because Tue 13 was a holiday.
    final status = at(bkk(2026, 10, 14, 9), DateTime.utc(2026, 10, 12));
    expect(status.kind, MarketStatusKind.holiday);
    expect(status.holiday, rama9);
  });

  test('release time passed without new data → delayed', () {
    final status = at(bkk(2026, 10, 20, 19), DateTime.utc(2026, 10, 19));
    expect(status.kind, MarketStatusKind.delayed);
    expect(status.nextRelease, bkk(2026, 10, 21, 18));
  });
}

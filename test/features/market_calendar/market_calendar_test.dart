import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';
import 'package:bath_wise/features/market_calendar/domain/refresh_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  // October 2026: Tue 13 and Fri 23 are holidays.
  final calendar = MarketCalendar([
    Holiday(date: DateTime.utc(2025, 12, 31), nameEn: 'NYE', nameTh: ''),
    Holiday(date: DateTime.utc(2026), nameEn: 'New Year', nameTh: ''),
    Holiday(date: DateTime.utc(2026, 10, 13), nameEn: 'Rama IX', nameTh: ''),
    Holiday(date: DateTime.utc(2026, 10, 23), nameEn: 'Chula', nameTh: ''),
  ]);
  const fx = ReleaseTime.exchangeRates;

  group('latestRelease (18:00 exchange rates)', () {
    test('before 18:00 on a business day → previous business day', () {
      expect(
        calendar.latestRelease(bkk(2026, 10, 20, 15, 42), fx),
        bkk(2026, 10, 19, 18),
      );
    });

    test('at exactly 18:00 → today', () {
      expect(
        calendar.latestRelease(bkk(2026, 10, 20, 18), fx),
        bkk(2026, 10, 20, 18),
      );
    });

    test('weekend → Friday', () {
      expect(
        calendar.latestRelease(bkk(2026, 10, 17, 12), fx),
        bkk(2026, 10, 16, 18),
      );
      expect(
        calendar.latestRelease(bkk(2026, 10, 19, 9), fx),
        bkk(2026, 10, 16, 18),
      );
    });

    test('skips a holiday', () {
      // Wed 14 morning: Tue 13 is a holiday, so Mon 12.
      expect(
        calendar.latestRelease(bkk(2026, 10, 14, 9), fx),
        bkk(2026, 10, 12, 18),
      );
      // Evening of the holiday itself: still Mon 12.
      expect(
        calendar.latestRelease(bkk(2026, 10, 13, 20), fx),
        bkk(2026, 10, 12, 18),
      );
    });

    test('long weekend: holiday Friday + weekend → Thursday', () {
      expect(
        calendar.latestRelease(bkk(2026, 10, 26, 8), fx),
        bkk(2026, 10, 22, 18),
      );
    });

    test('crosses New Year and consecutive holidays', () {
      // Thu Jan 1 and Wed Dec 31 are holidays → Tue Dec 30.
      expect(
        calendar.latestRelease(bkk(2026, 1, 1, 10), fx),
        bkk(2025, 12, 30, 18),
      );
    });

    test('uses Bangkok, not UTC, dates', () {
      // 00:30 Tue Oct 20 in Bangkok is still Mon Oct 19 in UTC.
      final now = bkk(2026, 10, 20, 0, 30);
      expect(now.day, 19);
      expect(calendar.latestRelease(now, fx), bkk(2026, 10, 19, 18));
    });

    test('loan rates release at 14:00', () {
      expect(
        calendar.latestRelease(bkk(2026, 10, 20, 15), ReleaseTime.loanRates),
        bkk(2026, 10, 20, 14),
      );
    });
  });

  group('nextRelease', () {
    test('later today on a business day', () {
      expect(
        calendar.nextRelease(bkk(2026, 10, 20, 15, 42), fx),
        bkk(2026, 10, 20, 18),
      );
    });

    test('after a Friday release → Monday', () {
      expect(
        calendar.nextRelease(bkk(2026, 10, 16, 19), fx),
        bkk(2026, 10, 19, 18),
      );
    });

    test('on a holiday → next business day', () {
      expect(
        calendar.nextRelease(bkk(2026, 10, 13, 9), fx),
        bkk(2026, 10, 14, 18),
      );
    });
  });

  test('holidayOn and isBusinessDay', () {
    expect(calendar.holidayOn(DateTime.utc(2026, 10, 13))?.nameEn, 'Rama IX');
    expect(calendar.isBusinessDay(DateTime.utc(2026, 10, 13)), isFalse);
    expect(calendar.isBusinessDay(DateTime.utc(2026, 10, 17)), isFalse);
    expect(calendar.isBusinessDay(DateTime.utc(2026, 10, 19)), isTrue);
  });

  test('without holiday data only weekends are closed', () {
    final weekendsOnly = MarketCalendar();
    expect(weekendsOnly.hasHolidayData, isFalse);
    expect(
      weekendsOnly.latestRelease(bkk(2026, 10, 14, 9), fx),
      bkk(2026, 10, 13, 18),
    );
  });

  group('RefreshPolicy', () {
    const policy = RefreshPolicy(release: ReleaseTime.exchangeRates);
    final now = bkk(2026, 10, 20, 19); // after today's release

    bool needs({DateTime? fetchedAt, DateTime? period}) => policy.needsRefresh(
      now: now,
      calendar: calendar,
      lastFetchedAt: fetchedAt,
      latestCachedPeriod: period,
    );

    test('never fetched → refresh', () {
      expect(needs(), isTrue);
    });

    test('fetched before the latest release → refresh', () {
      expect(
        needs(
          fetchedAt: bkk(2026, 10, 20, 17, 59),
          period: DateTime.utc(2026, 10, 20),
        ),
        isTrue,
      );
    });

    test('fetched after the release with the expected period → fresh', () {
      expect(
        needs(
          fetchedAt: bkk(2026, 10, 20, 18, 5),
          period: DateTime.utc(2026, 10, 20),
        ),
        isFalse,
      );
    });

    test('expected period missing → retry only after the interval', () {
      final yesterday = DateTime.utc(2026, 10, 19);
      expect(
        needs(fetchedAt: bkk(2026, 10, 20, 18, 45), period: yesterday),
        isFalse,
        reason: '15 min since last try',
      );
      expect(
        needs(fetchedAt: bkk(2026, 10, 20, 18, 30), period: yesterday),
        isTrue,
        reason: '30 min since last try',
      );
    });

    test('without the release-date expectation, never retries', () {
      const loose = RefreshPolicy(
        release: ReleaseTime.exchangeRates,
        expectsReleaseDatePeriod: false,
      );
      expect(
        loose.needsRefresh(
          now: now,
          calendar: calendar,
          lastFetchedAt: bkk(2026, 10, 20, 18, 1),
          latestCachedPeriod: DateTime.utc(2026, 10),
        ),
        isFalse,
      );
    });
  });
}

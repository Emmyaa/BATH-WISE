import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_api.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_dto.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_local_data_source.dart';
import 'package:bath_wise/features/market_calendar/data/holiday_repository_impl.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_helpers.dart';

class MockHolidayApi extends Mock implements HolidayApi;

class MockHolidayRepository extends Mock implements HolidayRepository;

void main() {
  final dtos = [
    for (final item in loadFixture('holidays_2026_spec_shape.json')! as List)
      HolidayDto.fromJson(item as Map<String, dynamic>),
  ];

  test('HolidayDto maps the spec shape and trims names', () {
    final holiday = dtos.first.toEntity();
    expect(holiday.date, DateTime.utc(2026));
    expect(holiday.nameEn, "New Year's Day");
    expect(holiday.nameTh, 'วันขึ้นปีใหม่');
  });

  group('HolidayRepositoryImpl', () {
    late AppDatabase db;
    late MockHolidayApi api;
    late FakeClock clock;
    late HolidayRepositoryImpl repo;

    setUp(() {
      db = inMemoryDatabase();
      api = MockHolidayApi();
      clock = FakeClock(bkk(2026, 10, 20, 9));
      repo = HolidayRepositoryImpl(api, HolidayLocalDataSource(db), db, clock);
    });
    tearDown(() => db.close());

    test('fetches once, then serves the year from cache', () async {
      when(() => api.fetchHolidays(2026)).thenAnswer((_) async => dtos);

      final first = await repo.getHolidays(2026);
      final second = await repo.getHolidays(2026);

      expect(first.valueOrNull, hasLength(3));
      expect(second.valueOrNull?.map((h) => h.nameEn), [
        "New Year's Day",
        'H.M. King Bhumibol Adulyadej The Great Memorial Day',
        'Chulalongkorn Day',
      ]);
      verify(() => api.fetchHolidays(2026)).called(1);
    });

    test('refetches after the TTL', () async {
      when(() => api.fetchHolidays(2026)).thenAnswer((_) async => dtos);

      await repo.getHolidays(2026);
      clock.advance(const Duration(days: 31));
      await repo.getHolidays(2026);

      verify(() => api.fetchHolidays(2026)).called(2);
    });

    test('backs off after a failure instead of retrying every call', () async {
      when(() => api.fetchHolidays(2026))
          .thenThrow(const UnauthorizedFailure('403'));

      final first = await repo.getHolidays(2026);
      final second = await repo.getHolidays(2026);

      expect(first.failureOrNull, isA<UnauthorizedFailure>());
      expect(second.failureOrNull, isA<NoDataFailure>());
      verify(() => api.fetchHolidays(2026)).called(1);

      clock.advance(const Duration(hours: 7));
      await repo.getHolidays(2026);
      verify(() => api.fetchHolidays(2026)).called(1);
    });

    test('serves stale cache when the refresh fails', () async {
      when(() => api.fetchHolidays(2026)).thenAnswer((_) async => dtos);
      await repo.getHolidays(2026);

      clock.advance(const Duration(days: 31));
      when(() => api.fetchHolidays(2026))
          .thenThrow(const NetworkFailure('offline'));

      expect((await repo.getHolidays(2026)).valueOrNull, hasLength(3));
    });
  });

  group('MarketCalendarService', () {
    late MockHolidayRepository repo;

    setUp(() {
      repo = MockHolidayRepository();
      when(() => repo.getHolidays(any()))
          .thenAnswer((_) async => const Err(NetworkFailure()));
    });

    test('loads the previous year in January', () async {
      when(() => repo.getHolidays(2025)).thenAnswer(
        (_) async => Ok([
          Holiday(date: DateTime.utc(2025, 12, 31), nameEn: 'NYE', nameTh: ''),
        ]),
      );

      final calendar = await MarketCalendarService(repo)
          .calendarAround(bkk(2026, 1, 2, 9));

      expect(calendar.holidayOn(DateTime.utc(2025, 12, 31)), isNotNull);
      verify(() => repo.getHolidays(2025)).called(1);
      verify(() => repo.getHolidays(2026)).called(1);
    });

    test('a failed year degrades to weekends-only', () async {
      final calendar = await MarketCalendarService(repo)
          .calendarAround(bkk(2026, 10, 20, 9));

      expect(calendar.hasHolidayData, isFalse);
      verify(() => repo.getHolidays(2026)).called(1);
      verifyNever(() => repo.getHolidays(2025));
    });
  });
}

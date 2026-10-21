import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:json_annotation/json_annotation.dart';

part 'holiday_dto.g.dart';

/// One item of the holidays API's top-level array (PascalCase fields).
/// Shape per docs/api-specs/holidays.json; no real sample yet.
@JsonSerializable(fieldRename: FieldRename.pascal)
class HolidayDto {
  const new({
    required this.date,
    this.holidayWeekDay,
    this.holidayWeekDayThai,
    this.dateThai,
    this.holidayDescription,
    this.holidayDescriptionThai,
  });

  factory fromJson(Map<String, dynamic> json) => _$HolidayDtoFromJson(json);

  /// `YYYY-MM-DD`.
  final String date;
  final String? holidayWeekDay;
  final String? holidayWeekDayThai;

  /// `DD/MM/YYYY` in the Buddhist era. Unused: [date] is unambiguous.
  final String? dateThai;
  final String? holidayDescription;
  final String? holidayDescriptionThai;

  Holiday toEntity() => Holiday(
    date: parseYmd(date),
    nameEn: holidayDescription?.trim() ?? '',
    nameTh: holidayDescriptionThai?.trim() ?? '',
  );
}

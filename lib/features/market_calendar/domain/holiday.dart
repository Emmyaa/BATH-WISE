import 'package:freezed_annotation/freezed_annotation.dart';

part 'holiday.freezed.dart';

/// A financial-institution holiday announced by BOT.
@freezed
abstract class Holiday with _$Holiday {
  const factory({
    /// Calendar date (`DateTime.utc(y, m, d)`).
    required DateTime date,
    required String nameEn,
    required String nameTh,
  }) = _Holiday;
}

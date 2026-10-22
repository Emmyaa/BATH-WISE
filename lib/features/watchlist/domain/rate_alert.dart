import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rate_alert.freezed.dart';

/// Which side of the target fires the alert.
enum AlertDirection {
  /// Fires when the rate is at or above the target.
  above,

  /// Fires when the rate is at or below the target.
  below,
}

/// "Tell me when USD selling reaches 33.00 baht."
///
/// One-shot: once triggered it is disabled and remembers what triggered
/// it, until the user re-arms it. Targets are in THB per the currency's
/// published unit (per 100 JPY, like the rest of the app).
@freezed
abstract class RateAlert with _$RateAlert {
  const factory({
    required int id,
    required String currencyCode,
    required AlertDirection direction,
    required Decimal target,
    required RateType rateType,
    required DateTime createdAt,
    @Default(true) bool enabled,
    DateTime? triggeredAt,
    Decimal? triggeredRate,

    /// BOT period of the rate that triggered the alert.
    DateTime? triggeredPeriod,
  }) = _RateAlert;

  const new _();

  bool get isTriggered => triggeredAt != null;

  bool isMetBy(Decimal value) => switch (direction) {
    AlertDirection.above => value >= target,
    AlertDirection.below => value <= target,
  };
}

/// What the user fills in; the repository assigns id and timestamps.
typedef NewRateAlert = ({
  String currencyCode,
  AlertDirection direction,
  Decimal target,
  RateType rateType,
});

/// An alert whose condition was met by `rate` for `period`.
typedef AlertTrigger = ({RateAlert alert, Decimal rate, DateTime period});

/// The direction that makes reaching [target] a future event, given the
/// [current] rate: above it means "rises to", below "falls to". Null when
/// they're equal, which would trigger at once.
AlertDirection? alertDirectionFor({
  required Decimal current,
  required Decimal target,
}) => switch (target.compareTo(current)) {
  > 0 => AlertDirection.above,
  < 0 => AlertDirection.below,
  _ => null,
};

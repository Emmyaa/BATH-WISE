import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:decimal/decimal.dart';

/// Baht price of a currency as quoted: `thb` baht per `unit` units.
typedef ThbPrice = ({Decimal thb, int unit});

/// "`unit` base = `rate` quote", e.g. 100 JPY = 21.1859 THB.
typedef ConversionRate = ({int unit, Decimal rate});

/// Converts between THB and the snapshot's currencies, and between two
/// foreign currencies through THB, since BOT only publishes THB rates.
///
/// Both legs of a cross conversion use the same [rateType], so a
/// USD → EUR conversion stays consistent with the rates shown elsewhere.
class CurrencyConverter {
  const new(this.snapshot, this.rateType);

  final RatesSnapshot snapshot;
  final RateType rateType;

  /// Null when [code] has no positive rate of [rateType] in the snapshot.
  ThbPrice? priceOf(String code) {
    if (code == Currencies.thb.code) return (thb: Decimal.one, unit: 1);
    final rate = snapshot.quoteFor(code)?.current;
    final value = rate?.valueOf(rateType);
    if (rate == null || value == null || value <= Decimal.zero) return null;
    return (thb: value, unit: rate.unit);
  }

  /// [amount] of [from] expressed in [to], or null if a rate is missing.
  /// Unrounded beyond [kDivisionScale]; round only for display.
  Decimal? convert(Decimal amount, {required String from, required String to}) {
    if (from == to) return amount;
    final source = priceOf(from);
    final target = priceOf(to);
    if (source == null || target == null) return null;
    // amount × (source.thb / source.unit) ÷ (target.thb / target.unit),
    // rearranged so there is a single, final division.
    return (amount * source.thb * Decimal.fromInt(target.unit)).dividedBy(
      Decimal.fromInt(source.unit) * target.thb,
    );
  }

  /// The rate to show as "rate used", per [from]'s quotation unit so tiny
  /// rates stay readable (1,000 IDR = 1.8653 THB rather than 0.0019).
  ConversionRate? rateFor({required String from, required String to}) {
    final unit = priceOf(from)?.unit ?? 1;
    final rate = convert(Decimal.fromInt(unit), from: from, to: to);
    return rate == null ? null : (unit: unit, rate: rate);
  }
}

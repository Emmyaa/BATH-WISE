import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Parses an API number into a [Decimal].
///
/// Accepts strings (BOT: `"33.4859000"`, may be empty) and JSON numbers
/// (Frankfurter). Empty, blank or null input yields `null`.
/// Throws [FormatException] on anything else.
Decimal? parseDecimalOrNull(Object? raw) {
  switch (raw) {
    case null:
      return null;
    case final String s when s.trim().isEmpty:
      return null;
    case final String s:
      return Decimal.parse(s.trim().replaceAll(',', ''));
    // num.toString() gives the shortest round-trip form, so no binary
    // floating-point noise leaks into the Decimal.
    case final num n:
      return Decimal.parse(n.toString());
    default:
      throw FormatException('Not a number', raw);
  }
}

/// Precision used when a division doesn't terminate (e.g. 1 / 3).
/// BOT publishes 7 decimal places; keep a few more for intermediate math.
const kDivisionScale = 10;

extension DecimalDivision on Decimal {
  /// `this / other`, rounded half away from zero to [scale] places.
  Decimal dividedBy(Decimal other, {int scale = kDivisionScale}) =>
      (this / other).roundToDecimal(scale);
}

extension RationalRounding on Rational {
  /// Rounds half away from zero to [scale] decimal places. (`toDecimal`
  /// with `scaleOnInfinitePrecision` truncates, which biases money down.)
  Decimal roundToDecimal(int scale) {
    final factor = BigInt.from(10).pow(scale);
    return Rational((this * Rational(factor)).round(), factor).toDecimal();
  }
}

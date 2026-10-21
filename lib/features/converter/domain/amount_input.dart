import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

/// The amount typed on the converter keypad.
///
/// Kept as text so "12." and "0.50" show exactly as typed. Always a valid
/// prefix of a decimal number with at most [maxIntegerDigits] integer and
/// [maxFractionDigits] fraction digits; '.' is the decimal point.
@immutable
class AmountInput {
  /// [text] must already be valid; use `preset` for numbers.
  const new([this.text = '']) : replaceOnType = false;

  /// A ready-made amount (quick amounts, the default) that the next digit
  /// replaces instead of extending.
  new preset(Decimal amount)
    : text = amount.round(scale: maxFractionDigits).toString(),
      replaceOnType = true;

  static const maxIntegerDigits = 12;
  static const maxFractionDigits = 2;

  final String text;

  /// Whether the next digit or decimal point starts a new amount.
  final bool replaceOnType;

  /// The typed amount; zero while empty or for a lone "0.".
  Decimal get value {
    final digits = text.endsWith('.')
        ? text.substring(0, text.length - 1)
        : text;
    return digits.isEmpty ? Decimal.zero : Decimal.parse(digits);
  }

  AmountInput typeDigit(int digit) {
    assert(digit >= 0 && digit <= 9, 'Not a digit: $digit');
    final current = replaceOnType ? '' : text;
    if (current == '0') return AmountInput('$digit');
    final [integer, ...fraction] = current.split('.');
    final full = fraction.isEmpty
        ? integer.length >= maxIntegerDigits
        : fraction.single.length >= maxFractionDigits;
    if (full) return AmountInput(current);
    return AmountInput('$current$digit');
  }

  AmountInput typeDecimalPoint() {
    final current = replaceOnType ? '' : text;
    if (current.contains('.')) return AmountInput(current);
    return AmountInput(current.isEmpty ? '0.' : '$current.');
  }

  AmountInput backspace() =>
      text.isEmpty ? this : AmountInput(text.substring(0, text.length - 1));

  AmountInput clear() => const AmountInput();

  @override
  bool operator ==(Object other) =>
      other is AmountInput &&
      other.text == text &&
      other.replaceOnType == replaceOnType;

  @override
  int get hashCode => Object.hash(text, replaceOnType);

  @override
  String toString() => 'AmountInput($text, replaceOnType: $replaceOnType)';
}

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';

/// Locale-aware formatting of [Decimal] values without going through
/// `double`, so what's shown is exactly the rounded Decimal.
class DecimalFormatter {
  new(String locale) : _symbols = NumberFormat.decimalPattern(locale).symbols;

  final NumberSymbols _symbols;

  /// `33.4859` → `"33.4859"`; `1234.5` with 2 digits → `"1,234.50"`.
  /// [signed] prefixes positive values with `+` (for changes).
  String format(Decimal value, {int digits = 4, bool signed = false}) {
    final rounded = value.round(scale: digits);
    final [integer, ...fraction] = rounded
        .abs()
        .toStringAsFixed(digits)
        .split('.');
    final grouped = _group(integer);
    final sign = switch (rounded.sign) {
      < 0 => '−',
      > 0 when signed => '+',
      _ => '',
    };
    return [
      '$sign$grouped',
      if (fraction.isNotEmpty) fraction.single,
    ].join(_symbols.DECIMAL_SEP);
  }

  /// Keypad input as typed (`"1234.5"` → `"1,234.5"`), keeping a trailing
  /// decimal point or zeros not yet followed by more digits. Empty → `"0"`.
  String formatTyped(String typed) {
    if (typed.isEmpty) return '0';
    final [integer, ...fraction] = typed.split('.');
    return [_group(integer), ...fraction].join(_symbols.DECIMAL_SEP);
  }

  String _group(String digits) => digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => _symbols.GROUP_SEP,
  );

  /// A change in percent: `0.2512` → `"+0.25%"`.
  String percent(Decimal value, {int digits = 2}) =>
      '${format(value, digits: digits, signed: true)}%';
}

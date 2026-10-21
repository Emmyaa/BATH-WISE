import 'package:bath_wise/features/converter/domain/amount_input.dart';
import 'package:bath_wise/features/converter/domain/currency_converter.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/watchlist/presentation/watchlist_codes_provider.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'converter_view_model.freezed.dart';
part 'converter_view_model.g.dart';

@freezed
abstract class ConverterState with _$ConverterState {
  const factory({
    required AmountInput input,
    @Default('USD') String from,
    @Default('THB') String to,
    @Default(RateType.mid) RateType rateType,
  }) = _ConverterState;
}

/// Keypad input, currency pair and rate type of the Converter. Kept alive
/// so a half-typed amount survives tab switches.
@Riverpod(keepAlive: true)
class ConverterViewModel extends _$ConverterViewModel {
  static final quickAmounts = [100, 1000, 10000];

  @override
  ConverterState build() =>
      ConverterState(input: AmountInput.preset(Decimal.fromInt(100)));

  void typeDigit(int digit) => _edit(state.input.typeDigit(digit));

  void typeDecimalPoint() => _edit(state.input.typeDecimalPoint());

  void backspace() => _edit(state.input.backspace());

  void clear() => _edit(state.input.clear());

  void useQuickAmount(int amount) =>
      _edit(AmountInput.preset(Decimal.fromInt(amount)));

  /// Swaps the pair; the typed amount stays and is now in the other
  /// currency.
  void swap() => state = state.copyWith(from: state.to, to: state.from);

  /// Picking the currency already on the other side swaps instead, so the
  /// pair never converts a currency to itself.
  void selectFrom(String code) {
    if (code == state.from) return;
    if (code == state.to) return swap();
    state = state.copyWith(from: code);
  }

  void selectTo(String code) {
    if (code == state.to) return;
    if (code == state.from) return swap();
    state = state.copyWith(to: code);
  }

  void selectRateType(RateType type) => state = state.copyWith(rateType: type);

  void _edit(AmountInput input) => state = state.copyWith(input: input);
}

/// One row of "in other currencies".
typedef ConvertedAmount = ({String code, Decimal? amount});

/// Everything the Converter shows for the current input and rates.
@freezed
abstract class ConversionView with _$ConversionView {
  const factory({
    required RatesSnapshot snapshot,
    required String from,
    required String to,

    /// The rate type actually used: mid for ECB data, which has no
    /// buy/sell rates.
    required RateType rateType,
    required Decimal amount,

    /// Null when `from` or `to` has no rate of `rateType`.
    required Decimal? result,
    required ConversionRate? rate,

    /// `amount` in THB and the watchlist currencies other than the pair.
    required List<ConvertedAmount> others,

    /// THB, then every currency in the snapshot, for the pickers.
    required List<String> currencies,
  }) = _ConversionView;
}

/// Null until the latest rates have loaded.
@riverpod
ConversionView? conversion(Ref ref) {
  final snapshot = ref.watch(latestRatesViewModelProvider).value;
  if (snapshot == null) return null;
  return buildConversion(
    snapshot,
    ref.watch(converterViewModelProvider),
    ref.watch(watchlistCodesProvider),
  );
}

/// Pure so it can be unit tested.
ConversionView buildConversion(
  RatesSnapshot snapshot,
  ConverterState state,
  List<String> watchlist,
) {
  final rateType = snapshot.source == RateSource.ecb
      ? RateType.mid
      : state.rateType;
  final converter = CurrencyConverter(snapshot, rateType);
  final amount = state.input.value;
  final ConverterState(:from, :to) = state;
  final thb = Currencies.thb.code;
  return ConversionView(
    snapshot: snapshot,
    from: from,
    to: to,
    rateType: rateType,
    amount: amount,
    result: converter.convert(amount, from: from, to: to),
    rate: converter.rateFor(from: from, to: to),
    others: [
      for (final code in {thb, ...watchlist})
        if (code != from &&
            code != to &&
            (code == thb || snapshot.quoteFor(code) != null))
          (code: code, amount: converter.convert(amount, from: from, to: code)),
    ],
    currencies: [thb, for (final q in snapshot.quotes) q.currencyCode],
  );
}

import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/features/converter/domain/amount_input.dart';
import 'package:bath_wise/features/converter/domain/currency_converter.dart';
import 'package:bath_wise/features/converter/presentation/converter_view_model.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Decimal d(String s) => Decimal.parse(s);

AmountInput typed(String keys) {
  var input = const AmountInput();
  for (final key in keys.split('')) {
    input = key == '.'
        ? input.typeDecimalPoint()
        : input.typeDigit(int.parse(key));
  }
  return input;
}

void main() {
  group('AmountInput', () {
    test('builds the amount digit by digit', () {
      expect(typed('1234').text, '1234');
      expect(typed('1234').value, d('1234'));
      expect(typed('12.5').value, d('12.5'));
    });

    test('keeps a trailing point and zeros as typed', () {
      expect(typed('12.').text, '12.');
      expect(typed('12.').value, d('12'));
      expect(typed('0.50').text, '0.50');
    });

    test('a leading point becomes "0."; a second point is ignored', () {
      expect(typed('.').text, '0.');
      expect(typed('.5').value, d('0.5'));
      expect(typed('1.2.3').text, '1.23');
    });

    test('no leading zeros', () {
      expect(typed('007').text, '7');
      expect(typed('0').text, '0');
      expect(typed('0.05').text, '0.05');
    });

    test('limits integer and fraction digits', () {
      expect(typed('1' * 15).text, '1' * AmountInput.maxIntegerDigits);
      expect(typed('1.999').text, '1.99');
    });

    test('backspace and clear', () {
      expect(typed('12.5').backspace().text, '12.');
      expect(typed('1').backspace().backspace().text, '');
      expect(typed('').value, Decimal.zero);
      expect(typed('99').clear(), const AmountInput());
    });

    test('a preset is replaced by the next digit or point', () {
      final preset = AmountInput.preset(Decimal.fromInt(1000));
      expect(preset.text, '1000');
      expect(preset.typeDigit(5).text, '5');
      expect(preset.typeDecimalPoint().text, '0.');
      // Backspace edits the preset instead, and typing then appends.
      expect(preset.backspace().typeDigit(7).text, '1007');
    });
  });

  group('CurrencyConverter (real BOT sample, 19 Oct 2026)', () {
    final snapshot = sampleSnapshot();
    final mid = CurrencyConverter(snapshot, RateType.mid);

    Decimal? convert(
      String amount,
      String from,
      String to, {
      CurrencyConverter? converter,
    }) => (converter ?? mid)
        .convert(d(amount), from: from, to: to)
        ?.round(scale: 2);

    test('foreign → THB multiplies by the rate', () {
      expect(convert('100', 'USD', 'THB'), d('3348.59'));
      expect(convert('25', 'USD', 'THB'), d('837.15'));
    });

    test('THB → foreign divides by the rate', () {
      expect(convert('1000', 'THB', 'USD'), d('29.86'));
    });

    test('respects quotation units (JPY per 100, IDR per 1,000)', () {
      expect(convert('1000', 'JPY', 'THB'), d('211.86'));
      expect(convert('100', 'USD', 'JPY'), d('15805.75'));
      expect(convert('100', 'USD', 'IDR'), d('1795201.84'));
    });

    test('foreign → foreign crosses through THB', () {
      expect(convert('100', 'USD', 'EUR'), d('89.22'));
    });

    test('uses the chosen rate type', () {
      final selling = CurrencyConverter(snapshot, RateType.selling);
      expect(convert('100', 'USD', 'THB', converter: selling), d('3364.89'));
    });

    test('same currency is identity; missing rates give null', () {
      expect(convert('42', 'USD', 'USD'), d('42'));
      expect(convert('1', 'XYZ', 'THB'), isNull);

      final noSelling = snapshot.copyWith(
        quotes: [
          for (final q in snapshot.quotes)
            if (q.currencyCode == 'USD')
              q.copyWith.current(selling: null)
            else
              q,
        ],
      );
      final selling = CurrencyConverter(noSelling, RateType.selling);
      expect(convert('1', 'USD', 'THB', converter: selling), isNull);
      expect(selling.rateFor(from: 'USD', to: 'THB'), isNull);
    });

    test('rate used is per quotation unit of the source currency', () {
      expect(mid.rateFor(from: 'USD', to: 'THB'), (
        unit: 1,
        rate: d('33.4859'),
      ));
      expect(mid.rateFor(from: 'IDR', to: 'THB'), (
        unit: 1000,
        rate: d('1.8653'),
      ));
      expect(
        mid.rateFor(from: 'THB', to: 'JPY')?.rate.round(scale: 4),
        d('4.7201'),
      );
    });
  });

  group('ConverterViewModel', () {
    late ProviderContainer container;
    ConverterViewModel vm() =>
        container.read(converterViewModelProvider.notifier);
    ConverterState state() => container.read(converterViewModelProvider);

    setUp(() {
      container = ProviderContainer.test(
        overrides: appOverrides(fx: FakeFxRepository(Ok(sampleSnapshot()))),
      );
    });

    test('starts at 100 USD → THB, mid rate', () {
      expect(state().from, 'USD');
      expect(state().to, 'THB');
      expect(state().input.value, d('100'));
      expect(state().rateType, RateType.mid);
    });

    test('typing replaces the default amount, then appends', () {
      vm()
        ..typeDigit(2)
        ..typeDigit(5);
      expect(state().input.text, '25');
    });

    test('quick amounts replace the amount', () {
      vm()
        ..typeDigit(7)
        ..useQuickAmount(10000);
      expect(state().input.value, d('10000'));
    });

    test('swap exchanges the pair and keeps the amount', () {
      vm().swap();
      expect((state().from, state().to), ('THB', 'USD'));
      expect(state().input.value, d('100'));
    });

    test('picking the other side’s currency swaps', () {
      vm().selectFrom('THB');
      expect((state().from, state().to), ('THB', 'USD'));
      vm().selectTo('THB');
      expect((state().from, state().to), ('USD', 'THB'));
      vm().selectTo('EUR');
      expect((state().from, state().to), ('USD', 'EUR'));
    });

    test('conversion follows the input and the loaded rates', () async {
      expect(container.read(conversionProvider), isNull);
      await container.read(latestRatesViewModelProvider.future);

      final view = container.read(conversionProvider)!;
      expect(view.result?.round(scale: 2), d('3348.59'));
      expect(view.rate, (unit: 1, rate: d('33.4859')));

      vm().selectRateType(RateType.selling);
      expect(
        container.read(conversionProvider)!.result?.round(scale: 2),
        d('3364.89'),
      );
    });

    test('a load failure leaves no conversion', () async {
      container = ProviderContainer.test(
        overrides: appOverrides(
          fx: FakeFxRepository(const Err(NetworkFailure())),
        ),
      );
      await expectLater(
        container.read(latestRatesViewModelProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(container.read(conversionProvider), isNull);
    });
  });

  group('buildConversion', () {
    const watchlist = ['USD', 'EUR', 'JPY', 'XYZ'];
    final state = ConverterState(input: AmountInput.preset(d('100')));

    test('other currencies: THB and the watchlist minus the pair', () {
      final view = buildConversion(
        sampleSnapshot(),
        state.copyWith(to: 'EUR'),
        watchlist,
      );
      // XYZ has no rate in the snapshot, so it's left out.
      expect([for (final o in view.others) o.code], ['THB', 'JPY']);
      expect(view.others.first.amount?.round(scale: 2), d('3348.59'));
      expect(view.others.last.amount?.round(scale: 2), d('15805.75'));
    });

    test('pickers offer THB first, then every quoted currency', () {
      final view = buildConversion(sampleSnapshot(), state, watchlist);
      expect(view.currencies.first, 'THB');
      expect(view.currencies, hasLength(20));
    });

    test('ECB data is converted at mid whatever type was chosen', () {
      final view = buildConversion(
        sampleSnapshot(source: RateSource.ecb),
        state.copyWith(rateType: RateType.selling),
        watchlist,
      );
      expect(view.rateType, RateType.mid);
      expect(view.result?.round(scale: 2), d('3348.59'));
    });
  });
}

import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_dto.dart';
import 'package:bath_wise/features/rates/data/bot_period_format.dart';
import 'package:bath_wise/features/rates/data/frankfurter_dtos.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

List<ExchangeRate> parseSample(String name, Periodicity periodicity) => [
  for (final row in botDataDetail(loadApiSample(name)))
    ?BotExchangeRateDto.fromJson(row).toEntity(periodicity),
];

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('BOT daily sample (real response)', () {
    final rates = parseSample('exchange_daily_all', Periodicity.daily);

    test('parses every currency for every released day', () {
      expect(rates, hasLength(76));
      expect(rates.map((r) => r.currencyCode).toSet(), hasLength(19));
      expect(rates.map((r) => r.period).toSet(), {
        DateTime.utc(2026, 10, 12),
        DateTime.utc(2026, 10, 14),
        DateTime.utc(2026, 10, 15),
        DateTime.utc(2026, 10, 19),
      });
    });

    test('maps all four rates as Decimals', () {
      final usd = rates.firstWhere(
        (r) =>
            r.currencyCode == 'USD' && r.period == DateTime.utc(2026, 10, 19),
      );
      expect(usd.source, RateSource.bot);
      expect(usd.buyingSight, d('33.23'));
      expect(usd.buyingTransfer, d('33.3229'));
      expect(usd.selling, d('33.6489'));
      expect(usd.mid, d('33.4859'));
    });

    test('reads quotation units from names: JPY per 100, IDR per 1,000', () {
      ExchangeRate of(String code) =>
          rates.firstWhere((r) => r.currencyCode == code);
      expect(of('JPY').unit, 100);
      expect(of('IDR').unit, 1000);
      expect(of('USD').unit, 1);
      expect(of('JPY').perUnit(RateType.mid), d('0.211859'));
    });

    test('uses clean display names instead of trailing-space BOT names', () {
      final usd = rates.firstWhere((r) => r.currencyCode == 'USD');
      expect(usd.nameEn, 'US Dollar');
      expect(usd.nameTh, 'ดอลลาร์สหรัฐฯ');
    });
  });

  test('BOT "no data" placeholder rows are dropped (weekend sample)', () {
    expect(parseSample('exchange_daily_weekend', Periodicity.daily), isEmpty);
  });

  test('unknown currency keeps BOT name, trimmed, and parsed unit', () {
    const dto = BotExchangeRateDto(
      period: '2026-10-19',
      currencyId: 'KRW',
      currencyNameEng: 'KOREA : WON (1,000 WON) (KRW) ',
      currencyNameTh: 'เกาหลีใต้ : วอน (KRW) ',
      midRate: '24.10',
      buyingSight: '',
    );
    final rate = dto.toEntity(Periodicity.daily)!;
    expect(rate.nameEn, 'KOREA : WON (1,000 WON) (KRW)');
    expect(rate.nameTh, 'เกาหลีใต้ : วอน (KRW)');
    expect(rate.unit, 1000);
    expect(rate.buyingSight, isNull);
  });

  test('BOT monthly and annual samples', () {
    final monthly = parseSample('exchange_monthly_usd', Periodicity.monthly);
    expect(monthly, hasLength(12));
    expect(monthly.first.period, DateTime.utc(2026, 9));
    expect(monthly.first.mid, d('33.2124'));

    final annual = parseSample('exchange_annual_jpy', Periodicity.annual);
    expect(annual.map((r) => r.period), [
      DateTime.utc(2025),
      DateTime.utc(2024),
      DateTime.utc(2023),
    ]);
    expect(annual.first.unit, 100);
  });

  group('BotPeriodFormat', () {
    final date = DateTime.utc(2026, 8, 15);

    test('formats each periodicity as the spec requires', () {
      expect(BotPeriodFormat.format(Periodicity.daily, date), '2026-08-15');
      expect(BotPeriodFormat.format(Periodicity.monthly, date), '2026-08');
      expect(BotPeriodFormat.format(Periodicity.quarterly, date), '2026-Q3');
      expect(BotPeriodFormat.format(Periodicity.annual, date), '2026');
    });

    test('parses periods to their first day', () {
      expect(
        BotPeriodFormat.parse(Periodicity.quarterly, '2026-Q3'),
        DateTime.utc(2026, 7),
      );
      expect(
        () => BotPeriodFormat.parse(Periodicity.monthly, '2026-13x'),
        throwsFormatException,
      );
    });
  });

  group('RateQuote', () {
    final rates = parseSample('exchange_daily_all', Periodicity.daily);
    final quotes = RateQuote.fromRates(rates);

    test('pairs each currency with its previous day, in BOT order', () {
      expect(quotes, hasLength(19));
      expect(quotes.first.currencyCode, 'USD');
      expect(quotes.first.current.period, DateTime.utc(2026, 10, 19));
      expect(quotes.first.previous!.period, DateTime.utc(2026, 10, 15));
    });

    test('computes change and percent change exactly', () {
      final quote = RateQuote(
        current: ExchangeRate(
          currencyCode: 'USD',
          period: DateTime.utc(2026, 10, 19),
          source: RateSource.bot,
          mid: d('33.50'),
        ),
        previous: ExchangeRate(
          currencyCode: 'USD',
          period: DateTime.utc(2026, 10, 15),
          source: RateSource.bot,
          mid: d('33.00'),
        ),
      );
      expect(quote.change(RateType.mid), d('0.5'));
      expect(quote.changePercent(RateType.mid), d('1.5152'));
      expect(quote.change(RateType.selling), isNull);
    });
  });

  group('Frankfurter (real responses)', () {
    test('latest: parses numeric rates', () {
      final dto = FrankfurterLatestDto.fromJson(
        loadApiSample('frankfurter_latest_thb')! as Map<String, dynamic>,
      );
      expect(dto.base, 'THB');
      expect(dto.rates['USD'], 0.0298);
    });

    test('series base=USD → THB per unit, oldest first', () {
      final dto = FrankfurterSeriesDto.fromJson(
        loadApiSample('frankfurter_series_usd_thb')! as Map<String, dynamic>,
      );
      final series = dto.toThbSeries('USD');
      expect(series, hasLength(7));
      expect(series.first.period, DateTime.utc(2026, 10, 9));
      expect(series.last.mid, d('33.555'));
      expect(series.every((r) => r.source == RateSource.ecb), isTrue);
    });

    test('series base=THB → inverted into BOT units', () {
      final latest =
          loadApiSample('frankfurter_latest_thb')! as Map<String, dynamic>;
      final dto = FrankfurterSeriesDto.fromJson({
        'base': 'THB',
        'rates': {'2026-10-19': latest['rates']},
      });
      final rates = {for (final r in dto.toThbRates()) r.currencyCode: r};

      expect(rates['USD']!.mid, d('33.5570470')); // 1 / 0.0298
      expect(rates['JPY']!.unit, 100);
      expect(rates['JPY']!.mid, d('21.2044105')); // 100 / 4.716
      expect(rates.containsKey('BND'), isFalse, reason: 'ECB has no BND');
      expect(rates.containsKey('BRL'), isFalse, reason: 'not a BOT currency');
    });
  });
}

// Captures real API responses into docs/api-samples/ for parser tests.
//
//   dart run tool/fetch_api_samples.dart
//
// Uses ~8 BOT calls (limit: 200/hour). Prints status and size only; the
// token is never printed.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:bath_wise/core/env/env.dart';

const _exchange = 'https://gateway.api.bot.or.th/Stat-ExchangeRate/v2';
const _loan = 'https://gateway.api.bot.or.th/LoanRate/v2';
const _holidays =
    'https://gateway.api.bot.or.th/financial-institutions-holidays/';
const _frankfurter = 'https://api.frankfurter.dev/v1';

Future<void> main() async {
  final today = DateTime.now();
  String ymd(DateTime d) => d.toIso8601String().substring(0, 10);
  final start = ymd(today.subtract(const Duration(days: 10)));
  final end = ymd(today);

  final samples = <String, (String, bool)>{
    'exchange_daily_all': (
      '$_exchange/DAILY_AVG_EXG_RATE/?start_period=$start&end_period=$end',
      true,
    ),
    'exchange_daily_weekend': (
      '$_exchange/DAILY_AVG_EXG_RATE/'
          '?start_period=2026-10-17&end_period=2026-10-18&currency=USD',
      true,
    ),
    'exchange_monthly_usd': (
      '$_exchange/MONTHLY_AVG_EXG_RATE/'
          '?start_period=2025-10&end_period=2026-09&currency=USD',
      true,
    ),
    'exchange_annual_jpy': (
      '$_exchange/ANNUAL_AVG_EXG_RATE/'
          '?start_period=2023&end_period=2025&currency=JPY',
      true,
    ),
    'loan_rate': (
      '$_loan/loan_rate/?start_period=$start&end_period=$end',
      true,
    ),
    'avg_loan_rate': (
      '$_loan/avg_loan_rate/?start_period=$start&end_period=$end',
      true,
    ),
    'holidays_2026': ('$_holidays?year=2026', true),
    'error_unauthorized': (
      '$_exchange/DAILY_AVG_EXG_RATE/?start_period=$end&end_period=$end',
      false,
    ),
    'frankfurter_latest_thb': ('$_frankfurter/latest?base=THB', false),
    'frankfurter_series_usd_thb': (
      '$_frankfurter/$start..$end?base=USD&symbols=THB',
      false,
    ),
    'frankfurter_currencies': ('$_frankfurter/currencies', false),
  };

  final client = HttpClient();
  final dir = Directory('docs/api-samples')..createSync(recursive: true);
  for (final MapEntry(key: name, value: (url, auth)) in samples.entries) {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (auth) {
      request.headers.set(HttpHeaders.authorizationHeader, Env.botApiToken);
    } else if (name.startsWith('error_')) {
      request.headers.set(HttpHeaders.authorizationHeader, 'invalid-token');
    }
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (auth && response.statusCode != 200) {
      // Keep the last good sample instead of overwriting it with an error.
      print('$name: ${response.statusCode} — skipped (${body.trim()})');
      continue;
    }
    Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      json = {'_raw': body};
    }
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert({'_request': url, '_status': response.statusCode, 'body': json});
    File('${dir.path}/$name.json').writeAsStringSync('$pretty\n');
    print('$name: ${response.statusCode} (${body.length} bytes)');
  }
  client.close();
}

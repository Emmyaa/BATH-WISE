import 'dart:async';

import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/bot_response.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_providers.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rates_repository.dart';
import 'package:bath_wise/features/market_calendar/data/market_calendar_providers.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday.dart';
import 'package:bath_wise/features/market_calendar/domain/holiday_repository.dart';
import 'package:bath_wise/features/market_calendar/domain/market_calendar_service.dart';
import 'package:bath_wise/features/rates/data/bot_exchange_rate_dto.dart';
import 'package:bath_wise/features/rates/data/rates_providers.dart';
import 'package:bath_wise/features/rates/domain/exchange_rate.dart';
import 'package:bath_wise/features/rates/domain/fx_repository.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_providers.dart';
import 'package:bath_wise/features/watchlist/domain/alert_check.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/features/watchlist/domain/watchlist_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/misc.dart';

import 'test_helpers.dart';

/// Snapshot built from the real daily sample (as of Mon 19 Oct 2026).
RatesSnapshot sampleSnapshot({
  RateSource source = RateSource.bot,
  Failure? refreshFailure,
}) {
  final rates = [
    for (final row in botDataDetail(loadApiSample('exchange_daily_all')))
      ?BotExchangeRateDto.fromJson(row).toEntity(Periodicity.daily),
  ];
  return RatesSnapshot(
    asOf: DateTime.utc(2026, 10, 19),
    source: source,
    quotes: RateQuote.fromRates(rates),
    fetchedAt: bkk(2026, 10, 19, 18, 5),
    refreshFailure: refreshFailure,
  );
}

typedef HistoryRequest = ({
  String code,
  Periodicity periodicity,
  DateTime start,
  DateTime end,
});

/// A [RateSeries] of mid rates, one per day (or month) from [start].
RateSeries fakeSeries(
  String code,
  List<num> mids, {
  Periodicity periodicity = Periodicity.daily,
  DateTime? start,
  RateSource source = RateSource.bot,
  Failure? refreshFailure,
}) {
  final first = start ?? DateTime.utc(2026, 9, 21);
  return RateSeries(
    currencyCode: code,
    periodicity: periodicity,
    source: source,
    refreshFailure: refreshFailure,
    points: [
      for (final (i, mid) in mids.indexed)
        ExchangeRate(
          currencyCode: code,
          period: periodicity == Periodicity.daily
              ? DateTime.utc(first.year, first.month, first.day + i)
              : DateTime.utc(first.year, first.month + i),
          source: source,
          mid: Decimal.parse('$mid'),
        ),
    ],
  );
}

class FakeFxRepository implements FxRepository {
  new(this.latest);

  /// What [getLatestRates] returns; replace between calls.
  Result<RatesSnapshot> latest;
  int latestCalls = 0;
  bool? lastForceRefresh;

  @override
  Future<Result<RatesSnapshot>> getLatestRates({
    bool forceRefresh = false,
  }) async {
    latestCalls++;
    lastForceRefresh = forceRefresh;
    return latest;
  }

  /// What [getHistory] returns per request; no data by default.
  Result<RateSeries> Function(HistoryRequest request) history = (_) =>
      const Err(NoDataFailure());
  final historyRequests = <HistoryRequest>[];

  @override
  Future<Result<RateSeries>> getHistory({
    required String currencyCode,
    required Periodicity periodicity,
    required DateTime start,
    required DateTime end,
  }) async {
    final request = (
      code: currencyCode,
      periodicity: periodicity,
      start: start,
      end: end,
    );
    historyRequests.add(request);
    return history(request);
  }

  @override
  Future<Result<CrossRate>> getCrossRate({
    required String base,
    required String quote,
  }) async => const Err(NoDataFailure());
}

class FakeHolidayRepository implements HolidayRepository {
  new([this.holidays = const []]);

  final List<Holiday> holidays;

  @override
  Future<Result<List<Holiday>>> getHolidays(int year) async => Ok([
    for (final h in holidays)
      if (h.date.year == year) h,
  ]);
}

class FakeLoanRatesRepository implements LoanRatesRepository {
  new([this.result = const Err(UnauthorizedFailure('403'))]);

  final Result<LoanRatesSnapshot> result;

  @override
  Future<Result<LoanRatesSnapshot>> getLatest(
    LoanRateKind kind, {
    bool forceRefresh = false,
  }) async => result;
}

/// In-memory watchlist and alerts with the same semantics as the Drift
/// repository (see watchlist_repository_test.dart for those).
class FakeWatchlistRepository implements WatchlistRepository {
  new({
    List<String> codes = AppDatabase.starterWatchlist,
    List<RateAlert> alerts = const [],
  }) : codes = [...codes],
       alerts = [...alerts];

  List<String> codes;
  List<RateAlert> alerts;
  final _changes = StreamController<void>.broadcast();
  int _nextId = 100;

  void _changed() => _changes.add(null);

  /// Emits [read] now and after every change, subscribing on listen so
  /// no change is missed.
  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        changes = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<List<String>> watchCodes() => _watch(() => [...codes]);

  @override
  Stream<List<RateAlert>> watchAlerts() => _watch(() => [...alerts]);

  @override
  Future<void> add(String code) async {
    if (!codes.contains(code)) codes = [...codes, code];
    _changed();
  }

  @override
  Future<RemovedWatchItem?> remove(String code) async {
    final index = codes.indexOf(code);
    if (index < 0) return null;
    final removed = (
      currencyCode: code,
      index: index,
      alerts: [
        for (final a in alerts)
          if (a.currencyCode == code) a,
      ],
    );
    codes = [...codes]..removeAt(index);
    alerts = [
      for (final a in alerts)
        if (a.currencyCode != code) a,
    ];
    _changed();
    return removed;
  }

  @override
  Future<void> restore(RemovedWatchItem item) async {
    codes = [...codes]
      ..insert(item.index.clamp(0, codes.length), item.currencyCode);
    alerts = [...alerts, ...item.alerts];
    _changed();
  }

  @override
  Future<void> reorder(List<String> codes) async {
    this.codes = [...codes];
    _changed();
  }

  @override
  Future<List<RateAlert>> activeAlerts() async => [
    for (final a in alerts)
      if (a.enabled && !a.isTriggered) a,
  ];

  @override
  Future<void> addAlert(NewRateAlert alert) async {
    if (!codes.contains(alert.currencyCode)) {
      codes = [...codes, alert.currencyCode];
    }
    alerts = [
      ...alerts,
      RateAlert(
        id: _nextId++,
        currencyCode: alert.currencyCode,
        direction: alert.direction,
        target: alert.target,
        rateType: alert.rateType,
        createdAt: DateTime.utc(2026, 10, 20),
      ),
    ];
    _changed();
  }

  @override
  Future<void> deleteAlert(int id) async {
    alerts = [
      for (final a in alerts)
        if (a.id != id) a,
    ];
    _changed();
  }

  @override
  Future<void> setAlertEnabled(int id, {required bool enabled}) async {
    alerts = [
      for (final a in alerts)
        if (a.id != id)
          a
        else if (enabled)
          a.copyWith(
            enabled: true,
            triggeredAt: null,
            triggeredRate: null,
            triggeredPeriod: null,
          )
        else
          a.copyWith(enabled: false),
    ];
    _changed();
  }

  @override
  Future<List<AlertTrigger>> markTriggered(
    List<AlertTrigger> triggers,
    DateTime at,
  ) async {
    final recorded = <AlertTrigger>[];
    for (final t in triggers) {
      final i = alerts.indexWhere((a) => a.id == t.alert.id);
      if (i < 0 || alerts[i].isTriggered) continue;
      alerts = [...alerts]
        ..[i] = alerts[i].copyWith(
          enabled: false,
          triggeredAt: at,
          triggeredRate: t.rate,
          triggeredPeriod: t.period,
        );
      recorded.add(t);
    }
    _changed();
    return recorded;
  }
}

class FakeAlertNotifier implements AlertNotifier {
  new({this.permission = true});

  bool permission;
  int permissionRequests = 0;
  final shown = <AlertTrigger>[];

  @override
  Future<void> initialize({void Function(String code)? onTap}) async {}

  @override
  Future<String?> launchedFromCode() async => null;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> show(List<AlertTrigger> triggers) async =>
      shown.addAll(triggers);
}

class FakeAlertScheduler implements AlertScheduler {
  /// Every `hasActiveAlerts` passed to [sync], in order.
  final syncs = <bool>[];

  @override
  Future<void> sync({required bool hasActiveAlerts}) async =>
      syncs.add(hasActiveAlerts);
}

/// A [RateAlert] for tests; mid rate, above, active unless stated.
RateAlert testAlert({
  int id = 1,
  String code = 'USD',
  AlertDirection direction = AlertDirection.above,
  String target = '30',
  RateType rateType = RateType.mid,
  bool enabled = true,
  DateTime? triggeredAt,
}) => RateAlert(
  id: id,
  currencyCode: code,
  direction: direction,
  target: Decimal.parse(target),
  rateType: rateType,
  createdAt: DateTime.utc(2026, 10, 2),
  enabled: enabled,
  triggeredAt: triggeredAt,
);

/// Overrides every provider that would touch the network, disk or clock.
List<Override> appOverrides({
  required FxRepository fx,
  DateTime? now,
  List<Holiday> holidays = const [],
  LoanRatesRepository? loans,
  WatchlistRepository? watchlist,
  AlertNotifier? notifier,
  AlertScheduler? scheduler,
}) {
  final holidayRepo = FakeHolidayRepository(holidays);
  return [
    watchlistRepositoryProvider.overrideWithValue(
      watchlist ?? FakeWatchlistRepository(),
    ),
    alertNotificationsProvider.overrideWithValue(
      notifier ?? FakeAlertNotifier(),
    ),
    alertSchedulerProvider.overrideWithValue(scheduler ?? FakeAlertScheduler()),
    fxRepositoryProvider.overrideWithValue(fx),
    holidayRepositoryProvider.overrideWithValue(holidayRepo),
    marketCalendarServiceProvider.overrideWithValue(
      MarketCalendarService(holidayRepo),
    ),
    loanRatesRepositoryProvider.overrideWithValue(
      loans ?? FakeLoanRatesRepository(),
    ),
    clockProvider.overrideWithValue(FakeClock(now ?? bkk(2026, 10, 20, 9))),
  ];
}

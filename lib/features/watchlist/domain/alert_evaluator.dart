import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';

/// The active alerts in [alerts] whose condition [snapshot] meets.
///
/// Only official BOT data can trigger an alert: an ECB fallback snapshot
/// is a reference rate (and mid only), so it never fires one.
List<AlertTrigger> evaluateAlerts(
  List<RateAlert> alerts,
  RatesSnapshot snapshot,
) {
  if (snapshot.source != RateSource.bot) return const [];
  return [
    for (final alert in alerts)
      if (alert.enabled && !alert.isTriggered)
        if (snapshot.quoteFor(alert.currencyCode)?.current case final rate?)
          if (rate.valueOf(alert.rateType) case final value?
              when alert.isMetBy(value))
            (alert: alert, rate: value, period: rate.period),
  ];
}

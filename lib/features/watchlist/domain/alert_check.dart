import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/rates/domain/fx_repository.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/watchlist/domain/alert_evaluator.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/features/watchlist/domain/watchlist_repository.dart';

/// Shows triggered alerts to the user (system notifications).
abstract interface class AlertNotifier {
  /// Must run before anything else. [onTap] receives the currency code of
  /// a tapped notification while the app is running.
  Future<void> initialize({void Function(String code)? onTap});

  /// Currency code of the alert notification that launched the app.
  Future<String?> launchedFromCode();

  /// Asks for permission to notify. True if granted or not needed.
  Future<bool> requestPermission();

  Future<void> show(List<AlertTrigger> triggers);
}

/// Keeps the periodic background check scheduled only while it has
/// something to check.
abstract interface class AlertScheduler {
  Future<void> sync({required bool hasActiveAlerts});
}

/// Checks the active alerts against the latest rates and notifies.
///
/// Used by the background worker and by the app whenever new rates load.
class AlertCheck {
  const new(this._watchlist, this._fx, this._notifier, this._clock);

  final WatchlistRepository _watchlist;
  final FxRepository _fx;
  final AlertNotifier _notifier;
  final Clock _clock;

  /// Evaluates against [snapshot], or the repository's latest rates when
  /// none is given. The repository only calls BOT when a release is due,
  /// so a run costs at most one BOT call, usually none. With no active
  /// alerts it doesn't ask for rates at all.
  Future<List<AlertTrigger>> run([RatesSnapshot? snapshot]) async {
    final alerts = await _watchlist.activeAlerts();
    if (alerts.isEmpty) return const [];
    final rates = snapshot ?? (await _fx.getLatestRates()).valueOrNull;
    if (rates == null) return const [];

    final met = evaluateAlerts(alerts, rates);
    if (met.isEmpty) return const [];
    final recorded = await _watchlist.markTriggered(met, _clock.now());
    if (recorded.isNotEmpty) await _notifier.show(recorded);
    return recorded;
  }
}

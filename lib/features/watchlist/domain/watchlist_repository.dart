import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';

/// A currency taken off the watchlist, with everything needed to put it
/// back exactly where it was (undo).
typedef RemovedWatchItem = ({
  String currencyCode,
  int index,
  List<RateAlert> alerts,
});

/// The user's watchlist and its rate alerts. Local only; alerts belong to
/// a watchlist currency and are removed (and restored) with it.
abstract interface class WatchlistRepository {
  /// Codes in display order. Emits again after every change.
  Stream<List<String>> watchCodes();

  /// Appends [code]; no-op if already listed.
  Future<void> add(String code);

  /// Removes [code] and its alerts. Null if it wasn't listed.
  Future<RemovedWatchItem?> remove(String code);

  /// Undoes [remove].
  Future<void> restore(RemovedWatchItem item);

  /// Persists a new order. [codes] must be the current codes, reordered.
  Future<void> reorder(List<String> codes);

  /// All alerts, oldest first. Emits again after every change.
  Stream<List<RateAlert>> watchAlerts();

  /// Enabled, untriggered alerts: what a check needs to evaluate.
  Future<List<RateAlert>> activeAlerts();

  /// Adds an alert, and its currency to the watchlist if missing.
  Future<void> addAlert(NewRateAlert alert);

  Future<void> deleteAlert(int id);

  /// Enabling clears a previous trigger, re-arming the alert.
  Future<void> setAlertEnabled(int id, {required bool enabled});

  /// Records the triggers and disables those alerts. Returns the ones
  /// actually recorded: an alert already triggered elsewhere (the app and
  /// the background worker can race) is skipped, so it notifies once.
  Future<List<AlertTrigger>> markTriggered(
    List<AlertTrigger> triggers,
    DateTime at,
  );
}

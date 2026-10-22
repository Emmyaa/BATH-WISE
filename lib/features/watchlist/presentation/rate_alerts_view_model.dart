import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_providers.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rate_alerts_view_model.g.dart';

/// Whether a new alert was saved, and whether it can notify.
enum AlertSaveResult { saved, savedWithoutPermission }

/// All rate alerts, and the edits on them.
@Riverpod(keepAlive: true)
class RateAlertsViewModel extends _$RateAlertsViewModel {
  @override
  Stream<List<RateAlert>> build() =>
      ref.watch(watchlistRepositoryProvider).watchAlerts();

  /// Asks for notification permission first (the system shows its prompt
  /// once), then saves the alert either way: it still shows in the app.
  Future<AlertSaveResult> add(NewRateAlert alert) async {
    final granted = await ref
        .read(alertNotificationsProvider)
        .requestPermission();
    await ref.read(watchlistRepositoryProvider).addAlert(alert);
    return granted
        ? AlertSaveResult.saved
        : AlertSaveResult.savedWithoutPermission;
  }

  Future<void> delete(int id) =>
      ref.read(watchlistRepositoryProvider).deleteAlert(id);

  /// Turning a triggered alert back on re-arms it.
  Future<void> setEnabled(int id, {required bool enabled}) => ref
      .read(watchlistRepositoryProvider)
      .setAlertEnabled(id, enabled: enabled);
}

/// Alerts of [code], oldest first.
@riverpod
List<RateAlert> alertsFor(Ref ref, String code) => [
  for (final alert
      in ref.watch(rateAlertsViewModelProvider).value ?? const <RateAlert>[])
    if (alert.currencyCode == code) alert,
];

/// Keeps the background check scheduled exactly while some alert is
/// active, and checks alerts whenever new rates or alerts arrive in the
/// app (the worker covers the time the app is closed).
///
/// Watched by the app root so it lives for the whole session.
@Riverpod(keepAlive: true)
Future<void> alertMonitor(Ref ref) async {
  final activeIds = ref.watch(
    rateAlertsViewModelProvider.select(
      (alerts) => alerts.value
          ?.where((a) => a.enabled && !a.isTriggered)
          .map((a) => a.id)
          .join(','),
    ),
  );
  // Rebuild on new data only, not on a refresh's loading state.
  final snapshot = ref.watch(
    latestRatesViewModelProvider.select((rates) => rates.value),
  );
  if (activeIds == null) return;

  await ref
      .read(alertSchedulerProvider)
      .sync(hasActiveAlerts: activeIds.isNotEmpty);
  if (snapshot != null && activeIds.isNotEmpty) {
    await ref.read(alertCheckProvider).run(snapshot);
  }
}

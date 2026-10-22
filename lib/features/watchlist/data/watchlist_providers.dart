import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/features/rates/data/rates_providers.dart';
import 'package:bath_wise/features/watchlist/background/alert_worker.dart';
import 'package:bath_wise/features/watchlist/data/local_alert_notifier.dart';
import 'package:bath_wise/features/watchlist/data/watchlist_repository_impl.dart';
import 'package:bath_wise/features/watchlist/domain/alert_check.dart';
import 'package:bath_wise/features/watchlist/domain/watchlist_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watchlist_providers.g.dart';

@Riverpod(keepAlive: true)
WatchlistRepository watchlistRepository(Ref ref) => WatchlistRepositoryImpl(
  ref.watch(appDatabaseProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
AlertNotifier alertNotifications(Ref ref) =>
    LocalAlertNotifier(FlutterLocalNotificationsPlugin());

@Riverpod(keepAlive: true)
AlertScheduler alertScheduler(Ref ref) => WorkmanagerAlertScheduler();

@Riverpod(keepAlive: true)
AlertCheck alertCheck(Ref ref) => AlertCheck(
  ref.watch(watchlistRepositoryProvider),
  ref.watch(fxRepositoryProvider),
  ref.watch(alertNotificationsProvider),
  ref.watch(clockProvider),
);

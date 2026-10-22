import 'dart:ui';

import 'package:bath_wise/core/money/formatters.dart';
import 'package:bath_wise/core/time/date_formatters.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_type_selector.dart';
import 'package:bath_wise/features/watchlist/domain/alert_check.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Rate-alert notifications via flutter_local_notifications.
///
/// Works without a `BuildContext`, so the background worker can use it:
/// text is localized with the device locale.
class LocalAlertNotifier implements AlertNotifier {
  new(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;

  @override
  Future<void> initialize({void Function(String code)? onTap}) =>
      _initialized ??= _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Ask when the user creates their first alert, not on launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload case final code? when onTap != null) {
            onTap(code);
          }
        },
      );

  @override
  Future<String?> launchedFromCode() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  /// Android 13+ and iOS ask; older Android needs nothing.
  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (_plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
        case final android?) {
      return await android.requestNotificationsPermission() ?? false;
    }
    if (_plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
        case final ios?) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<void> show(List<AlertTrigger> triggers) async {
    await initialize();
    final locale = _deviceLocale();
    final l10n = lookupAppLocalizations(locale);
    final tag = locale.toLanguageTag();
    final text = AlertNotificationText(
      l10n,
      DecimalFormatter(tag),
      DateFormatters(tag),
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'rate_alerts',
        l10n.alertChannelName,
        channelDescription: l10n.alertChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    for (final trigger in triggers) {
      await _plugin.show(
        // One notification per alert: a repeat replaces, never stacks.
        id: trigger.alert.id,
        title: text.title(trigger),
        body: text.body(trigger),
        notificationDetails: details,
        payload: trigger.alert.currencyCode,
      );
    }
  }

  static Locale _deviceLocale() {
    final device = PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == device.languageCode,
    );
    return supported ? Locale(device.languageCode) : const Locale('en');
  }
}

/// Title and body of a triggered-alert notification. Pure for tests.
@visibleForTesting
class AlertNotificationText {
  const new(this._l10n, this._decimals, this._dates);

  final AppLocalizations _l10n;
  final DecimalFormatter _decimals;
  final DateFormatters _dates;

  String title(AlertTrigger t) {
    final rate = _decimals.format(t.rate);
    return switch (t.alert.direction) {
      AlertDirection.above => _l10n.alertNotifyRose(t.alert.currencyCode, rate),
      AlertDirection.below => _l10n.alertNotifyFell(t.alert.currencyCode, rate),
    };
  }

  String body(AlertTrigger t) => _l10n.alertNotifyBody(
    t.alert.rateType.label(_l10n),
    _decimals.format(t.alert.target),
    _dates.date(t.period),
  );
}

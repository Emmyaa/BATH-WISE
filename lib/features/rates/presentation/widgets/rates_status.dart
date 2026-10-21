import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/market_calendar/domain/market_status.dart';
import 'package:bath_wise/features/market_calendar/presentation/market_status_provider.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Official BOT rate as of …", or why the data isn't today's
/// ("Bank holiday (…) — showing rates as of …").
String ratesStatusText(
  BuildContext context,
  RatesSnapshot snapshot,
  MarketStatus? status,
) {
  final l10n = context.l10n;
  final date = context.dates.date(snapshot.asOf);
  if (snapshot.source == RateSource.ecb) return l10n.statusEcb(date);
  return switch (status?.kind) {
    MarketStatusKind.weekend => l10n.statusWeekend(date),
    MarketStatusKind.holiday => l10n.statusHoliday(
      _holidayName(context, status!),
      date,
    ),
    MarketStatusKind.delayed => l10n.statusDelayed(date),
    _ => l10n.statusUpToDate(date),
  };
}

/// "Next update today at 18:00" / "Next update Mon at 18:00"; null when
/// the shown data is already today's.
String? nextUpdateText(
  BuildContext context,
  MarketStatus? status,
  DateTime now,
) {
  if (status == null || status.kind == MarketStatusKind.upToDate) return null;
  final l10n = context.l10n;
  final time = context.dates.bangkokTime(status.nextRelease);
  final day = Bangkok.dateOf(status.nextRelease);
  return day == Bangkok.dateOf(now)
      ? l10n.nextUpdateToday(time)
      : l10n.nextUpdateOn(context.dates.weekday(day), time);
}

String _holidayName(BuildContext context, MarketStatus status) {
  final holiday = status.holiday!;
  final thai = Localizations.localeOf(context).languageCode == 'th';
  return thai && holiday.nameTh.isNotEmpty ? holiday.nameTh : holiday.nameEn;
}

/// Status and next-update lines for a snapshot, styled by the caller.
class RatesStatusLines extends ConsumerWidget {
  const new({required this.snapshot, super.key, this.style});

  final RatesSnapshot snapshot;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(marketStatusProvider).value;
    final next = nextUpdateText(
      context,
      status,
      ref.watch(clockProvider).now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ratesStatusText(context, snapshot, status), style: style),
        if (next != null)
          Text(
            next,
            style: style?.copyWith(
              color: style?.color?.withValues(alpha: 0.75),
            ),
          ),
      ],
    );
  }
}

/// Explains degraded data: offline / refresh failed (cache) / ECB
/// fallback. Renders nothing when the data is fresh.
class DegradedDataBanner extends ConsumerWidget {
  const new({required this.snapshot, super.key});

  final RatesSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = snapshot.refreshFailure;
    if (failure == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final saved = context.dates.updatedAt(
      snapshot.fetchedAt,
      now: ref.watch(clockProvider).now(),
    );
    final (icon, message) = switch (failure) {
      _ when snapshot.source == RateSource.ecb => (
        Icons.public_rounded,
        l10n.bannerEcbFallback,
      ),
      NetworkFailure() => (Icons.wifi_off_rounded, l10n.bannerOffline(saved)),
      _ => (Icons.history_rounded, l10n.bannerStale(saved)),
    };
    return StatusBanner(icon: icon, message: message);
  }
}

import 'package:bath_wise/features/market_calendar/domain/market_calendar.dart';

/// Decides whether cached BOT data must be refetched.
///
/// Rules:
/// 1. Never fetched → fetch.
/// 2. Last fetch was before the latest release → fetch.
/// 3. Fetched after the release but the expected period is still missing
///    (BOT published late, or our calendar missed a holiday) → retry, but
///    at most every [retryInterval] to protect the 200 calls/hour quota.
class RefreshPolicy {
  const new({
    required this.release,
    this.expectsReleaseDatePeriod = true,
    this.retryInterval = const Duration(minutes: 30),
  });

  final ReleaseTime release;

  /// Whether a release on day D carries data for period D. True for daily
  /// exchange rates (verified against real responses).
  final bool expectsReleaseDatePeriod;

  final Duration retryInterval;

  bool needsRefresh({
    required DateTime now,
    required MarketCalendar calendar,
    required DateTime? lastFetchedAt,
    required DateTime? latestCachedPeriod,
  }) {
    if (lastFetchedAt == null) return true;
    final latestRelease = calendar.latestRelease(now, release);
    if (lastFetchedAt.isBefore(latestRelease)) return true;
    if (!expectsReleaseDatePeriod) return false;

    final expected = calendar.latestReleaseDate(now, release);
    final missing =
        latestCachedPeriod == null || latestCachedPeriod.isBefore(expected);
    return missing && now.difference(lastFetchedAt) >= retryInterval;
  }
}

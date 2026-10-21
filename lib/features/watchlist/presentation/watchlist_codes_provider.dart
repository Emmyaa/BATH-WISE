import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watchlist_codes_provider.g.dart';

/// Currencies on the user's watchlist, in display order.
///
/// A fixed starter list for now; Phase 6 backs this with persisted,
/// user-editable data behind the same provider.
@Riverpod(keepAlive: true)
List<String> watchlistCodes(Ref ref) => const [
  'USD',
  'EUR',
  'JPY',
  'GBP',
  'CNY',
  'SGD',
];

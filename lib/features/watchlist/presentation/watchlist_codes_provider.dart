import 'package:bath_wise/features/watchlist/presentation/watchlist_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watchlist_codes_provider.g.dart';

/// Currencies on the user's watchlist, in display order.
///
/// Empty until the stored list has loaded, which is near-instant (local
/// database), so Dashboard and Converter can read it synchronously.
@Riverpod(keepAlive: true)
List<String> watchlistCodes(Ref ref) =>
    ref.watch(watchlistViewModelProvider).value ?? const [];

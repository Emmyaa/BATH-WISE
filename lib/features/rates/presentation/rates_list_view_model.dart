import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rates_list_view_model.freezed.dart';
part 'rates_list_view_model.g.dart';

enum RatesSort { defaultOrder, code, gainers, losers }

@freezed
abstract class RatesListState with _$RatesListState {
  const factory({
    @Default('') String query,
    @Default(RatesSort.defaultOrder) RatesSort sort,
    @Default(RateType.mid) RateType rateType,
  }) = _RatesListState;
}

/// Search, sort and rate-type choices of the Rates screen. Kept alive so
/// they survive tab switches.
@Riverpod(keepAlive: true)
class RatesListViewModel extends _$RatesListViewModel {
  @override
  RatesListState build() => const RatesListState();

  void search(String query) => state = state.copyWith(query: query);

  void sortBy(RatesSort sort) => state = state.copyWith(sort: sort);

  void showRateType(RateType type) => state = state.copyWith(rateType: type);
}

/// The quotes to show for the current search and sort, or null until the
/// rates have loaded.
@riverpod
List<RateQuote>? visibleQuotes(Ref ref) {
  final quotes = ref.watch(latestRatesViewModelProvider).value?.quotes;
  if (quotes == null) return null;
  return filterAndSortQuotes(quotes, ref.watch(ratesListViewModelProvider));
}

/// Pure so it can be unit tested. Matches code and both names,
/// case-insensitively. Quotes without a change sort last.
List<RateQuote> filterAndSortQuotes(
  List<RateQuote> quotes,
  RatesListState state,
) {
  final query = state.query.trim().toLowerCase();
  final matches = query.isEmpty
      ? [...quotes]
      : [
          for (final q in quotes)
            if (q.currencyCode.toLowerCase().contains(query) ||
                q.current.nameEn.toLowerCase().contains(query) ||
                q.current.nameTh.contains(query))
              q,
        ];

  int byChange(RateQuote a, RateQuote b, {required bool descending}) {
    final x = a.changePercent(state.rateType);
    final y = b.changePercent(state.rateType);
    if (x == null || y == null) {
      return (x == null ? 1 : 0) - (y == null ? 1 : 0);
    }
    return descending ? y.compareTo(x) : x.compareTo(y);
  }

  switch (state.sort) {
    case RatesSort.defaultOrder:
      break;
    case RatesSort.code:
      matches.sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
    case RatesSort.gainers:
      matches.sort((a, b) => byChange(a, b, descending: true));
    case RatesSort.losers:
      matches.sort((a, b) => byChange(a, b, descending: false));
  }
  return matches;
}

/// The [count] quotes with the largest absolute mid-rate move.
List<RateQuote> topMovers(List<RateQuote> quotes, {int count = 3}) {
  Decimal magnitude(RateQuote q) =>
      q.changePercent(RateType.mid)?.abs() ?? Decimal.zero;
  return ([...quotes]..sort((a, b) => magnitude(b).compareTo(magnitude(a))))
      .where((q) => magnitude(q) > Decimal.zero)
      .take(count)
      .toList();
}

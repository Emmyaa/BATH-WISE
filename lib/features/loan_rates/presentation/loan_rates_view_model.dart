import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/no_auto_retry.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_providers.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'loan_rates_view_model.freezed.dart';
part 'loan_rates_view_model.g.dart';

/// Per-bank loan rates for the Loan Rates screen.
@Riverpod(keepAlive: true, retry: noAutoRetry)
class LoanRatesViewModel extends _$LoanRatesViewModel {
  @override
  Future<LoanRatesSnapshot> build() async =>
      (await ref
              .watch(loanRatesRepositoryProvider)
              .getLatest(LoanRateKind.bank))
          .getOrThrow();

  /// Pull-to-refresh; see `LatestRatesViewModel.refresh`.
  Future<Failure?> refresh() async {
    final result = await ref
        .read(loanRatesRepositoryProvider)
        .getLatest(LoanRateKind.bank, forceRefresh: true);
    switch (result) {
      case Ok(:final value):
        state = AsyncData(value);
        return value.refreshFailure;
      case Err(:final failure):
        if (!state.hasValue) state = AsyncError(failure, StackTrace.current);
        return failure;
    }
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future.then((_) {}, onError: (_) {});
  }
}

/// Bank name, or one rate lowest first.
enum LoanSort { name, mor, mlr, mrr }

@freezed
abstract class LoanRatesListState with _$LoanRatesListState {
  const factory({
    @Default(LoanSort.mlr) LoanSort sort,

    /// English bank type to show; null shows every type.
    String? bankType,
  }) = _LoanRatesListState;
}

/// Sort and filter choices of the Loan Rates screen.
@Riverpod(keepAlive: true)
class LoanRatesListViewModel extends _$LoanRatesListViewModel {
  @override
  LoanRatesListState build() => const LoanRatesListState();

  void sortBy(LoanSort sort) => state = state.copyWith(sort: sort);

  void filterBankType(String? bankType) =>
      state = state.copyWith(bankType: bankType);
}

/// A bank type, as used by the filter chips.
typedef BankType = ({String en, String th});

/// The bank types present in [rates], in first-seen order (BOT lists
/// domestic banks first).
List<BankType> bankTypesOf(List<LoanRate> rates) {
  final seen = <String, BankType>{};
  for (final rate in rates) {
    if (rate.bankTypeEn case final en? when en.isNotEmpty) {
      seen.putIfAbsent(en, () => (en: en, th: rate.bankTypeTh ?? en));
    }
  }
  return [...seen.values];
}

/// Pure so it can be unit tested. Rates sort lowest first (the better
/// deal for a borrower); banks without that rate sort last, and ties fall
/// back to the name. Names sort in the language they're shown in.
List<LoanRate> filterAndSortLoanRates(
  List<LoanRate> rates,
  LoanRatesListState state, {
  required bool thai,
}) {
  final shown = [
    for (final rate in rates)
      if (state.bankType == null || rate.bankTypeEn == state.bankType) rate,
  ];
  String name(LoanRate r) =>
      thai && r.nameTh.isNotEmpty ? r.nameTh : r.nameEn.toLowerCase();
  int byName(LoanRate a, LoanRate b) => name(a).compareTo(name(b));
  int byRate(LoanRate a, LoanRate b, Decimal? Function(LoanRate) value) {
    final x = value(a);
    final y = value(b);
    if (x == null || y == null) {
      final missing = (x == null ? 1 : 0) - (y == null ? 1 : 0);
      return missing != 0 ? missing : byName(a, b);
    }
    final order = x.compareTo(y);
    return order != 0 ? order : byName(a, b);
  }

  shown.sort(switch (state.sort) {
    LoanSort.name => byName,
    LoanSort.mor => (a, b) => byRate(a, b, (r) => r.mor),
    LoanSort.mlr => (a, b) => byRate(a, b, (r) => r.mlr),
    LoanSort.mrr => (a, b) => byRate(a, b, (r) => r.mrr),
  });
  return shown;
}

import 'package:bath_wise/core/network/no_auto_retry.dart';
import 'package:bath_wise/features/loan_rates/data/loan_rates_providers.dart';
import 'package:bath_wise/features/loan_rates/domain/loan_rate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'average_loan_rates_provider.g.dart';

/// BOT's average MOR/MLR/MRR for the Dashboard card.
@Riverpod(keepAlive: true, retry: noAutoRetry)
Future<LoanRatesSnapshot> averageLoanRates(Ref ref) async =>
    (await ref
            .watch(loanRatesRepositoryProvider)
            .getLatest(LoanRateKind.average))
        .getOrThrow();

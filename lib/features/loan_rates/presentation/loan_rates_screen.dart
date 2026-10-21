import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/widgets/coming_soon_view.dart';
import 'package:flutter/material.dart';

/// Placeholder until Phase 7 (per-bank MOR/MLR/MRR, sort and filter).
class LoanRatesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.loanRatesTitle)),
      body: const ComingSoonView(icon: Icons.account_balance_rounded),
    );
  }
}

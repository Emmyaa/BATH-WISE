import 'package:bath_wise/core/widgets/coming_soon_view.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

class ConverterScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(AppLocalizations.of(context).tabConverter)),
      body: const ComingSoonView(icon: Icons.currency_exchange_rounded),
    );
  }
}

import 'package:bath_wise/core/widgets/coming_soon_view.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

class WatchlistScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(AppLocalizations.of(context).tabWatchlist)),
      body: const ComingSoonView(icon: Icons.star_rounded),
    );
  }
}

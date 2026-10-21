import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/theme/theme_mode_controller.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 1: theme switcher only, so both themes can be reviewed.
/// The full settings screen arrives in Phase 8.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsAppearance, style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_rounded),
                        label: Text(l10n.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded),
                        label: Text(l10n.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded),
                        label: Text(l10n.themeDark),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeControllerProvider.notifier)
                        .select(selection.single),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_type_selector.dart';
import 'package:bath_wise/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Appearance, language, default rate type, app lock and where the data
/// comes from. Every change is saved immediately.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: AppSpacing.screen.copyWith(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            ),
            children: [
              _Section(
                title: l10n.settingsAppearance,
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
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => controller.setThemeMode(s.single),
                ),
              ),
              _Section(
                title: l10n.settingsLanguage,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: '', label: Text(l10n.languageSystem)),
                    // Each language in its own script, as usual for
                    // language pickers.
                    ButtonSegment(value: 'th', label: Text(l10n.languageThai)),
                    ButtonSegment(
                      value: 'en',
                      label: Text(l10n.languageEnglish),
                    ),
                  ],
                  selected: {settings.languageCode ?? ''},
                  onSelectionChanged: (s) => controller.setLanguage(
                    s.single.isEmpty ? null : s.single,
                  ),
                ),
              ),
              _Section(
                title: l10n.settingsRates,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.settingsDefaultRateType,
                      style: context.text.bodyLarge,
                    ),
                    Text(
                      l10n.settingsDefaultRateTypeHint,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    RateTypeSelector(
                      selected: settings.defaultRateType,
                      onSelected: controller.setDefaultRateType,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              _Section(
                title: l10n.settingsSecurity,
                padding: EdgeInsets.zero,
                child: const _AppLockTile(),
              ),
              _Section(
                title: l10n.settingsDataSources,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (icon, title, body) in [
                      (
                        Icons.currency_exchange_rounded,
                        l10n.sourceExchangeTitle,
                        l10n.sourceExchangeBody,
                      ),
                      (
                        Icons.account_balance_rounded,
                        l10n.sourceLoanTitle,
                        l10n.sourceLoanBody,
                      ),
                      (
                        Icons.event_busy_rounded,
                        l10n.sourceHolidaysTitle,
                        l10n.sourceHolidaysBody,
                      ),
                      (
                        Icons.public_rounded,
                        l10n.sourceEcbTitle,
                        l10n.sourceEcbBody,
                      ),
                    ])
                      ListTile(
                        leading: Icon(icon, color: context.colors.primary),
                        title: Text(title),
                        subtitle: Text(body),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: Text(
                  l10n.settingsDisclaimer,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.titleMedium),
          ),
        ),
        GlassCard(padding: padding, child: child),
      ],
    );
  }
}

class _AppLockTile extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      settingsControllerProvider.select((s) => s.appLock),
    );
    // Assume available while checking, so the switch doesn't flicker.
    final available = ref.watch(deviceAuthAvailableProvider).value ?? true;
    final canChange = available || enabled;

    return SwitchListTile(
      secondary: Icon(
        enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
        color: context.colors.primary,
      ),
      title: Text(l10n.settingsAppLock),
      subtitle: Text(
        canChange ? l10n.settingsAppLockHint : l10n.settingsAppLockUnavailable,
      ),
      value: enabled,
      onChanged: canChange
          ? (on) async {
              final messenger = ScaffoldMessenger.of(context);
              final changed = await ref
                  .read(settingsControllerProvider.notifier)
                  .setAppLock(enabled: on, reason: l10n.lockReasonSettings);
              if (!changed) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.settingsAppLockFailed)),
                );
              }
            }
          : null,
    );
  }
}

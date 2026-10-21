import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// Temporary body for tabs whose feature phase hasn't landed yet.
class ComingSoonView extends StatelessWidget {
  const new({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: context.bw.brandGradient.createShader,
                child: Icon(icon, size: 48, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.comingSoon, style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.comingSoonBody,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

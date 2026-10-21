import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:flutter/material.dart';

/// Full-area error with a retry button.
class ErrorStateView extends StatelessWidget {
  const new({
    required this.error,
    required this.onRetry,
    super.key,
    this.title,
  });

  /// A [Failure], or anything else (shown as a generic error).
  final Object error;
  final VoidCallback onRetry;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = error;
    final message = failure is Failure
        ? failure.localized(l10n)
        : l10n.errorGeneric;
    final icon = switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      UnauthorizedFailure() => Icons.lock_outline_rounded,
      RateLimitFailure() => Icons.hourglass_top_rounded,
      _ => Icons.error_outline_rounded,
    };
    return _CenteredMessage(
      icon: icon,
      title: title ?? l10n.errorTitle,
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.retry),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const new({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) =>
      _CenteredMessage(icon: icon, message: message);
}

class _CenteredMessage extends StatelessWidget {
  const new({
    required this.icon,
    required this.message,
    this.title,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            if (title case final t?) ...[
              Text(t, style: context.text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (action case final a?) ...[
              const SizedBox(height: AppSpacing.lg),
              a,
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline notice for degraded data (offline, stale, fallback source).
class StatusBanner extends StatelessWidget {
  const new({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.tertiary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title row for a dashboard section with an optional action.
class SectionHeader extends StatelessWidget {
  const new({required this.title, super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleMedium),
            ),
          ),
          if (actionLabel case final label?)
            TextButton(onPressed: onAction, child: Text(label)),
        ],
      ),
    );
  }
}

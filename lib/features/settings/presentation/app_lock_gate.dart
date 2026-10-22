import 'dart:async';

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/app_background.dart';
import 'package:bath_wise/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Covers the app with a lock screen while [AppLockController] is
/// locked, and tells it when the app goes to and comes back from the
/// background.
///
/// The app stays mounted underneath, so unlocking returns exactly where
/// the user was. While the lock is on, the app switcher shows the lock
/// screen too, not the user's data.
class AppLockGate extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late final AppLifecycleListener _lifecycle;

  /// Hides content in the app switcher; separate from the lock itself.
  var _inBackground = false;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(appLockControllerProvider.notifier);
    _lifecycle = AppLifecycleListener(
      onHide: () {
        controller.onBackgrounded();
        setState(() => _inBackground = true);
      },
      onShow: () {
        controller.onResumed();
        setState(() => _inBackground = false);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockControllerProvider);
    final lockOn = ref.watch(
      settingsControllerProvider.select((s) => s.appLock),
    );
    final cover = locked || (lockOn && _inBackground);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Out of reach (taps, focus, screen readers) while covered.
        ExcludeFocus(
          excluding: cover,
          child: ExcludeSemantics(
            excluding: cover,
            child: IgnorePointer(ignoring: cover, child: widget.child),
          ),
        ),
        if (cover) _LockScreen(locked: locked),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const new({required this.locked});

  /// False when only covering the app switcher snapshot.
  final bool locked;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // Prompt right away, like other banking apps.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  void _unlock() {
    if (!mounted || !widget.locked) return;
    unawaited(
      ref
          .read(appLockControllerProvider.notifier)
          .unlock(context.l10n.lockReason),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      child: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 56,
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.lockTitle,
                      style: context.text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (widget.locked) ...[
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(l10n.lockUnlock),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

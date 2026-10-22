import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/money/decimal_utils.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_models.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_type_selector.dart';
import 'package:bath_wise/features/watchlist/domain/rate_alert.dart';
import 'package:bath_wise/features/watchlist/presentation/rate_alerts_view_model.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The alerts of [code], and a form to add one.
Future<void> showRateAlertsSheet(BuildContext context, String code) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _RateAlertsSheet(code: code),
    );

class _RateAlertsSheet extends ConsumerWidget {
  const new({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alerts = ref.watch(alertsForProvider(code));
    final snapshot = ref.watch(latestRatesViewModelProvider).value;
    return Padding(
      // Keeps the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          Padding(
            padding: AppSpacing.screen,
            child: Semantics(
              header: true,
              child: Text(
                l10n.alertsTitle(code),
                style: context.text.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (alerts.isEmpty)
            Padding(
              padding: AppSpacing.screen.add(
                const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              child: Text(
                l10n.alertsEmpty,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final alert in alerts) _AlertRow(alert: alert),
          const Divider(height: AppSpacing.xl),
          if (snapshot != null) _NewAlertForm(code: code, snapshot: snapshot),
          Padding(
            padding: AppSpacing.screen.add(
              const EdgeInsets.only(top: AppSpacing.md),
            ),
            child: Text(
              l10n.alertsFootnote,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const new({required this.alert});

  final RateAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final viewModel = ref.read(rateAlertsViewModelProvider.notifier);
    final rateType = alert.rateType.label(l10n);
    final target = context.decimals.format(alert.target);
    final rule = switch (alert.direction) {
      AlertDirection.above => l10n.alertRuleAbove(rateType, target),
      AlertDirection.below => l10n.alertRuleBelow(rateType, target),
    };
    final status = switch (alert) {
      RateAlert(triggeredRate: final rate?, triggeredPeriod: final period?) =>
        l10n.alertTriggered(
          context.decimals.format(rate),
          context.dates.date(period),
        ),
      RateAlert(enabled: true) => l10n.alertWaiting,
      _ => l10n.alertPaused,
    };
    return ListTile(
      leading: Icon(
        alert.direction == AlertDirection.above
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        color: alert.isTriggered
            ? context.colors.primary
            : context.colors.onSurfaceVariant,
      ),
      title: Text(rule, style: context.text.titleSmall?.tabular),
      subtitle: Text(status),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: rule,
            child: Switch(
              value: alert.enabled,
              onChanged: (on) => viewModel.setEnabled(alert.id, enabled: on),
            ),
          ),
          IconButton(
            tooltip: l10n.alertDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => viewModel.delete(alert.id),
          ),
        ],
      ),
    );
  }
}

class _NewAlertForm extends ConsumerStatefulWidget {
  const new({required this.code, required this.snapshot});

  final String code;
  final RatesSnapshot snapshot;

  @override
  ConsumerState<_NewAlertForm> createState() => _NewAlertFormState();
}

class _NewAlertFormState extends ConsumerState<_NewAlertForm> {
  final _target = TextEditingController();
  RateType _rateType = RateType.mid;
  var _saving = false;
  var _permissionDenied = false;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Decimal? get _current =>
      widget.snapshot.quoteFor(widget.code)?.current.valueOf(_rateType);

  Decimal? get _targetValue =>
      parseDecimalOrNull(_target.text.replaceAll(',', '').trim());

  AlertDirection? get _direction => switch ((_current, _targetValue)) {
    (final current?, final target?) when target > Decimal.zero =>
      alertDirectionFor(current: current, target: target),
    _ => null,
  };

  Future<void> _save() async {
    final direction = _direction;
    final target = _targetValue;
    if (direction == null || target == null) return;
    setState(() => _saving = true);
    final result = await ref.read(rateAlertsViewModelProvider.notifier).add((
      currencyCode: widget.code,
      direction: direction,
      target: target,
      rateType: _rateType,
    ));
    if (!mounted) return;
    _target.clear();
    setState(() {
      _saving = false;
      _permissionDenied = result == AlertSaveResult.savedWithoutPermission;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _current;
    final direction = _direction;
    final rateType = _rateType.label(l10n);
    final unit = widget.snapshot.quoteFor(widget.code)?.current.unit ?? 1;
    final target = _targetValue;
    final invalid = _target.text.trim().isNotEmpty && direction == null;
    final preview = switch ((direction, target)) {
      (AlertDirection.above, final t?) => l10n.alertPreviewAbove(
        rateType,
        context.decimals.format(t),
      ),
      (AlertDirection.below, final t?) => l10n.alertPreviewBelow(
        rateType,
        context.decimals.format(t),
      ),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screen,
          child: Text(l10n.alertNew, style: context.text.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        RateTypeSelector(
          selected: _rateType,
          midOnly: widget.snapshot.source == RateSource.ecb,
          onSelected: (type) => setState(() => _rateType = type),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: AppSpacing.screen,
          child: TextField(
            controller: _target,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            style: context.text.titleMedium?.tabular,
            decoration: InputDecoration(
              labelText: l10n.alertTargetLabel(
                l10n.perUnits('$unit', widget.code),
              ),
              helperText: current == null
                  ? l10n.alertNoRate(rateType)
                  : l10n.alertCurrent(context.decimals.format(current)),
              errorText: invalid ? l10n.alertInvalidTarget : null,
            ),
          ),
        ),
        if (preview != null)
          Padding(
            padding: AppSpacing.screen.add(
              const EdgeInsets.only(top: AppSpacing.sm),
            ),
            child: Text(preview, style: context.text.bodyMedium),
          ),
        if (_permissionDenied)
          Padding(
            padding: AppSpacing.screen.add(
              const EdgeInsets.only(top: AppSpacing.sm),
            ),
            child: StatusBanner(
              icon: Icons.notifications_off_outlined,
              message: l10n.alertPermissionDenied,
            ),
          ),
        Padding(
          padding: AppSpacing.screen.add(
            const EdgeInsets.only(top: AppSpacing.md),
          ),
          child: FilledButton.icon(
            onPressed: direction == null || _saving ? null : _save,
            icon: const Icon(Icons.add_alert_rounded),
            label: Text(l10n.alertCreate),
          ),
        ),
      ],
    );
  }
}

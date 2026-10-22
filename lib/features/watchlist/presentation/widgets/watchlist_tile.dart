import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/change_indicator.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/domain/rate_quote.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A watchlist row: flag, code/name, mid rate and change, an alerts
/// button and a drag handle.
///
/// The main area reads as one sentence to screen readers (like
/// `RateTile`); the alerts button stays a separate, labelled control.
/// Reordering is announced by `ReorderableListView`'s own actions.
class WatchlistTile extends StatelessWidget {
  const new({
    required this.code,
    required this.quote,
    required this.index,
    required this.activeAlerts,
    required this.heroTag,
    required this.onTap,
    required this.onAlerts,
    required this.onRemove,
    super.key,
  });

  final String code;

  /// Null when the current data has no rate for [code] (e.g. the ECB
  /// fallback, which covers fewer currencies).
  final RateQuote? quote;

  /// Position in the list, for the drag handle.
  final int index;
  final int activeAlerts;
  final Object heroTag;
  final VoidCallback onTap;
  final VoidCallback onAlerts;

  /// Offered as a screen reader action.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rate = quote?.current;
    final mid = rate?.mid;
    final percent = quote?.changePercent(RateType.mid);
    final name = quote == null
        ? context.currencyName(code)
        : context.localizedName(quote!);
    final perUnit = rate == null || rate.unit == 1
        ? ''
        : l10n.perUnits('${rate.unit}', code);
    final valueText = mid == null ? '—' : context.decimals.format(mid);
    final alertsText = l10n.alertsActiveCount(activeAlerts);
    final rateLabel = l10n.a11yRate(
      name,
      valueText,
      perUnit,
      describeChange(context, percent),
    );

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              onTap: onTap,
              label: '$rateLabel. $alertsText',
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.watchlistRemove(code)):
                    onRemove,
              },
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.lg),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.md,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      CurrencyFlag(code: code, heroTag: heroTag),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(code, style: context.text.titleMedium),
                            Text(
                              perUnit.isEmpty ? name : '$name · $perUnit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            valueText,
                            style: context.text.titleMedium?.tabular,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          ChangeIndicator(percent: percent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.alertsTooltip(code),
            onPressed: onAlerts,
            icon: Badge(
              isLabelVisible: activeAlerts > 0,
              label: Text('$activeAlerts'),
              child: Icon(
                activeAlerts > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: l10n.watchlistReorder,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppSpacing.sm,
                  top: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                ),
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

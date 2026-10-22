import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// Mid / Buy sight / Buy TT / Sell. Scrolls horizontally so long Thai
/// labels and large text sizes still fit.
class RateTypeSelector extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelected,
    super.key,
    this.midOnly = false,
    this.padding = AppSpacing.screen,
  });

  final RateType selected;
  final ValueChanged<RateType> onSelected;

  /// ECB fallback data only has mid rates.
  final bool midOnly;

  /// Outer padding of the scrolling row; full-width screens use the
  /// screen gutters.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final type in RateType.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(type.label(l10n)),
                selected: type == selected,
                onSelected: midOnly && type != RateType.mid
                    ? null
                    : (_) => onSelected(type),
              ),
            ),
        ],
      ),
    );
  }
}

extension RateTypeLabel on RateType {
  String label(AppLocalizations l10n) => switch (this) {
    RateType.mid => l10n.rateTypeMid,
    RateType.buyingSight => l10n.rateTypeBuyingSight,
    RateType.buyingTransfer => l10n.rateTypeBuyingTransfer,
    RateType.selling => l10n.rateTypeSelling,
  };
}

import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/rates/domain/currency_info.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:flutter/material.dart';

/// Shows a searchable list of [codes] and returns the picked one, or null
/// if dismissed.
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required List<String> codes,
  required String selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: _CurrencyPicker(codes: codes, selected: selected),
  ),
);

class _CurrencyPicker extends StatefulWidget {
  const new({required this.codes, required this.selected});

  final List<String> codes;
  final String selected;

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  var _query = '';

  bool _matches(String code) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final info = Currencies.byCode(code);
    return code.toLowerCase().contains(query) ||
        (info?.nameEn.toLowerCase().contains(query) ?? false) ||
        (info?.nameTh.contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final codes = widget.codes.where(_matches).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screen,
          child: Semantics(
            header: true,
            child: Text(
              l10n.converterPickCurrency,
              style: context.text.titleLarge,
            ),
          ),
        ),
        Padding(
          padding: AppSpacing.screen.add(
            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          ),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchCurrencies,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: codes.isEmpty
              ? EmptyStateView(
                  icon: Icons.search_off_rounded,
                  message: l10n.noResults(_query.trim()),
                )
              : ListView.builder(
                  itemCount: codes.length,
                  itemBuilder: (context, i) {
                    final code = codes[i];
                    final selected = code == widget.selected;
                    return ListTile(
                      leading: CurrencyFlag(code: code),
                      title: Text(code),
                      subtitle: Text(context.currencyName(code)),
                      selected: selected,
                      trailing: selected
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(code),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

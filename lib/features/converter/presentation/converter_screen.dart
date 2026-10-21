import 'package:bath_wise/core/l10n/l10n_context.dart';
import 'package:bath_wise/core/theme/app_tokens.dart';
import 'package:bath_wise/core/theme/app_typography.dart';
import 'package:bath_wise/core/theme/theme_context.dart';
import 'package:bath_wise/core/widgets/currency_flag.dart';
import 'package:bath_wise/core/widgets/entrance.dart';
import 'package:bath_wise/core/widgets/glass_card.dart';
import 'package:bath_wise/core/widgets/skeleton.dart';
import 'package:bath_wise/core/widgets/state_views.dart';
import 'package:bath_wise/features/converter/presentation/converter_view_model.dart';
import 'package:bath_wise/features/converter/presentation/widgets/amount_keypad.dart';
import 'package:bath_wise/features/converter/presentation/widgets/conversion_pair.dart';
import 'package:bath_wise/features/converter/presentation/widgets/currency_picker_sheet.dart';
import 'package:bath_wise/features/rates/domain/rate_enums.dart';
import 'package:bath_wise/features/rates/presentation/latest_rates_view_model.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_tile.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rate_type_selector.dart';
import 'package:bath_wise/features/rates/presentation/widgets/rates_status.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConverterScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(latestRatesViewModelProvider);
    final view = ref.watch(conversionProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(context.l10n.tabConverter)),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: switch (rates) {
          AsyncValue(hasValue: true) when view != null => _ConverterContent(
            view,
          ),
          AsyncValue(error: final error?) => ErrorStateView(
            error: error,
            onRetry: ref.read(latestRatesViewModelProvider.notifier).retry,
          ),
          _ => const _ConverterSkeleton(),
        },
      ),
    );
  }
}

/// Phone: results scroll above a fixed keypad. Wide screens: results and
/// keypad side by side.
class _ConverterContent extends StatelessWidget {
  const new(this.view);

  final ConversionView view;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.expanded;
        final summary = _Summary(view);
        final input = Padding(
          padding: AppSpacing.screen.add(
            const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
          ),
          child: const _AmountInputPanel(),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: summary),
              SizedBox(width: 400, child: input),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: summary),
            input,
          ],
        );
      },
    );
  }
}

class _Summary extends ConsumerWidget {
  const new(this.view);

  final ConversionView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(converterViewModelProvider.notifier);
    final typed = ref.watch(
      converterViewModelProvider.select((s) => s.input.text),
    );

    Future<void> pick({required bool from}) async {
      final code = await showCurrencyPicker(
        context,
        codes: view.currencies,
        selected: from ? view.from : view.to,
      );
      if (code == null) return;
      if (from) {
        viewModel.selectFrom(code);
      } else {
        viewModel.selectTo(code);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      children: [
        RateTypeSelector(
          selected: view.rateType,
          midOnly: view.snapshot.source == RateSource.ecb,
          onSelected: viewModel.selectRateType,
        ),
        Padding(
          padding: AppSpacing.screen.add(
            const EdgeInsets.only(top: AppSpacing.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              ConversionPair(
                from: view.from,
                to: view.to,
                typed: typed,
                amount: view.amount,
                result: view.result,
                onPickFrom: () => pick(from: true),
                onPickTo: () => pick(from: false),
                onSwap: viewModel.swap,
              ),
              _RateUsed(view),
              DegradedDataBanner(snapshot: view.snapshot),
            ],
          ),
        ),
        if (view.others.isNotEmpty)
          Padding(
            padding: AppSpacing.screen,
            child: SectionHeader(title: context.l10n.converterOtherCurrencies),
          ),
        for (final (i, other) in view.others.indexed)
          Padding(
            key: ValueKey(other.code),
            padding: AppSpacing.screen.add(
              const EdgeInsets.only(bottom: AppSpacing.xs),
            ),
            child: _OtherCurrencyTile(
              view: view,
              other: other,
              onTap: () => viewModel.selectTo(other.code),
            ).entrance(context, i),
          ),
      ],
    );
  }
}

/// "1 USD = 33.4859 THB" with its source, rate type and date, so it's
/// always clear which rate produced the result.
class _RateUsed extends StatelessWidget {
  const new(this.view);

  final ConversionView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = view.snapshot;
    final rateType = view.rateType.label(l10n);
    final muted = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final rate = view.rate;
    final base = Decimal.fromInt(rate?.unit ?? 1);

    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            snapshot.source == RateSource.bot
                ? Icons.verified_rounded
                : Icons.public_rounded,
            size: 20,
            color: context.colors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.converterRateUsed, style: muted),
                if (rate == null)
                  Text(
                    l10n.converterNoRate(rateType),
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.error,
                    ),
                  )
                else
                  Text(
                    '${context.decimals.format(base, digits: 0)} ${view.from}'
                    ' = ${context.decimals.format(rate.rate)} ${view.to}',
                    style: context.text.titleSmall?.tabular,
                  ),
                Text(
                  l10n.converterRateLine(
                    snapshot.source == RateSource.bot
                        ? l10n.sourceBot
                        : l10n.sourceEcb,
                    rateType,
                    context.dates.date(snapshot.asOf),
                  ),
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherCurrencyTile extends StatelessWidget {
  const new({required this.view, required this.other, required this.onTap});

  final ConversionView view;
  final ConvertedAmount other;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = other.amount;
    final amountText = amount == null
        ? '—'
        : context.decimals.format(amount, digits: 2);
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: context.l10n.a11yConversion(
        context.decimals.format(view.amount, digits: 2),
        view.from,
        amountText,
        other.code,
      ),
      excludeSemantics: true,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CurrencyFlag(code: other.code, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(other.code, style: context.text.titleSmall),
                  Text(
                    context.currencyName(other.code),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amountText,
                  style: context.text.titleMedium?.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick amounts and the keypad.
class _AmountInputPanel extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(converterViewModelProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.sm,
      children: [
        Row(
          spacing: AppSpacing.xs,
          children: [
            for (final amount in ConverterViewModel.quickAmounts)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => viewModel.useQuickAmount(amount),
                  child: FittedBox(
                    child: Text(
                      context.decimals.format(
                        Decimal.fromInt(amount),
                        digits: 0,
                      ),
                      style: const TextStyle().tabular,
                    ),
                  ),
                ),
              ),
          ],
        ),
        AmountKeypad(
          onDigit: viewModel.typeDigit,
          onDecimalPoint: viewModel.typeDecimalPoint,
          onBackspace: viewModel.backspace,
          onClear: viewModel.clear,
        ),
      ],
    );
  }
}

class _ConverterSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: const Padding(
        padding: AppSpacing.screen,
        child: Column(
          spacing: AppSpacing.xs,
          children: [
            SkeletonBox(height: 104, radius: AppRadius.lg),
            SkeletonBox(height: 104, radius: AppRadius.lg),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 40),
          ],
        ),
      ),
    );
  }
}

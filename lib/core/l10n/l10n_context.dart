import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/money/formatters.dart';
import 'package:bath_wise/core/time/date_formatters.dart';
import 'package:bath_wise/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get _localeTag => Localizations.localeOf(this).toLanguageTag();

  DecimalFormatter get decimals => _decimalFormatters.putIfAbsent(
    _localeTag,
    () => DecimalFormatter(_localeTag),
  );

  DateFormatters get dates =>
      _dateFormatters.putIfAbsent(_localeTag, () => DateFormatters(_localeTag));
}

// One formatter per locale; building NumberFormat isn't free.
final _decimalFormatters = <String, DecimalFormatter>{};
final _dateFormatters = <String, DateFormatters>{};

extension FailureMessage on Failure {
  /// What to tell the user. Messages from [Failure.message] are for logs.
  String localized(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    RateLimitFailure() => l10n.errorRateLimit,
    NoDataFailure() => l10n.errorNoData,
    ServerFailure() ||
    ParsingFailure() ||
    CacheFailure() ||
    UnexpectedFailure() => l10n.errorGeneric,
  };
}

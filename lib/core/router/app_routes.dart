abstract final class AppRoutes {
  static const dashboard = '/dashboard';
  static const rates = '/rates';
  static const converter = '/converter';
  static const watchlist = '/watchlist';
  static const settings = '/settings';

  /// Full-screen routes above the tab bar.
  static const currencyPattern = '/currency/:code';
  static String currency(String code) => '/currency/$code';
  static const loanRates = '/loan-rates';
}

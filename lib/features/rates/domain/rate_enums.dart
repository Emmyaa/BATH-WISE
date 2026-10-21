/// Where a rate came from. Shown in the UI next to every rate.
enum RateSource {
  /// Bank of Thailand official rates (buy/sell/mid).
  bot,

  /// European Central Bank reference rates via Frankfurter (mid only).
  ecb,
}

/// Which BOT quote to read from an `ExchangeRate`.
enum RateType { buyingSight, buyingTransfer, selling, mid }

/// Granularity of a rate series, matching BOT's four endpoints.
enum Periodicity { daily, monthly, quarterly, annual }

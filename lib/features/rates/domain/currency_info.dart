/// Static metadata for the currencies BOT publishes.
class CurrencyInfo {
  const new(
    this.code,
    this.nameEn,
    this.nameTh, {
    this.region = '',
    this.unit = 1,
  });

  final String code;
  final String nameEn;
  final String nameTh;

  /// ISO 3166 region for the flag (EU for the euro); empty if unknown.
  final String region;

  /// BOT quotes some currencies per 100 or 1,000 units (JPY, IDR).
  final int unit;

  /// Flag emoji built from [region] (regional indicator symbols), or ''.
  String get flag => region.length != 2
      ? ''
      : String.fromCharCodes(region.codeUnits.map((c) => 0x1F1A5 + c));
}

abstract final class Currencies {
  /// The base currency of every BOT rate. Not in [bot].
  static const thb = CurrencyInfo('THB', 'Thai Baht', 'บาท', region: 'TH');

  /// The 19 currencies in BOT's daily response, in BOT's order.
  static const bot = [
    CurrencyInfo('USD', 'US Dollar', 'ดอลลาร์สหรัฐฯ', region: 'US'),
    CurrencyInfo('GBP', 'British Pound', 'ปอนด์สเตอร์ลิง', region: 'GB'),
    CurrencyInfo('EUR', 'Euro', 'ยูโร', region: 'EU'),
    CurrencyInfo('JPY', 'Japanese Yen', 'เยนญี่ปุ่น', region: 'JP', unit: 100),
    CurrencyInfo('HKD', 'Hong Kong Dollar', 'ดอลลาร์ฮ่องกง', region: 'HK'),
    CurrencyInfo('MYR', 'Malaysian Ringgit', 'ริงกิตมาเลเซีย', region: 'MY'),
    CurrencyInfo('SGD', 'Singapore Dollar', 'ดอลลาร์สิงคโปร์', region: 'SG'),
    CurrencyInfo('BND', 'Brunei Dollar', 'ดอลลาร์บรูไน', region: 'BN'),
    CurrencyInfo('PHP', 'Philippine Peso', 'เปโซฟิลิปปินส์', region: 'PH'),
    CurrencyInfo(
      'IDR',
      'Indonesian Rupiah',
      'รูเปียห์อินโดนีเซีย',
      region: 'ID',
      unit: 1000,
    ),
    CurrencyInfo('INR', 'Indian Rupee', 'รูปีอินเดีย', region: 'IN'),
    CurrencyInfo('CHF', 'Swiss Franc', 'ฟรังก์สวิส', region: 'CH'),
    CurrencyInfo('AUD', 'Australian Dollar', 'ดอลลาร์ออสเตรเลีย', region: 'AU'),
    CurrencyInfo(
      'NZD',
      'New Zealand Dollar',
      'ดอลลาร์นิวซีแลนด์',
      region: 'NZ',
    ),
    CurrencyInfo('CAD', 'Canadian Dollar', 'ดอลลาร์แคนาดา', region: 'CA'),
    CurrencyInfo('SEK', 'Swedish Krona', 'โครนาสวีเดน', region: 'SE'),
    CurrencyInfo('DKK', 'Danish Krone', 'โครนเดนมาร์ก', region: 'DK'),
    CurrencyInfo('NOK', 'Norwegian Krone', 'โครนนอร์เวย์', region: 'NO'),
    CurrencyInfo('CNY', 'Chinese Yuan', 'หยวนจีน', region: 'CN'),
  ];

  static final Map<String, CurrencyInfo> _byCode = {
    for (final c in [thb, ...bot]) c.code: c,
  };

  static CurrencyInfo? byCode(String code) => _byCode[code];

  /// Sort key keeping BOT's order; unknown codes go last.
  static int orderOf(String code) {
    final index = bot.indexWhere((c) => c.code == code);
    return index < 0 ? bot.length : index;
  }
}

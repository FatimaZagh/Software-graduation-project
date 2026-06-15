/// Palestinian locale defaults for currency and nationality across Rafeeq UI.
class RafeeqRegionalDefaults {
  RafeeqRegionalDefaults._();

  static const currencyCode = 'ILS';
  static const currencySymbol = '₪';

  static const nationalityEnglish = 'Palestinian';
  static const nationalityArabic = 'فلسطيني';

  static String currencySuffix({required bool isArabic}) => isArabic ? 'شيكل' : currencyCode;

  static String formatAmount(double amount, {required bool isArabic}) {
    final formatted =
        amount.truncateToDouble() == amount ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return '$formatted ${currencySuffix(isArabic: isArabic)}';
  }
}

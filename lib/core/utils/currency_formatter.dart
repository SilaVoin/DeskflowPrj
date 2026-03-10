

/// Russian currency formatter.
///
/// Formats amounts as `1 234,56 ₽` (Russian standard):
/// - Space as thousands separator
/// - Comma as decimal separator
/// - Ruble sign `₽` after the amount
///
/// Usage:
/// ```dart
/// CurrencyFormatter.format(1234.5);   // '1 234,50 ₽'
/// CurrencyFormatter.format(0);        // '0,00 ₽'
/// CurrencyFormatter.format(1000000);  // '1 000 000,00 ₽'
/// CurrencyFormatter.formatCompact(99); // '99 ₽' (no decimals if whole)
/// ```
class CurrencyFormatter {
  CurrencyFormatter._();

  static const String _symbol = '₽';
  static const String _thousandsSep = ' '; // non-breaking thin space is ideal, but regular space for compatibility
  static const String _decimalSep = ',';

  /// Format amount with 2 decimal places: `1 234,56 ₽`
  static String format(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final intPart = _addThousandsSeparator(parts[0]);
    final decPart = parts[1];
    final formatted = '$intPart$_decimalSep$decPart $_symbol';
    return isNegative ? '-$formatted' : formatted;
  }

  /// Compact format — omit decimals if amount is whole: `1 234 ₽`
  ///
  /// Shows 2 decimal places only when there are kopecks.
  static String formatCompact(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    // Check if there are meaningful decimals (kopecks)
    final hasDecimals = (absAmount * 100).round() % 100 != 0;

    if (hasDecimals) {
      return format(amount);
    }

    final intPart = _addThousandsSeparator(absAmount.toInt().toString());
    final formatted = '$intPart $_symbol';
    return isNegative ? '-$formatted' : formatted;
  }

  /// Add thousands separator to integer part string.
  static String _addThousandsSeparator(String intPart) {
    if (intPart.length <= 3) return intPart;

    final buffer = StringBuffer();
    final len = intPart.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(_thousandsSep);
      }
      buffer.write(intPart[i]);
    }
    return buffer.toString();
  }
}

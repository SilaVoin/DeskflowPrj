import 'package:intl/intl.dart';

abstract class CurrencyFormatter {
  static final _compactFormat = NumberFormat.currency(
    locale: 'ru_RU',
    symbol: '\u20bd',
    decimalDigits: 0,
  );

  static final _fullFormat = NumberFormat.currency(
    locale: 'ru_RU',
    symbol: '\u20bd',
    decimalDigits: 2,
  );

  static String formatCompact(double amount) {
    return _compactFormat.format(amount);
  }

  static String formatFull(double amount) {
    return _fullFormat.format(amount);
  }
}

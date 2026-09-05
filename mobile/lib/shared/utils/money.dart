import 'package:intl/intl.dart';

String formatMoney(
  double value, {
  required String currency,
  String? symbol,
}) {
  final displayCurrency =
      (symbol?.trim().isNotEmpty == true) ? symbol!.trim() : currency.trim();
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '$displayCurrency ',
    decimalDigits: 0,
  ).format(value);
}

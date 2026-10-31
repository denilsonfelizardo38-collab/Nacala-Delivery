/// Formatação de valores em meticais (centavos) e datas em português.
library;

const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

/// 45000 -> "450,00 MT"
String formatMoney(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final units = absolute ~/ 100;
  final decimals = (absolute % 100).toString().padLeft(2, '0');
  final digits = units.toString();
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  buffer.write(',');
  buffer.write(decimals);
  buffer.write(' MT');
  return buffer.toString();
}

/// 45000 -> "450,00" (sem moeda, para campos de formulário)
String formatMoneyPlain(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final units = absolute ~/ 100;
  final decimals = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$units,$decimals';
}

/// 4.8 -> "4,8"
String formatRating(num rating) =>
    rating.toStringAsFixed(1).replaceAll('.', ',');

/// 2026-10-30T21:45:00Z -> "30 out · 21:45"
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]} · $hour:$minute';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Converte texto introduzido pelo utilizador em centavos, sem vírgula
/// flutuante: "1.250,50" -> 125050, "450" -> 45000, "450.00" -> 45000.
int? parseMoneyToCents(String input) {
  var text = input.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (text.isEmpty) return null;
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else {
    final dots = '.'.allMatches(text).length;
    if (dots > 1) {
      text = text.replaceAll('.', '');
    } else if (dots == 1) {
      final fraction = text.split('.').last;
      // "1.500" é milhar; "450.00" é decimal.
      if (fraction.length == 3) text = text.replaceAll('.', '');
    }
  }
  final parts = text.split('.');
  if (parts.length > 2) return null;
  final units = parts[0].isEmpty ? '0' : parts[0];
  var decimals = parts.length == 2 ? parts[1] : '';
  if (decimals.length > 2) return null;
  decimals = decimals.padRight(2, '0');
  final unitsValue = int.tryParse(units);
  final decimalsValue = int.tryParse(decimals);
  if (unitsValue == null || decimalsValue == null) return null;
  return unitsValue * 100 + decimalsValue;
}

/// "Cliente Demonstração" -> "CD"
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

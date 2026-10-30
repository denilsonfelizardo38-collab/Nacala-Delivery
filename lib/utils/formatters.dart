/// Formatação de valores em meticais e datas em português.
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

/// 8450 -> "8.450 MT"
String formatMoney(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  buffer.write(' MT');
  return buffer.toString();
}

/// 4.8 -> "4,8"
String formatRating(double rating) =>
    rating.toStringAsFixed(1).replaceAll('.', ',');

/// 2026-10-30 21:45 -> "30 out · 21:45"
String formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${_months[date.month - 1]} · $hour:$minute';
}

/// 2026-10-30 21:45 -> "30 de outubro de 2026 às 21:45"
String formatLongDate(DateTime date) {
  const long = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} de ${long[date.month - 1]} de ${date.year} às $hour:$minute';
}

/// Remove espaços e deixa apenas dígitos (para telefone).
String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

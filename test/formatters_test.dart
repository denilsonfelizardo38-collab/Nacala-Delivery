import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/core/formatters.dart';

void main() {
  group('formatMoney', () {
    test('usa vírgula decimal e ponto de milhar', () {
      expect(formatMoney(0), '0,00 MT');
      expect(formatMoney(530), '5,30 MT');
      expect(formatMoney(8450), '84,50 MT');
      expect(formatMoney(845000), '8.450,00 MT');
      expect(formatMoney(-1200), '-12,00 MT');
    });

    test('formatMoneyPlain não inclui a moeda', () {
      expect(formatMoneyPlain(0), '0,00');
      expect(formatMoneyPlain(123456), '1234,56');
    });
  });

  group('parseMoneyToCents', () {
    test('interpreta formatos usados em Moçambique', () {
      expect(parseMoneyToCents('450'), 45000);
      expect(parseMoneyToCents('450,00'), 45000);
      expect(parseMoneyToCents('1.250,50'), 125050);
      expect(parseMoneyToCents('1.250'), 125000);
      expect(parseMoneyToCents('12,5'), 1250);
      expect(parseMoneyToCents('0,99'), 99);
    });

    test('rejeita valores inválidos', () {
      expect(parseMoneyToCents(''), isNull);
      expect(parseMoneyToCents('abc'), isNull);
      expect(parseMoneyToCents('1,234'), isNull);
      expect(parseMoneyToCents('12,345'), isNull);
    });
  });

  test('initialsOf devolve as iniciais do nome', () {
    expect(initialsOf('Cliente Demonstração'), 'CD');
    expect(initialsOf('Ana'), 'A');
    expect(initialsOf('  '), '?');
  });

  test('formatRating usa vírgula', () {
    expect(formatRating(4.75), '4,8');
    expect(formatRating(5), '5,0');
  });

  test('digitsOnly remove separadores', () {
    expect(digitsOnly('84 123 4567'), '841234567');
    expect(digitsOnly('+258 (84) 123-4567'), '258841234567');
  });
}

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

  group('formatMoneyCompact', () {
    test('omite centavos quando são zero', () {
      expect(formatMoneyCompact(0), '0 MT');
      expect(formatMoneyCompact(8000), '80 MT');
      expect(formatMoneyCompact(45000), '450 MT');
    });

    test('mantém centavos e milhares quando existem', () {
      expect(formatMoneyCompact(4550), '45,50 MT');
      expect(formatMoneyCompact(845000), '8.450 MT');
      expect(formatMoneyCompact(-550), '-5,50 MT');
    });
  });

  group('plural', () {
    test('singular com 1', () {
      expect(plural(1, 'parceiro'), 'parceiro');
      expect(plural(1, 'avaliação'), 'avaliação');
      expect(plural(1, 'item'), 'item');
    });

    test('plural derivado', () {
      expect(plural(3, 'parceiro'), 'parceiros');
      expect(plural(2, 'avaliação'), 'avaliações');
      expect(plural(0, 'unidade'), 'unidades');
    });

    test('plural explícito', () {
      expect(plural(2, 'item', 'itens'), 'itens');
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

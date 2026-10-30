import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/screens/customer/account_screen.dart';
import 'package:nacala_derivery/state/app_state.dart';

/// Ecrã lógico alto (420x1200) para que as listas caibam sem scroll nos testes.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(NacalaDeliveryApp(state: AppState()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cliente vê a página inicial e filtra por categoria', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Olá, vizinho 👋'), findsOneWidget);
    expect(find.text('Cantinho da Baía'), findsOneWidget);

    await tester.tap(find.text('Farmácias'));
    await tester.pumpAndSettle();

    expect(find.text('Farmácia Nacala'), findsOneWidget);
    expect(find.text('Cantinho da Baía'), findsNothing);
  });

  testWidgets('pesquisa filtra locais e pode ser limpa', (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, 'farmácia');
    await tester.pumpAndSettle();
    expect(find.text('Farmácia Nacala'), findsOneWidget);
    expect(find.text('Mercado Central'), findsNothing);

    await tester.tap(find.byTooltip('Limpar pesquisa'));
    await tester.pumpAndSettle();
    expect(find.text('Mercado Central'), findsOneWidget);
  });

  testWidgets('fluxo completo: loja, carrinho, checkout e pedido', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Cantinho da Baía'));
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Adicionar Frango grelhado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ver carrinho · 1 itens'), findsOneWidget);

    await tester.tap(find.textContaining('Ver carrinho'));
    await tester.pumpAndSettle();
    expect(find.text('Carrinho'), findsOneWidget);
    expect(find.text('530 MT'), findsWidgets);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar pedido'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '841234567');
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(find.textContaining('NC-1049'), findsWidgets);
    expect(find.text('Pedido recebido'), findsWidgets);

    await tester.tap(find.textContaining('NC-1049').first);
    await tester.pumpAndSettle();
    expect(find.text('Estado da entrega'), findsOneWidget);
    expect(find.text('Resumo do pedido'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('checkout exige número quando o pagamento é por telemóvel', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Cantinho da Baía'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adicionar Matapa com arroz'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ver carrinho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(
      find.text('Indique um número de telemóvel com 9 dígitos.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('modo demonstração revela os painéis de parceiro e admin', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Conta'));
    await tester.pumpAndSettle();
    expect(find.text('A sua conta'), findsOneWidget);

    final accountList = find
        .descendant(
          of: find.byType(AccountScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      200,
      scrollable: accountList,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Parceiro'), findsOneWidget);
    await tester.tap(find.text('Parceiro'));
    await tester.pumpAndSettle();
    expect(find.text('PAINEL DO PARCEIRO'), findsOneWidget);

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('ADMINISTRAÇÃO'), findsOneWidget);

    await tester.tap(find.text('Cliente'));
    await tester.pumpAndSettle();
    expect(find.text('A sua conta'), findsOneWidget);
  });
}

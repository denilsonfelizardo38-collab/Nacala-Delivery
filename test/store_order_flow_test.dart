import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/customer/store_screen.dart';
import 'package:nacala_derivery/state/app_scope.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('adicionar produto mostra ações para pedir em ecrã pequeno', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = FakeApi()
      ..establishmentDetail = const EstablishmentDetail(
        establishment: Establishment(
          id: 'store-1',
          name: 'Cantinho da Baía',
          slug: 'cantinho-da-baia',
          description: 'Cozinha local',
          address: 'Nacala-Porto',
          phone: '841234567',
          deliveryFeeCents: 8000,
          prepMinutes: 30,
          opensAt: '08:00',
          closesAt: '21:00',
          isOpen: true,
          rating: 4.5,
          reviewCount: 2,
          productCount: 1,
          categoryId: 'cat-1',
          categoryName: 'Restaurantes',
          categorySlug: 'restaurantes',
        ),
        products: [
          Product(
            id: 'product-1',
            establishmentId: 'store-1',
            name: 'Frango grelhado',
            description: 'Frango inteiro com acompanhamento',
            priceCents: 45000,
            category: 'Pratos',
            isAvailable: true,
          ),
        ],
        reviews: [],
      );
    final state = AppState(preferences, api: api);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: StoreScreen(establishmentId: 'store-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsOneWidget);
    await tester.tap(find.text('Avaliações'));
    await tester.pumpAndSettle();
    expect(find.text('Sem avaliações'), findsOneWidget);
    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre Cantinho da Baía'), findsOneWidget);
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'Adicionar');
    // Os botões de contacto (Ligar / Ver no mapa) acrescentam altura ao
    // cabeçalho da loja; garante-se que o cartão fica visível antes de tocar.
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Frango grelhado adicionado ao carrinho.'),
      findsOneWidget,
    );
    expect(find.text('Ver carrinho'), findsOneWidget);
    expect(find.text('1 item no carrinho'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

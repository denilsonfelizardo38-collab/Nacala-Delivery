import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// FASE 8 — painel do parceiro: formulário de produto adaptativo à categoria
/// do estabelecimento e fluxo de eliminação honesto.
///
/// Cobre: sugestões de categoria por tipo de loja (restaurante), selecção
/// "Outra categoria…" com validação obrigatória, payload enviado ao
/// servidor e os dois resultados possíveis da eliminação (apagar vs.
/// apenas desativar quando já há encomendas).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const partner = UserAccount(
    id: 'p1',
    role: 'partner',
    name: 'Mercado Teste',
    email: 'mercado@teste.mz',
    phone: '845556666',
  );

  const establishment = Establishment(
    id: 'est_teste',
    name: 'Mercado Teste',
    slug: 'mercado-teste',
    description: 'Produtos frescos',
    address: 'Bairro Central, Nacala-Porto',
    phone: '845556666',
    deliveryFeeCents: 10000,
    prepMinutes: 20,
    opensAt: '08:00',
    closesAt: '20:00',
    isOpen: true,
    rating: 4.5,
    reviewCount: 3,
    productCount: 1,
    categoryId: 'cat_restaurantes',
    categoryName: 'Restaurantes',
    categorySlug: 'restaurantes',
  );

  const seededProduct = Product(
    id: 'prd_sumo',
    establishmentId: 'est_teste',
    name: 'Sumo de manga',
    description: 'Natural, 500 ml',
    priceCents: 12000,
    category: 'Bebidas',
    isAvailable: true,
  );

  /// Entra como parceiro e abre o separador "Produtos".
  Future<FakeApi> openProducts(WidgetTester tester) async {
    final api = FakeApi(user: partner)
      ..loginResult = const AuthResult(token: 'token-partner', user: partner)
      ..partnerEstablishmentResult = establishment
      ..partnerDashboardResult = const PartnerDashboardData(
        establishment: establishment,
        summary: PartnerSummary(
          ordersToday: 1,
          salesTodayCents: 1500,
          pendingOrders: 0,
          activeOrders: 0,
          totalOrders: 4,
          salesTotalCents: 12000,
          rating: 4.5,
          reviewCount: 3,
        ),
        recentOrders: [],
      )
      ..partnerProductsResult = const [seededProduct];

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, api: api);
    await state.login('mercado@teste.mz', 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produtos'));
    await tester.pumpAndSettle();
    expect(find.text('Sumo de manga'), findsOneWidget);
    return api;
  }

  Future<void> openNewProductDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo produto'));
    await tester.pumpAndSettle();
    expect(find.text('Novo produto'), findsWidgets);
  }

  testWidgets('categorias sugeridas seguem o tipo de estabelecimento', (
    tester,
  ) async {
    final api = await openProducts(tester);
    await openNewProductDialog(tester);

    // Restaurante → começa já numa categoria típica.
    expect(find.text('Pratos'), findsOneWidget);

    // O campo de categoria fica por baixo da dobra do dialogo — trazê-lo
    // à vista antes de tocar (a área visível é limitada em testes).
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Sobremesas'), findsOneWidget);
    expect(find.text('Outra categoria…'), findsOneWidget);

    await tester.tap(find.text('Bebidas').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sumo de laranja');
    await tester.enterText(fields.at(1), 'Fruta espremida na hora');
    await tester.enterText(fields.at(2), '150');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = api.lastSavedProduct;
    expect(saved, isNotNull, reason: 'produto enviado ao servidor');
    expect(api.lastSavedProductId, isNull, reason: 'criação, não edição');
    expect(saved!.name, 'Sumo de laranja');
    expect(saved.category, 'Bebidas');
    expect(saved.priceCents, 15000);
  });

  testWidgets('categoria própria ("Outra categoria…") exige texto', (
    tester,
  ) async {
    final api = await openProducts(tester);
    await openNewProductDialog(tester);

    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outra categoria…').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova categoria'), findsOneWidget);

    // Sem texto → validação bloqueia o envio.
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Indique a categoria do menu.'), findsOneWidget);
    expect(api.lastSavedProduct, isNull);
    expect(find.text('Nova categoria'), findsOneWidget, reason: 'dialogo aberto');

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Caril de amendoim');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(4), 'Pratos do dia');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = api.lastSavedProduct;
    expect(saved, isNotNull);
    expect(saved!.category, 'Pratos do dia');
    expect(saved.priceCents, 25000);
  });

  testWidgets('editar produto mantém a categoria actual no dropdown', (
    tester,
  ) async {
    final api = await openProducts(tester);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar produto'), findsOneWidget);
    // Categoria legada/actual continua seleccionável mesmo fora das
    // sugestões — aqui 'Bebidas' já é sugestão de restaurante.
    expect(find.text('Bebidas'), findsWidgets);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(api.lastSavedProductId, 'prd_sumo', reason: 'edição, não criação');
    expect(api.lastSavedProduct!.category, 'Bebidas');
    expect(api.lastSavedProduct!.name, 'Sumo de manga');
  });

  testWidgets('eliminar avisa que o produto é removido do menu', (tester) async {
    final api = await openProducts(tester);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar produto'), findsOneWidget);
    expect(
      find.textContaining('desativado para preservar o histórico'),
      findsOneWidget,
    );

    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(api.lastDeletedProductId, 'prd_sumo');
    expect(find.text('Produto eliminado.'), findsOneWidget);
    expect(find.text('Sumo de manga'), findsNothing);
  });

  testWidgets('produto já usado em encomendas fica apenas desativado', (
    tester,
  ) async {
    final api = await openProducts(tester)
      ..deleteProductResult = true;

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(api.lastDeletedProductId, 'prd_sumo');
    expect(
      find.text('Produto desativado (já tinha encomendas).'),
      findsOneWidget,
    );
  });
}

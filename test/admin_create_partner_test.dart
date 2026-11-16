import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fake_image_picker.dart';

/// FASE 13 — Registo de parceiro pela administração.
///
/// Cobre: NUIT obrigatório de 9 dígitos e a fotografia escolhida como
/// **ficheiro** (galeria) e carregada para a API, em vez de um link colado
/// manualmente.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const admin = UserAccount(
    id: 'a1',
    role: 'admin',
    name: 'Admin Teste',
    email: 'admin@teste.mz',
    phone: '841234567',
  );

  /// PNG de 1×1 usado como fotografia do estabelecimento nos testes.
  const tinyPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQ'
      'GAhKmMIQAAAABJRU5ErkJggg==';

  FakeApi buildApi() => FakeApi(user: admin)
    ..loginResult = const AuthResult(token: 'token-admin', user: admin)
    ..adminSummaryResult = const AdminSummary(
      customers: 3,
      partners: 4,
      couriers: 1,
      activePartners: 4,
      pendingPartners: 1,
      totalOrders: 5,
      ordersInProgress: 0,
      salesTotalCents: 100000,
      salesTodayCents: 50000,
      ordersToday: 2,
      recentOrders: [],
      pendingEstablishments: [],
    )
    ..categoriesResult = const [
      Category(id: 'cat_lojas', name: 'Lojas', slug: 'lojas', icon: 'shop'),
    ];

  /// Entra como administrador e abre o formulário «Registar parceiro».
  Future<void> openCreatePartner(WidgetTester tester, FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, api: api);
    await state.login(admin.email, 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tabFinder = find.byTooltip('Parceiros');
    await tester.tap(
      tabFinder.evaluate().isNotEmpty ? tabFinder : find.text('Parceiros'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registar parceiro').first);
    await tester.pumpAndSettle();
    expect(find.text('Criar parceiro'), findsOneWidget);
  }

  /// Preenche os campos obrigatórios, deixando o NUIT vazio.
  Future<void> fillPartnerForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Gestor Teste');
    await tester.enterText(fields.at(1), 'gestor@nacala.co.mz');
    await tester.enterText(fields.at(2), '846666668');
    await tester.enterText(fields.at(3), 'Parceiro123');
    await tester.enterText(fields.at(4), 'Loja do Gestor');
    await tester.enterText(fields.at(6), 'Bairro Central, Nacala-Porto');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lojas').last);
    await tester.pumpAndSettle();
  }

  testWidgets('registar parceiro exige NUIT e carrega a fotografia', (
    tester,
  ) async {
    final api = buildApi();
    await openCreatePartner(tester, api);

    // Fotografia escolhida na galeria: seletor simulado devolve a imagem
    // em memória (os testes de widget não têm I/O de disco real).
    mockImagePicker(base64Decode(tinyPng));

    await fillPartnerForm(tester);
    await tester.enterText(
      find.byType(TextFormField).at(8),
      '400012345',
    );

    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();
    // A pré-visualização usa a fotografia escolhida, não um link.
    expect(find.byType(Image), findsWidgets);

    await tester.ensureVisible(find.text('Criar parceiro'));
    await tester.tap(find.text('Criar parceiro'));
    await tester.pumpAndSettle();

    expect(find.text('Parceiro registado com acesso ativo.'), findsOneWidget);

    final created = api.lastAdminPartner!;
    expect(created['nuit'], '400012345');
    expect(
      created['image_url'],
      startsWith('https://teste.nacala.delivery/uploads/'),
      reason: 'a foto vem do upload de ficheiro, não de um link colado',
    );
  });

  testWidgets('NUIT inválido bloqueia o registo do parceiro', (tester) async {
    final api = buildApi();
    await openCreatePartner(tester, api);

    await fillPartnerForm(tester);
    // NUIT com menos de 9 dígitos.
    await tester.enterText(find.byType(TextFormField).at(8), '12345');

    await tester.ensureVisible(find.text('Criar parceiro'));
    await tester.tap(find.text('Criar parceiro'));
    await tester.pumpAndSettle();

    expect(api.lastAdminPartner, isNull);
    expect(find.text('NUIT inválido (9 dígitos).'), findsOneWidget);
  });
}

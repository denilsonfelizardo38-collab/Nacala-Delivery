import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fake_image_picker.dart';

/// FASE 5 — candidatura de estabelecimento e estado da candidatura.
///
/// Cobre o fluxo público: Home → CRIAR CONTA → ESTABELECIMENTO →
/// formulário completo → ENVIAR PARA APROVAÇÃO, e o ecrã de estado que o
/// candidato pendente vê (também usado como painel enquanto a conta não
/// está aprovada).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> newState(FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return AppState(prefs, api: api);
  }

  final application = Application(
    id: 'app_1234567890abcd',
    kind: 'establishment',
    status: 'pending',
    name: 'Cantinho Teste',
    email: '841112222@estabelecimentos.nacala.delivery',
    phone: '841112222',
    payload: const {'establishment_name': 'Cantinho Teste'},
    createdAt: DateTime.utc(2026, 11, 12),
    updatedAt: DateTime.utc(2026, 11, 12),
  );
  /// Abre a app em modo convidado e navega até ao formulário de
  /// estabelecimento (Home → CRIAR CONTA → ESTABELECIMENTO).
  Future<void> openEstablishmentForm(WidgetTester tester, FakeApi api) async {
    final state = await newState(api);
    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    // O gate mantém a splash durante a animação de marca (1850 ms).
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(430, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-estabelecimento')));
    await tester.pumpAndSettle();
    expect(find.text('Registar estabelecimento'), findsOneWidget);
  }

  testWidgets(
    'candidatura de estabelecimento envia o formulário completo para aprovação',
    (tester) async {
      final api = FakeApi()
        ..categoriesResult = const [
          Category(
            id: 'cat_restaurantes',
            name: 'Restaurantes',
            slug: 'restaurantes',
            icon: 'restaurant',
          ),
          Category(id: 'cat_lojas', name: 'Lojas', slug: 'lojas', icon: 'shop'),
        ]
        ..applicationResult = application;

      await openEstablishmentForm(tester, api);

      // O título do ecrã e o botão de envio estão presentes.
      expect(find.text('ENVIAR PARA APROVAÇÃO'), findsOneWidget);

      // Formulário: nome do estabelecimento, NUIT, categoria, morada.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Cantinho Teste',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '400012345');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurantes').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Bairro Central, Nacala-Porto',
      );

      // Dados de contacto e conta (últimos campos do formulário).
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(6), 'Candidato Teste');
      await tester.enterText(fields.at(7), '841112222');
      await tester.enterText(fields.at(10), 'Segura123');
      await tester.enterText(fields.at(11), 'Segura123');

      await tester.ensureVisible(find.byKey(const ValueKey('submit-application')));
      await tester.tap(find.byKey(const ValueKey('submit-application')));
      await tester.pumpAndSettle();

      // Painel de sucesso com estado "pending" e referência.
      expect(find.text('Candidatura enviada!'), findsOneWidget);
      expect(find.text('Em análise'), findsOneWidget);

      // O payload enviado contém os dados validados pelo servidor.
      final submission = api.lastApplicationSubmission!;
      expect(submission['kind'], 'establishment');
      expect(submission['name'], 'Candidato Teste');
      expect(submission['phone'], '841112222');
      final payload = submission['payload'] as Map<String, dynamic>;
      expect(payload['establishment_name'], 'Cantinho Teste');
      expect(payload['nuit'], '400012345');
      expect(payload['category_id'], 'cat_restaurantes');
      expect(payload['address'], 'Bairro Central, Nacala-Porto');
      expect(payload['opens_at'], '08:00');
      expect(payload['closes_at'], '21:00');
      expect(payload['prep_minutes'], 30);
      expect(payload['delivery_fee_cents'], 0);

      // Sem sessão: convidado é levado ao login para acompanhar o estado.
      expect(find.byKey(const ValueKey('goto-login')), findsOneWidget);
    },
  );

  testWidgets('formulário exige NUIT, categoria, morada e palavra-passe', (
    tester,
  ) async {
    final api = FakeApi()
      ..categoriesResult = const [
        Category(
          id: 'cat_lojas',
          name: 'Lojas',
          slug: 'lojas',
          icon: 'shop',
        ),
        Category(
          id: 'cat_restaurantes',
          name: 'Restaurantes',
          slug: 'restaurantes',
          icon: 'restaurant',
        ),
      ];

    await openEstablishmentForm(tester, api);

    await tester.ensureVisible(find.byKey(const ValueKey('submit-application')));
    await tester.tap(find.byKey(const ValueKey('submit-application')));
    await tester.pumpAndSettle();

    // Nada foi enviado e as validações aparecem.
    expect(api.lastApplicationSubmission, isNull);
    expect(find.text('Indica o nome do estabelecimento.'), findsOneWidget);
    expect(find.text('NUIT inválido (9 dígitos).'), findsOneWidget);
    expect(
      find.text('Escolhe a categoria do estabelecimento.'),
      findsOneWidget,
    );
    expect(find.text('Indica a morada do estabelecimento.'), findsOneWidget);
    expect(
      find.text('Usa pelo menos 8 caracteres, com letras e números.'),
      findsWidgets,
    );
  });

  testWidgets('candidato pendente vê o estado em vez do painel bloqueado', (
    tester,
  ) async {
    const pendingPartner = UserAccount(
      id: 'u_pending',
      role: 'partner',
      name: 'Cantinho Pendente',
      email: 'pendente@teste.mz',
      phone: '843334444',
      approvalStatus: 'pending',
    );
    final api = FakeApi(user: pendingPartner)
      ..myApplicationResult = Application(
        id: 'app_abc',
        kind: 'establishment',
        status: 'pending',
        name: 'Cantinho Pendente',
        email: 'pendente@teste.mz',
        phone: '843334444',
        createdAt: DateTime.utc(2026, 11, 12),
        updatedAt: DateTime.utc(2026, 11, 12),
      );

    SharedPreferences.setMockInitialValues({
      'nacala.token.v2': 'token-pending',
      'nacala.user.v2':
          '{"id":"u_pending","role":"partner","name":"Cantinho Pendente",'
          '"email":"pendente@teste.mz","phone":"843334444",'
          '"approval_status":"pending"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final appState = AppState(prefs, api: api);

    await tester.pumpWidget(NacalaDeliveryApp(state: appState));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // A shell abre no estado da candidatura, não no painel do parceiro.
    expect(appState.isSignedIn, isTrue);
    expect(find.text('Candidatura'), findsOneWidget);
    expect(find.text('Estado da candidatura'), findsOneWidget);
    expect(find.text('Em análise'), findsWidgets);
    // O painel do parceiro nunca é apresentado a uma conta pendente.
    expect(find.text('Painel'), findsNothing);
  });


  /// PNG de 1×1 usado como fotografia de documento nos testes.
  const tinyPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQ'
      'GAhKmMIQAAAABJRU5ErkJggg==';

  /// Navega até ao formulário de candidatura a entregador.
  Future<void> openCourierForm(WidgetTester tester, FakeApi api) async {
    final state = await newState(api);
    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(430, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-entregador')));
    await tester.pumpAndSettle();
    expect(find.text('Ser entregador'), findsOneWidget);
  }

  /// Preenche os campos do formulário do entregador (sem documentos).
  Future<void> fillCourierForm(WidgetTester tester) async {
    // NUIT (0), zona (1), notas (2), nome (3), telefone (4), passe (7 e 8).
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '400099887');
    await tester.enterText(fields.at(1), 'Mucipal, Nacala-Porto');
    await tester.enterText(fields.at(2), 'Disponível de manhã.');
    await tester.enterText(fields.at(3), 'Estafeta Teste');
    await tester.enterText(fields.at(4), '842223333');
    await tester.enterText(fields.at(7), 'Segura123');
    await tester.enterText(fields.at(8), 'Segura123');

    // Focar o último campo pode disparar uma auto-rolagem animada; enquanto
    // ela corre o conteúdo ignora toques, por isso esperamos que termine.
    await tester.pumpAndSettle();

    final dd = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dd);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mota').last);
    await tester.pumpAndSettle();
  }

  testWidgets('entregador envia NUIT e os quatro documentos obrigatórios', (
    tester,
  ) async {
    final api = FakeApi()
      ..applicationResult = Application(
        id: 'app_courier_1',
        kind: 'delivery',
        status: 'pending',
        name: 'Estafeta Teste',
        email: '842223333@entregadores.nacala.delivery',
        phone: '842223333',
        payload: const {'vehicle_type': 'Mota'},
        createdAt: DateTime.utc(2026, 11, 13),
        updatedAt: DateTime.utc(2026, 11, 13),
      );

    // Fotografia escolhida: seletor simulado devolve a imagem em memória
    // (os testes de widget não têm I/O de disco real).
    mockImagePicker(base64Decode(tinyPng));

    await openCourierForm(tester, api);
    await fillCourierForm(tester);

    // Os quatro documentos: selfie, B.I (frente e verso) e carta de condução.
    for (final label in const [
      'Selfie',
      'B.I — frente',
      'B.I — verso',
      'Carta de condução',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar fotografia'));
      await tester.pumpAndSettle();
      expect(find.text('$label ✓'), findsOneWidget);
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey('submit-application')),
    );
    await tester.tap(find.byKey(const ValueKey('submit-application')));
    await tester.pumpAndSettle();

    expect(find.text('Candidatura enviada!'), findsOneWidget);

    // As quatro imagens foram carregadas e seguem no payload, em caminhos
    // `/uploads/…` aceites pelo servidor.
    expect(api.applicationImageUploads, 4);
    final submission = api.lastApplicationSubmission!;
    expect(submission['kind'], 'delivery');
    final payload = submission['payload'] as Map<String, dynamic>;
    expect(payload['nuit'], '400099887');
    // Veículo e zona de cobertura continuam no payload (FASE 5).
    expect(payload['vehicle_type'], 'Mota');
    expect(payload['address'], 'Mucipal, Nacala-Porto');
    expect(payload['notes'], 'Disponível de manhã.');
    final documents = payload['documents'] as Map<String, dynamic>;
    expect(
      documents.keys,
      containsAll(['selfie', 'bi_front', 'bi_back', 'license']),
    );
    expect(
      [for (final value in documents.values) '$value']
          .every((path) => path.startsWith('/uploads/')),
      isTrue,
    );
  });

  testWidgets('entregador não candidata sem os quatro documentos', (
    tester,
  ) async {
    final api = FakeApi();
    await openCourierForm(tester, api);
    await fillCourierForm(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('submit-application')));
    await tester.tap(find.byKey(const ValueKey('submit-application')));
    await tester.pumpAndSettle();

    // Nada foi enviado: a validação lista os documentos em falta.
    expect(api.lastApplicationSubmission, isNull);
    expect(
      find.text(
        'Falta fotografar: Selfie, B.I — frente, B.I — verso, '
        'Carta de condução.',
      ),
      findsOneWidget,
    );
  });
}

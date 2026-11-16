import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// FASE 7 — Gestão de Registos (admin).
///
/// Cobre: abertura do separador, contagens por estado, filtros de estado e
/// tipo, detalhe com os dados do formulário e as três decisões (aprovar,
/// pedir correções com nota obrigatória, recusar).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const admin = UserAccount(
    id: 'a1',
    role: 'admin',
    name: 'Admin Teste',
    email: 'admin@teste.mz',
    phone: '841234567',
  );

  final pendingApplication = Application(
    id: 'app_pend_1',
    kind: 'establishment',
    status: 'pending',
    name: 'Cantinho Teste',
    email: '845550001@estabelecimentos.nacala.delivery',
    phone: '845550001',
    payload: const {
      'establishment_name': 'Cantinho Teste',
      'category_id': 'cat_restaurantes',
      'address': 'Bairro Central, Nacala-Porto',
      'description': 'Comida caseira',
      'opens_at': '08:00',
      'closes_at': '21:00',
      'delivery_fee_cents': 15000,
      'prep_minutes': 25,
    },
    createdAt: DateTime.utc(2026, 11, 13),
    updatedAt: DateTime.utc(2026, 11, 13),
  );

  final approvedApplication = Application(
    id: 'app_pend_1',
    kind: 'establishment',
    status: 'approved',
    name: 'Cantinho Teste',
    email: '845550001@estabelecimentos.nacala.delivery',
    phone: '845550001',
    payload: pendingApplication.payload,
    createdAt: DateTime.utc(2026, 11, 13),
    updatedAt: DateTime.utc(2026, 11, 14),
  );

  final changesApplication = Application(
    id: 'app_chang_2',
    kind: 'delivery',
    status: 'changes_requested',
    name: 'Estafeta Teste',
    email: '845550002@entregadores.nacala.delivery',
    phone: '845550002',
    adminNote: 'Falta a zona de cobertura.',
    payload: const {
      'vehicle_type': 'Mota',
      'address': 'Mucipal, Nacala-Porto',
    },
    createdAt: DateTime.utc(2026, 11, 12),
    updatedAt: DateTime.utc(2026, 11, 13),
  );

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
      Category(
        id: 'cat_restaurantes',
        name: 'Restaurantes',
        slug: 'restaurantes',
        icon: 'restaurant',
      ),
    ]
    ..adminApplicationsResult = (
      applications: [pendingApplication, changesApplication],
      counts: {
        'pending': 1,
        'changes_requested': 1,
        'approved': 0,
        'rejected': 0,
      },
    );

  /// Entra como administrador e abre o separador "Registos".
  Future<void> openRegistos(WidgetTester tester, FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, api: api);
    await state.login('admin@teste.mz', 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Em ecrãs estreitos a administração usa o rail de ícones — o rótulo
    // está no Tooltip (mesmo padrão do teste existente com "Conta").
    await tester.tap(find.byTooltip('Registos'));
    await tester.pumpAndSettle();
    expect(find.text('Gestão de Registos'), findsOneWidget);
  }

  testWidgets('lista com contagens, filtros e detalhe da candidatura', (
    tester,
  ) async {
    final api = buildApi();
    await openRegistos(tester, api);

    // Contagens por estado vindas do servidor.
    expect(find.text('Em análise · 1'), findsOneWidget);
    expect(find.text('Correções · 1'), findsOneWidget);
    expect(find.text('Aprovadas · 0'), findsOneWidget);

    // Ambas as candidaturas listadas com o resumo.
    expect(find.text('Cantinho Teste'), findsOneWidget);
    expect(find.text('Estafeta Teste'), findsOneWidget);
    expect(find.text('Estabelecimento • Restaurantes'), findsOneWidget);

    // Filtro de tipo chega ao servidor.
    await tester.tap(find.text('Entregadores'));
    await tester.pumpAndSettle();
    expect(api.lastAdminApplicationsFilter, '|delivery');

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(api.lastAdminApplicationsFilter, '|');

    // Detalhe: dados completos do formulário de estabelecimento.
    await tester.tap(find.text('Cantinho Teste'));
    await tester.pumpAndSettle();
    expect(find.text('Estabelecimento • Em análise'), findsOneWidget);
    expect(find.text('Bairro Central, Nacala-Porto'), findsOneWidget);
    expect(find.text('150 MZN'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('08:00 – 21:00'), findsOneWidget);
    // Candidatura em análise mostra as três decisões.
    expect(find.byKey(const ValueKey('review-approve')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-changes')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-reject')), findsOneWidget);
  });

  testWidgets('aprovar leva a decisão ao servidor', (tester) async {
    final api = buildApi()
      ..applicationReviewResult = approvedApplication;
    await openRegistos(tester, api);

    await tester.tap(find.text('Cantinho Teste'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-approve')));
    await tester.pumpAndSettle();

    expect(find.text('Aprovar candidatura'), findsOneWidget);
    // Nota opcional: aprova de imediato.
    await tester.tap(find.text('APROVAR').last);
    await tester.pumpAndSettle();

    expect(api.lastApplicationReview, 'approve:app_pend_1:');
    expect(find.text('Candidatura aprovada. Conta e painel desbloqueados.'),
        findsOneWidget);
  });

  testWidgets('pedir correções exige nota obrigatória', (tester) async {
    final api = buildApi()
      ..applicationReviewResult = Application(
        id: 'app_pend_1',
        kind: 'establishment',
        status: 'changes_requested',
        name: 'Cantinho Teste',
        email: '845550001@estabelecimentos.nacala.delivery',
        phone: '845550001',
        adminNote: 'Falta a coordenada no mapa.',
        payload: pendingApplication.payload,
        createdAt: DateTime.utc(2026, 11, 13),
        updatedAt: DateTime.utc(2026, 11, 14),
      );
    await openRegistos(tester, api);

    await tester.tap(find.text('Cantinho Teste'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-changes')));
    await tester.pumpAndSettle();

    expect(find.text('Pedir correções'), findsOneWidget);
    await tester.tap(find.text('ENVIAR PEDIDO'));
    await tester.pumpAndSettle();

    // Nota vazia → erro e o dialogo mantém-se aberto.
    expect(
      find.text('Indica o que o candidato deve corrigir.'),
      findsOneWidget,
    );
    expect(api.lastApplicationReview, isNull);

    await tester.enterText(find.byType(TextField), 'Falta a coordenada.');
    await tester.tap(find.text('ENVIAR PEDIDO'));
    await tester.pumpAndSettle();

    expect(api.lastApplicationReview, 'changes:app_pend_1:Falta a coordenada.');
    expect(find.text('Correções pedidas ao candidato.'), findsOneWidget);
  });

  testWidgets('candidatura já avaliada não mostra ações', (tester) async {
    final api = buildApi()
      ..adminApplicationsResult = (
        applications: [approvedApplication],
        counts: {'pending': 0, 'changes_requested': 0, 'approved': 1, 'rejected': 0},
      );
    await openRegistos(tester, api);

    expect(find.text('Aprovadas · 1'), findsOneWidget);
    await tester.tap(find.text('Cantinho Teste'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-approve')), findsNothing);
    expect(
      find.text('Candidatura aprovada — sem ações pendentes.'),
      findsOneWidget,
    );
  });
}

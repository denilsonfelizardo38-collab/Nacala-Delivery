import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// FASE 10 — Gestão de funcionários (admin) e separadores do funcionário.
///
/// Cobre: abertura do separador "Funcionários", listagem com nível e
/// permissões, criação com nível/permissões, edição, desativação e
/// eliminação; e o painel do funcionário, que só mostra os separadores
/// correspondentes às permissões da conta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const admin = UserAccount(
    id: 'a1',
    role: 'admin',
    name: 'Admin Teste',
    email: 'admin@teste.mz',
    phone: '841234567',
  );

  final employee = AdminEmployee(
    id: 'emp_1',
    userId: 'usr_emp_1',
    name: 'Operador Loja',
    email: 'operador@nacala.co.mz',
    phone: '845200001',
    level: 'staff',
    permissions: const ['orders', 'customers'],
    createdAt: DateTime.utc(2026, 11, 13),
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
    ..adminEmployeesResult = [employee];

  /// Entra com [user] e abre o separador [tooltip] (rail estreito).
  Future<void> openTab(
    WidgetTester tester,
    FakeApi api,
    UserAccount user,
    String tooltip,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, api: api);
    await state.login(user.email, 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Em ecrãs estreitos a administração usa o rail com Tooltip; a barra
    // inferior (cliente/funcionário) usa Text — o teste aceita ambos.
    final tabFinder = find.byTooltip(tooltip);
    await tester.tap(tabFinder.evaluate().isNotEmpty
        ? tabFinder
        : find.text(tooltip));
    await tester.pumpAndSettle();
  }

  testWidgets('admin abre Funcionários e vê nível, estado e permissões', (
    tester,
  ) async {
    final api = buildApi();
    await openTab(tester, api, admin, 'Funcionários');

    expect(find.text('Funcionários'), findsWidgets);
    expect(find.text('Operador Loja'), findsOneWidget);
    expect(find.text('operador@nacala.co.mz · 845200001'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Ativo'), findsOneWidget);
    // Permissões traduzidas a partir do mapa partilhado.
    expect(find.text('Encomendas'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Desativar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
  });

  testWidgets('criar funcionário envia nível e permissões escolhidas', (
    tester,
  ) async {
    final api = buildApi();
    await openTab(tester, api, admin, 'Funcionários');

    await tester.tap(find.byTooltip('Novo funcionário'));
    await tester.pumpAndSettle();

    expect(find.text('Novo funcionário'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nova Empregada');
    await tester.enterText(fields.at(1), 'nova@nacala.co.mz');
    await tester.enterText(fields.at(2), '845200009');
    await tester.enterText(fields.at(3), 'Segura123');

    // Nível: Gestor (o "Staff" também está no cartão ao fundo, por isso se
    // restringe ao próprio dropdown).
    await tester.tap(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String>),
        matching: find.text('Staff'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestor').last);
    await tester.pumpAndSettle();

    // Permissão "Gestão de registos" (fim do diálogo: garantir visibilidade).
    final permissionTile = find.text('Gestão de registos');
    await tester.ensureVisible(permissionTile);
    await tester.pumpAndSettle();
    await tester.tap(permissionTile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar funcionário'));
    await tester.pumpAndSettle();

    final created = api.adminEmployeesResult.last;
    expect(created.name, 'Nova Empregada');
    expect(created.level, 'admin');
    expect(created.permissions, ['applications']);
    expect(
      find.text(
        'Funcionário criado. Já pode entrar com as permissões escolhidas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('desativar e eliminar pedem confirmação e atualizam a lista', (
    tester,
  ) async {
    final api = buildApi();
    await openTab(tester, api, admin, 'Funcionários');

    // Desativar: diálogo destrutivo → confirma → estado refletido.
    await tester.tap(find.text('Desativar'));
    await tester.pumpAndSettle();
    expect(find.text('Desativar funcionário'), findsOneWidget);
    await tester.tap(find.text('Desativar').last);
    await tester.pumpAndSettle();
    expect(api.adminEmployeesResult.single.isActive, isFalse);
    expect(find.text('Inativo'), findsOneWidget);
    expect(find.text('Reativar'), findsOneWidget);

    // Eliminar: confirmação → some da lista.
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar funcionário'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(api.adminEmployeesResult, isEmpty);
    expect(find.text('Sem funcionários'), findsOneWidget);
  });

  testWidgets('funcionário só vê os separadores das suas permissões', (
    tester,
  ) async {
    const staff = UserAccount(
      id: 'e1',
      role: 'employee',
      name: 'Operador Teste',
      email: 'operador@nacala.co.mz',
      phone: '845200001',
      permissions: ['orders'],
    );
    final api = FakeApi(user: staff)
      ..loginResult = const AuthResult(token: 'token-emp', user: staff);
    // O funcionário não-admin usa a barra inferior (rótulos em Text).
    await openTab(tester, api, staff, 'Pedidos');

    // Com `orders` vê Pedidos; sem as outras permissões não há Parceiros,
    // Utilizadores nem Registos; a Conta está sempre presente.
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Parceiros'), findsNothing);
    expect(find.text('Utilizadores'), findsNothing);
    expect(find.text('Registos'), findsNothing);
    expect(find.text('Funcionários'), findsNothing);
    expect(find.text('Auditoria'), findsNothing);
    expect(find.text('Painel'), findsNothing);
  });

  testWidgets('funcionário sem permissões só vê a Conta', (tester) async {
    const staff = UserAccount(
      id: 'e2',
      role: 'employee',
      name: 'Sem Permissões',
      email: 'sem@nacala.co.mz',
      phone: '845200002',
      permissions: [],
    );
    final api = FakeApi(user: staff)
      ..loginResult = const AuthResult(token: 'token-emp2', user: staff);
    await openTab(tester, api, staff, 'Conta');

    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Pedidos'), findsNothing);
    expect(find.text('Parceiros'), findsNothing);
  });
}

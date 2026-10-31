import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/splash_screen.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

const _customer = UserAccount(
  id: 'u1',
  role: 'customer',
  name: 'Cliente Teste',
  email: 'cliente@teste.mz',
  phone: '841234567',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> newState(FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return AppState(prefs, api: api);
  }

  testWidgets('o ecrã de arranque mostra a identidade da marca', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(find.text('Nacala Entrega'), findsOneWidget);
    expect(find.text('Entregas locais em Nacala-Porto'), findsOneWidget);
  });

  testWidgets('sem sessão a aplicação apresenta o login', (tester) async {
    final state = await newState(FakeApi());
    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    expect(find.text('Entregas locais em Nacala-Porto'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Entrar na sua conta'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });

  testWidgets('cliente autenticado entra no shell com navegação inferior', (
    tester,
  ) async {
    final api = FakeApi(user: _customer)
      ..loginResult = const AuthResult(token: 'token-123', user: _customer);
    final state = await newState(api);
    await state.login('cliente@teste.mz', 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Olá, Cliente'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Entrar na sua conta'), findsNothing);
  });

  testWidgets('admin tem menu de conta com palavra-passe e logout', (
    tester,
  ) async {
    const admin = UserAccount(
      id: 'a1',
      role: 'admin',
      name: 'Admin Teste',
      email: 'admin@teste.mz',
      phone: '841234567',
    );
    final api = FakeApi(user: admin)
      ..loginResult = const AuthResult(token: 'token-admin', user: admin)
      ..adminSummaryResult = const AdminSummary(
        customers: 3,
        partners: 4,
        couriers: 1,
        activePartners: 4,
        pendingPartners: 0,
        totalOrders: 5,
        ordersInProgress: 0,
        salesTotalCents: 100000,
        salesTodayCents: 50000,
        ordersToday: 2,
        recentOrders: [],
        pendingEstablishments: [],
      );
    final state = await newState(api);
    await state.login('admin@teste.mz', 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Painel de administração'), findsOneWidget);

    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();

    expect(find.text('Alterar palavra-passe'), findsOneWidget);
    expect(find.text('Terminar sessão'), findsOneWidget);
  });
}

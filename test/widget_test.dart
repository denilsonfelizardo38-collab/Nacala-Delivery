import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/data/api_service.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/splash_screen.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:nacala_derivery/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

class _SlowMeApi extends FakeApi {
  @override
  Future<MeData> me() => Completer<MeData>().future;
}

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
    expect(find.text('Nacala\nEntrega'), findsOneWidget);
    expect(find.text('Pedido feito. Entrega garantida!'), findsOneWidget);
  });

  testWidgets('a splash termina mesmo se a API demorar a restaurar sessão', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'nacala.token.v2': 'token-antigo'});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, api: _SlowMeApi());

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    expect(find.byType(SplashScreen), findsOneWidget);

    // O timeout por omissão da revalidação é 12 s (tolera cold start).
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(state.status, SessionStatus.signedOut);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Pedido feito. Entrega garantida!'), findsOneWidget);
  });

  testWidgets('sem sessão apresenta boas-vindas antes do formulário', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi(user: _customer)
      ..loginResult = const AuthResult(token: 'token-123', user: _customer);
    final state = await newState(api);
    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pedido feito. Entrega garantida!'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar Conta'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsNothing);
    expect(tester.getSize(find.byType(AppLogo)), const Size(104, 104));

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido feito. Entrega garantida!'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsNothing);

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'cliente@teste.mz',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'segredo');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Cliente!'), findsOneWidget);
  });

  testWidgets(
    'convidado explora o catálogo mas precisa de conta para pedidos',
    (tester) async {
      final state = await newState(FakeApi());
      await tester.pumpWidget(NacalaDeliveryApp(state: state));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Pedido feito. Entrega garantida!'), findsOneWidget);
      await tester.ensureVisible(find.text('Explorar como convidado'));
      await tester.tap(find.text('Explorar como convidado'));
      await tester.pumpAndSettle();

      expect(state.isGuest, isTrue);
      expect(find.text('Início'), findsOneWidget);
      await tester.tap(find.text('Pedidos'));
      await tester.pumpAndSettle();
      expect(find.text('Os pedidos são da tua conta'), findsOneWidget);
      expect(find.text('Entrar ou criar conta'), findsOneWidget);

      await tester.tap(find.text('Entrar ou criar conta'));
      await tester.pumpAndSettle();
      expect(state.isGuest, isFalse);
      expect(find.text('Pedido feito. Entrega garantida!'), findsOneWidget);
    },
  );

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

    expect(find.text('Olá, Cliente!'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Categorias'), findsWidgets);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Entre na sua conta'), findsNothing);
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

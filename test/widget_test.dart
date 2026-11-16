import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/app.dart';
import 'package:nacala_derivery/data/api_service.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/splash_screen.dart';
import 'package:nacala_derivery/state/app_state.dart';
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
    // Identidade actual: logótipo vermelho + wordmark "Nacala Delivery"
    // e a mota de entrega presente, pronta para atravessar o ecrã.
    expect(find.byIcon(Icons.delivery_dining_rounded), findsOneWidget);
    expect(find.text('Nacala'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(
      tester
          .widgetList<Positioned>(find.byType(Positioned))
          .any((position) => position.width != null),
      isTrue,
      reason: 'a mota de entrega está presente no splash',
    );
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

    // Sem sessão válida a app arranca em modo convidado — vai directamente
    // para a Home (fluxo Splash → Home), nunca para um ecrã de login.
    expect(state.isGuest, isTrue);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsNothing);
  });

  testWidgets('sem sessão abre a Home e leva à seleção de tipo de utilizador', (
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

    // O gate mantém a splash durante a animação de marca (1850 ms).
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Depois do splash: Home directamente, em modo convidado — com os
    // botões ENTRAR / CRIAR CONTA no hero, sem welcome nem login forçado.
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsNothing);

    // ENTRAR → página de seleção do tipo de utilizador.
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('CLIENTE'), findsOneWidget);
    expect(find.text('ESTABELECIMENTO'), findsOneWidget);
    expect(find.text('ENTREGADOR'), findsOneWidget);
    // O registo de administrador/funcionário nunca aparece na área pública.
    expect(find.text('ADMINISTRADOR'), findsNothing);
    expect(find.text('Email ou telefone'), findsNothing);

    // CLIENTE → processo de login do cliente.
    await tester.tap(find.byKey(const ValueKey('role-cliente')));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsOneWidget);

    // Voltar: login → seleção → Home.
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('CLIENTE'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Email ou telefone'), findsNothing);

    // Login completo: o sistema identifica a conta e encaminha para o painel.
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-cliente')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'cliente@teste.mz',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'segredo');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    // Saudação da Home autenticada (sem botões de entrada).
    expect(find.text('Cliente, o que vai pedir hoje?'), findsOneWidget);
    expect(find.text('Criar conta'), findsNothing);
  });

  testWidgets(
    'convidado explora o catálogo mas precisa de conta para pedidos',
    (tester) async {
      final state = await newState(FakeApi());
      await tester.pumpWidget(NacalaDeliveryApp(state: state));
      // O gate mantém a splash durante a animação de marca (1850 ms).
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Sem sessão a app arranca directamente na Home, em modo convidado.
      expect(state.isGuest, isTrue);
      expect(find.text('Início'), findsOneWidget);

      await tester.tap(find.text('Pedidos'));
      await tester.pumpAndSettle();
      expect(find.text('Os pedidos são da tua conta'), findsOneWidget);
      expect(find.text('Entrar ou criar conta'), findsOneWidget);

      // A acção leva à seleção de tipo de utilizador (mantém o convidado
      // até haver login — o carrinho e o estado local não se perdem).
      await tester.tap(find.text('Entrar ou criar conta'));
      await tester.pumpAndSettle();
      expect(state.isGuest, isTrue);
      expect(find.text('CLIENTE'), findsOneWidget);
      expect(find.text('ESTABELECIMENTO'), findsOneWidget);
      expect(find.text('ENTREGADOR'), findsOneWidget);
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
    // O gate mantém o splash durante a animação de marca (1850 ms).
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.text('Cliente, o que vai pedir hoje?'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Categorias'), findsWidgets);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Entre na sua conta'), findsNothing);
    // Sessão iniciada: os botões de entrada desaparecem da Home.
    expect(find.text('Criar conta'), findsNothing);
  });

  testWidgets('a aplicação é sempre escura e não oferece escolha de tema', (
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
    await state.login('cliente@teste.mz', 'segredo');

    await tester.pumpWidget(NacalaDeliveryApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.brightness, Brightness.dark);

    await tester.tap(find.text('Conta'));
    await tester.pumpAndSettle();

    // Sem seletor de tema: a identidade é escura por definição.
    expect(find.text('Tema da aplicação'), findsNothing);
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

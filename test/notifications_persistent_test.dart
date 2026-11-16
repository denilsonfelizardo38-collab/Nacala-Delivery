import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/customer/notifications_screen.dart';
import 'package:nacala_derivery/state/app_scope.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// FASE 12 — Notificações persistentes.
///
/// Cobre: o ecrã lista as notificações do servidor (candidaturas, decisões,
/// mensagens de chat…), marca-as como lidas ao abrir, deduplica mudanças de
/// estado já cobertas pelos eventos do pedido e mantém os eventos reais dos
/// pedidos como fonte complementar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const customer = UserAccount(
    id: 'u1',
    role: 'customer',
    name: 'Cliente Teste',
    email: 'cliente@teste.mz',
    phone: '841234567',
  );

  final orderEventItem = Order(
    id: 'order-1',
    number: 'ND-0001',
    status: 'preparing',
    paymentMethod: 'cash',
    paymentStatus: 'cash_on_delivery',
    subtotalCents: 45000,
    deliveryFeeCents: 8000,
    discountCents: 0,
    totalCents: 53000,
    addressLabel: 'Casa',
    addressLine: 'Rua da Praia, 12',
    phone: '841234567',
    createdAt: DateTime(2026, 11, 3, 8, 30),
    establishment: const MiniEstablishment(
      id: 'store-1',
      name: 'Baía Azul',
      address: 'Nacala-Porto',
      phone: '854011185',
    ),
    items: const [],
    events: [
      OrderEvent(
        status: 'preparing',
        createdAt: DateTime(2026, 11, 3, 8, 35),
        note: 'A tua refeição está a ser preparada.',
      ),
    ],
  );

  FakeApi buildApi({
    List<AppNotification> notifications = const [],
    List<Order> orders = const [],
  }) => FakeApi(user: customer)
    ..loginResult = const AuthResult(token: 'token-1', user: customer)
    ..notificationsResult = notifications
    ..ordersResult = orders;

  Future<AppState> signedInState(FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, api: api);
    await state.login('cliente@teste.mz', 'segredo');
    return state;
  }

  Widget app(AppState state) => AppScope(
    state: state,
    child: const MaterialApp(home: NotificationsScreen()),
  );

  testWidgets('notificação persistente de candidatura aparece e é marcada '
      'como lida', (tester) async {
    final api = buildApi(
      notifications: [
        AppNotification(
          id: 'ntf-1',
          kind: 'application_changes',
          title: 'Precisamos de mais informações',
          body: 'Falta a coordenada no mapa.',
          createdAt: DateTime(2026, 11, 13, 10, 0),
        ),
      ],
    );
    final state = await signedInState(api);

    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Precisamos de mais informações'), findsOneWidget);
    expect(find.text('Falta a coordenada no mapa.'), findsOneWidget);
    // Marca como lidas as que acabou de mostrar (não ficam presas).
    expect(api.markNotificationsReadCalls, [
      ['ntf-1'],
    ]);
    expect(api.notificationsResult.single.isRead, isTrue);
  });

  testWidgets('mudança de estado já coberta pela notificação não duplica', (
    tester,
  ) async {
    final api = buildApi(
      notifications: [
        AppNotification(
          id: 'ntf-2',
          kind: 'order_preparing',
          title: 'Pedido ND-0001 em preparação',
          body: 'A tua refeição está a ser preparada.',
          data: const {'order_id': 'order-1', 'status': 'preparing'},
          createdAt: DateTime(2026, 11, 3, 8, 35),
        ),
      ],
      orders: [orderEventItem],
    );
    final state = await signedInState(api);

    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // O evento do pedido fica (tem o nº do pedido); a notificação repetida
    // do mesmo estado não aparece em duplicado.
    expect(find.text('ND-0001 · A preparar'), findsOneWidget);
    expect(find.text('Pedido ND-0001 em preparação'), findsNothing);
  });

  testWidgets('notificação de pedido sem evento correspondente é listada', (
    tester,
  ) async {
    final api = buildApi(
      notifications: [
        AppNotification(
          id: 'ntf-3',
          kind: 'new_order',
          title: 'Novo pedido ND-0042',
          body: '2× Frango grelhado · 45 000 MZN',
          data: const {'order_id': 'order-42', 'status': 'pending'},
          createdAt: DateTime(2026, 11, 13, 11, 0),
        ),
      ],
    );
    final state = await signedInState(api);

    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Novo pedido ND-0042'), findsOneWidget);
    expect(find.text('2× Frango grelhado · 45 000 MZN'), findsOneWidget);
  });

  testWidgets('sem notificações nem eventos mostra estado vazio', (
    tester,
  ) async {
    final api = buildApi();
    final state = await signedInState(api);

    await tester.pumpWidget(app(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sem novidades'), findsOneWidget);
    // Sem nada para marcar não se chama o endpoint de leitura.
    expect(api.markNotificationsReadCalls, isEmpty);
  });
}

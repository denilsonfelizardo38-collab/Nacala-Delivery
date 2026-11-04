import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/customer/favorites_screen.dart';
import 'package:nacala_derivery/screens/customer/notifications_screen.dart';
import 'package:nacala_derivery/state/app_scope.dart';
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

const _establishment = Establishment(
  id: 'store-1',
  name: 'Baía Azul',
  slug: 'baia-azul',
  description: 'Comida local',
  address: 'Nacala-Porto',
  phone: '854011185',
  deliveryFeeCents: 8000,
  prepMinutes: 30,
  opensAt: '08:00',
  closesAt: '22:00',
  isOpen: true,
  rating: 4.5,
  reviewCount: 12,
  productCount: 8,
  categoryId: 'cat-1',
  categoryName: 'Restaurantes',
  categorySlug: 'restaurantes',
);

final _order = Order(
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
      status: 'pending',
      createdAt: DateTime(2026, 11, 3, 8, 30),
      note: 'Pedido recebido.',
    ),
    OrderEvent(
      status: 'preparing',
      createdAt: DateTime(2026, 11, 3, 8, 35),
      note: 'A tua refeição está a ser preparada.',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> newState(FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return AppState(prefs, api: api);
  }

  FakeApi signedIn({List<Establishment>? favorites, List<Order>? orders}) {
    return FakeApi(user: _customer)
      ..loginResult = const AuthResult(token: 'token-1', user: _customer)
      ..favoritesResult = favorites ?? const []
      ..ordersResult = orders ?? const [];
  }

  Future<AppState> signedInState(FakeApi api) async {
    final state = await newState(api);
    await state.login('cliente@teste.mz', 'segredo');
    return state;
  }

  Widget app(AppState state, Widget home) => AppScope(
    state: state,
    child: MaterialApp(home: home),
  );

  testWidgets('convidado nas notificações é convidado a entrar', (
    tester,
  ) async {
    final state = await newState(FakeApi());
    await state.enterGuestMode();
    await tester.pumpWidget(app(state, const NotificationsScreen()));
    await tester.pump();
    expect(find.text('As notificações são da tua conta'), findsOneWidget);
    expect(find.text('Entrar ou criar conta'), findsOneWidget);
  });

  testWidgets('notificações listam eventos reais dos pedidos', (tester) async {
    final state = await signedInState(signedIn(orders: [_order]));
    await tester.pumpWidget(app(state, const NotificationsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ND-0001 · A preparar'), findsOneWidget);
    expect(find.text('Baía Azul'), findsWidgets);
    expect(
      find.textContaining('refeição está a ser preparada'),
      findsOneWidget,
    );
  });

  testWidgets('notificações vazias mostram estado vazio', (tester) async {
    final state = await signedInState(signedIn());
    await tester.pumpWidget(app(state, const NotificationsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Sem novidades'), findsOneWidget);
  });

  testWidgets('favoritos vazios mostram estado vazio', (tester) async {
    final state = await signedInState(signedIn());
    await tester.pumpWidget(app(state, const FavoritesScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Ainda sem favoritos'), findsOneWidget);
  });

  testWidgets('remover favorito desliga o coração na lista', (tester) async {
    final state = await signedInState(signedIn(favorites: [_establishment]));
    await tester.pumpWidget(app(state, const FavoritesScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Baía Azul'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover dos favoritos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.isFavoriteEstablishment('store-1'), isFalse);
    expect(find.text('Ainda sem favoritos'), findsOneWidget);
  });
}

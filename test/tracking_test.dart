import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/customer/tracking_screen.dart';
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

const _store = Establishment(
  id: 'e1',
  name: 'Cantinho da Baía',
  slug: 'cantinho',
  description: 'Cozinha local',
  address: 'Nacala-Porto',
  phone: '843333331',
  deliveryFeeCents: 8000,
  prepMinutes: 30,
  opensAt: '08:00',
  closesAt: '22:00',
  isOpen: true,
  rating: 4.5,
  reviewCount: 3,
  productCount: 2,
  categoryId: 'c1',
  categoryName: 'Restaurantes',
  categorySlug: 'restaurantes',
);

const _product = Product(
  id: 'p1',
  establishmentId: 'e1',
  name: 'Frango grelhado',
  description: 'Frango inteiro',
  priceCents: 45000,
  category: 'Pratos principais',
  isAvailable: true,
);

final _order = Order(
  id: 'o1',
  number: 'NC-2000',
  status: 'delivered',
  paymentMethod: 'cash',
  paymentStatus: 'cash_on_delivery',
  subtotalCents: 90000,
  deliveryFeeCents: 8000,
  discountCents: 0,
  totalCents: 98000,
  addressLabel: 'Casa',
  addressLine: 'Bairro Central, Rua 12',
  phone: '841234567',
  createdAt: DateTime.utc(2026, 10, 31, 12),
  establishment: const MiniEstablishment(
    id: 'e1',
    name: 'Cantinho da Baía',
    address: 'Nacala-Porto',
    phone: '843333331',
  ),
  items: const [
    OrderItem(
      productId: 'p1',
      name: 'Frango grelhado',
      unitPriceCents: 45000,
      quantity: 2,
      lineTotalCents: 90000,
    ),
  ],
  events: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('repetir pedido repõe as quantidades no carrinho', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi(user: _customer)
      ..loginResult = const AuthResult(token: 'token-123', user: _customer)
      ..orderResult = _order
      ..establishmentDetail = const EstablishmentDetail(
        establishment: _store,
        products: [_product],
        reviews: [],
      );
    final state = AppState(prefs, api: api);
    await state.login('cliente@teste.mz', 'segredo');

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: const TrackingScreen(orderId: 'o1'),
          routes: {
            '/cart': (_) => const Scaffold(body: Text('Carrinho aberto')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reorder = find.text('Repetir pedido');
    await tester.scrollUntilVisible(reorder, 200);
    await tester.pumpAndSettle();

    expect(reorder, findsOneWidget);

    await tester.tap(reorder);
    await tester.pumpAndSettle();

    expect(state.quantityOf('p1'), 2);
    expect(state.cartTotalCents, 90000 + 8000);
    expect(find.text('Carrinho aberto'), findsOneWidget);
  });
}

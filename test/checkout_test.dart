import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/screens/customer/checkout_screen.dart';
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

const _address = Address(
  id: 'addr1',
  label: 'Casa',
  line: 'Bairro Central, Rua 12, casa 34',
  city: 'Nacala-Porto',
  isDefault: true,
  latitude: -14.5428,
  longitude: 40.6729,
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

const _store = CartStore(
  id: 'e1',
  name: 'Cantinho da Baía',
  deliveryFeeCents: 8000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('o checkout pede confirmação antes de criar o pedido', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = FakeApi(user: _customer, addressList: const [_address])
      ..loginResult = const AuthResult(token: 'token-123', user: _customer);
    final state = AppState(prefs, api: api);
    await state.login('cliente@teste.mz', 'segredo');
    state.addToCart(_product, _store);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('530,00 MT'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();

    // O pedido só é criado depois da confirmação explícita.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Confirmar pedido'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.textContaining(
        'Ao confirmar, o pedido é enviado ao estabelecimento.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Dinheiro na entrega'), findsWidgets);
  });
}

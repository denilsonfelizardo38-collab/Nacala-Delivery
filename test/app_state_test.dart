import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/core/api_client.dart';
import 'package:nacala_derivery/models/models.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

const _user = UserAccount(
  id: 'u1',
  role: 'customer',
  name: 'Cliente Teste',
  email: 'cliente@teste.mz',
  phone: '841234567',
);

Product _product(String id, int priceCents) => Product(
  id: id,
  establishmentId: 'e1',
  name: 'Produto $id',
  description: '',
  priceCents: priceCents,
  category: 'Pratos',
  isAvailable: true,
);

const _store = CartStore(
  id: 'e1',
  name: 'Cantinho',
  deliveryFeeCents: 10000,
  imageUrl: 'https://images.example.test/cantinho.jpg',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('sessão', () {
    test('sem token fica signedOut', () async {
      final state = AppState(prefs, api: FakeApi());
      await state.bootstrap();
      expect(state.status, SessionStatus.signedOut);
      expect(state.isSignedIn, isFalse);
    });

    test('login guarda sessão e carrega moradas', () async {
      final api = FakeApi(user: _user);
      api.loginResult = const AuthResult(token: 'token-123', user: _user);
      final state = AppState(prefs, api: api);

      await state.login('cliente@teste.mz', 'segredo');

      expect(state.isSignedIn, isTrue);
      expect(state.user?.name, 'Cliente Teste');
      expect(prefs.getString('nacala.token.v2'), 'token-123');
    });

    test('401 ao restaurar sessão limpa credenciais', () async {
      SharedPreferences.setMockInitialValues({
        'nacala.token.v2': 'token-antigo',
      });
      prefs = await SharedPreferences.getInstance();
      final api = FakeApi(user: _user)
        ..meError = const ApiException('expirado', status: 401);
      final state = AppState(prefs, api: api);

      await state.bootstrap();

      expect(state.status, SessionStatus.signedOut);
      expect(prefs.getString('nacala.token.v2'), isNull);
    });

    test('logout limpa a sessão local', () async {
      final api = FakeApi(user: _user)
        ..loginResult = const AuthResult(token: 'token-123', user: _user);
      final state = AppState(prefs, api: api);
      await state.login('cliente@teste.mz', 'segredo');
      await state.logout();
      expect(state.isSignedIn, isFalse);
      expect(prefs.getString('nacala.token.v2'), isNull);
    });

    test('modo convidado é local e conserva o carrinho', () async {
      final state = AppState(prefs, api: FakeApi());
      state.addToCart(_product('p1', 45000), _store);

      await state.enterGuestMode();

      expect(state.isGuest, isTrue);
      expect(state.isSignedIn, isFalse);
      expect(state.user, isNull);
      expect(state.cartItemCount, 1);
      expect(prefs.getString('nacala.token.v2'), isNull);

      state.exitGuestMode();
      expect(state.isGuest, isFalse);
      expect(state.status, SessionStatus.signedOut);
      expect(state.cartItemCount, 1);
    });
  });

  group('carrinho', () {
    test('a imagem do estabelecimento persiste no carrinho', () {
      final restored = CartStore.fromJson(_store.toJson());
      expect(restored.imageUrl, _store.imageUrl);
    });

    test('soma linhas e taxa de entrega em centavos', () {
      final state = AppState(prefs, api: FakeApi());
      state.addToCart(_product('p1', 45000), _store);
      state.addToCart(_product('p1', 45000), _store);
      state.addToCart(_product('p2', 125050), _store);

      expect(state.cartItemCount, 3);
      expect(state.cartSubtotalCents, 215050);
      expect(state.cartDeliveryFeeCents, 10000);
      expect(state.cartTotalCents, 225050);
    });

    test('adicionar com quantidade preserva o total', () {
      final state = AppState(prefs, api: FakeApi());
      state.addToCart(_product('p1', 45000), _store, quantity: 3);
      expect(state.quantityOf('p1'), 3);
      expect(state.cartTotalCents, 135000 + 10000);
      state.addToCart(_product('p1', 45000), _store, quantity: 2);
      expect(state.quantityOf('p1'), 5);
    });

    test('decrementar até zero remove a linha', () {
      final state = AppState(prefs, api: FakeApi());
      state.addToCart(_product('p1', 45000), _store);
      state.decrement('p1');
      expect(state.cart, isEmpty);
      expect(state.cartStore, isNull);
    });

    test('trocar de estabelecimento substitui o carrinho', () {
      final state = AppState(prefs, api: FakeApi());
      state.addToCart(_product('p1', 45000), _store);
      const other = CartStore(
        id: 'e2',
        name: 'Mercado',
        deliveryFeeCents: 5000,
      );
      state.addToCart(_product('p2', 20000), other);
      expect(state.cart.length, 1);
      expect(state.cartStore?.id, 'e2');
    });

    test('cupão nunca excede o subtotal', () {
      final state = AppState(prefs, api: FakeApi());
      state.addToCart(_product('p1', 1000), _store);
      expect(state.couponDiscountCents, 0);
    });
  });
}

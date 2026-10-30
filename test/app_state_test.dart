import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/data/mock_data.dart';
import 'package:nacala_derivery/models/order.dart';
import 'package:nacala_derivery/state/app_state.dart';
import 'package:nacala_derivery/utils/formatters.dart';

void main() {
  group('formatMoney', () {
    test('usa ponto como separador de milhares', () {
      expect(formatMoney(0), '0 MT');
      expect(formatMoney(530), '530 MT');
      expect(formatMoney(8450), '8.450 MT');
      expect(formatMoney(1250000), '1.250.000 MT');
    });
  });

  group('AppState', () {
    late AppState state;

    setUp(() => state = AppState());

    test('adiciona, incrementa e remove produtos', () {
      final place = mockPlaces.first;
      final product = productsFor(place.id).first;

      expect(state.isCartEmpty, isTrue);
      state.addProduct(place, product);
      state.addProduct(place, product);

      expect(state.quantityOf(product), 2);
      expect(state.cartItemCount, 2);
      expect(state.subtotal, product.price * 2);
      expect(state.total, state.subtotal + place.deliveryFee);

      state.decrementProduct(product);
      expect(state.quantityOf(product), 1);

      state.decrementProduct(product);
      expect(state.isCartEmpty, isTrue);
    });

    test('trocar de local reinicia o carrinho', () {
      final restaurant = mockPlaces[0];
      final market = mockPlaces[1];

      state.addProduct(restaurant, productsFor(restaurant.id).first);
      final replaced = state.addProduct(market, productsFor(market.id).first);

      expect(replaced, isTrue);
      expect(state.cartItemCount, 1);
      expect(state.cartPlace?.id, market.id);
    });

    test('confirmar pedido limpa o carrinho e cria o pedido', () async {
      final place = mockPlaces.first;
      state.addProduct(place, productsFor(place.id).first);

      final order = await state.placeOrder(
        address: 'Bairro Central, casa 12',
        payment: PaymentMethod.mpesa,
        phone: '841234567',
      );

      expect(order.id, 'NC-1049');
      expect(order.status, OrderStatus.received);
      expect(order.total, order.subtotal + order.deliveryFee);
      expect(order.deliveryFee, place.deliveryFee);
      expect(state.isCartEmpty, isTrue);
      expect(state.orders.single.id, order.id);
      expect(state.address, 'Bairro Central, casa 12');
    });

    test('avançar estado segue a ordem até entregue', () async {
      final place = mockPlaces.first;
      state.addProduct(place, productsFor(place.id).first);
      final order = await state.placeOrder(
        address: 'Bairro Central, casa 12',
        payment: PaymentMethod.cash,
      );

      state.advanceOrder(order.id);
      expect(state.orderById(order.id)?.status, OrderStatus.preparing);
      state.advanceOrder(order.id);
      expect(state.orderById(order.id)?.status, OrderStatus.onTheWay);
      state.advanceOrder(order.id);
      expect(state.orderById(order.id)?.status, OrderStatus.delivered);

      // Não passa de "entregue".
      state.advanceOrder(order.id);
      expect(state.orderById(order.id)?.status, OrderStatus.delivered);
    });
  });
}

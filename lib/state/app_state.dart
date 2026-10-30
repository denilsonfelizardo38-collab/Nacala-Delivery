import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_data.dart';
import '../models/cart_line.dart';
import '../models/order.dart';
import '../models/place.dart';

/// Estado global da aplicação: carrinho, pedidos, morada e modo demonstração.
///
/// Implementado com [ChangeNotifier] para não depender de pacotes externos de
/// gestão de estado. Quando existir backend, as operações passam a delegar no
/// `DeliveryRepository`.
class AppState extends ChangeNotifier {
  AppState([this._prefs]) {
    _restore();
  }

  static const _ordersKey = 'nacala.orders.v1';
  static const _addressKey = 'nacala.address.v1';
  static const _demoKey = 'nacala.demoMode.v1';

  final SharedPreferences? _prefs;
  final List<CartLine> _cart = [];
  final List<Order> _orders = [];

  String _address = 'Nacala-Porto · Bairro Central';
  bool _demoMode = false;
  int _tabIndex = 0;
  int _nextOrderNumber = 1049;

  List<CartLine> get cart => List.unmodifiable(_cart);

  List<Order> get orders => List.unmodifiable(_orders);

  String get address => _address;

  bool get demoMode => _demoMode;

  int get tabIndex => _tabIndex;

  void selectTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }

  Place? get cartPlace =>
      _cart.isEmpty ? null : placesById[_cart.first.product.placeId];

  int get cartItemCount => _cart.fold(0, (sum, line) => sum + line.quantity);

  int get subtotal => _cart.fold(0, (sum, line) => sum + line.total);

  int get deliveryFee => _cart.isEmpty ? 0 : (cartPlace?.deliveryFee ?? 0);

  int get total => subtotal + deliveryFee;

  bool get isCartEmpty => _cart.isEmpty;

  Order? orderById(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  int quantityOf(Product product) {
    for (final line in _cart) {
      if (line.product.id == product.id) return line.quantity;
    }
    return 0;
  }

  /// Adiciona um produto ao carrinho.
  ///
  /// Devolve `true` quando o carrinho anterior (de outro local) foi esvaziado.
  bool addProduct(Place place, Product product) {
    var replaced = false;
    if (_cart.isNotEmpty && _cart.first.product.placeId != place.id) {
      _cart.clear();
      replaced = true;
    }
    final index = _cart.indexWhere((line) => line.product.id == product.id);
    if (index == -1) {
      _cart.add(CartLine(product: product, quantity: 1));
    } else {
      _cart[index] = _cart[index].copyWith(quantity: _cart[index].quantity + 1);
    }
    notifyListeners();
    return replaced;
  }

  void decrementProduct(Product product) {
    final index = _cart.indexWhere((line) => line.product.id == product.id);
    if (index == -1) return;
    final line = _cart[index];
    if (line.quantity <= 1) {
      _cart.removeAt(index);
    } else {
      _cart[index] = line.copyWith(quantity: line.quantity - 1);
    }
    notifyListeners();
  }

  void removeProduct(Product product) {
    _cart.removeWhere((line) => line.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    notifyListeners();
  }

  /// Confirma o pedido com o conteúdo atual do carrinho.
  Future<Order> placeOrder({
    required String address,
    required PaymentMethod payment,
    String? phone,
    String? note,
  }) async {
    final place = cartPlace;
    if (place == null) {
      throw StateError('Não é possível confirmar um carrinho vazio.');
    }
    final order = Order(
      id: 'NC-${_nextOrderNumber++}',
      place: place,
      lines: List.of(_cart),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      address: address,
      payment: payment,
      createdAt: DateTime.now(),
      phone: phone,
      note: note,
    );
    _orders.insert(0, order);
    _cart.clear();
    _address = address;
    notifyListeners();
    await _persist();
    return order;
  }

  /// Avança manualmente o estado de um pedido (apenas modo demonstração).
  void advanceOrder(String orderId) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    final next = order.status.index + 1;
    if (next >= OrderStatus.values.length) return;
    _orders[index] = order.copyWith(status: OrderStatus.values[next]);
    notifyListeners();
    _persist();
  }

  void setAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == _address) return;
    _address = trimmed;
    notifyListeners();
    _persist();
  }

  void setDemoMode(bool value) {
    if (_demoMode == value) return;
    _demoMode = value;
    notifyListeners();
    _persist();
  }

  void clearOrders() {
    if (_orders.isEmpty) return;
    _orders.clear();
    notifyListeners();
    _persist();
  }

  void _restore() {
    final prefs = _prefs;
    if (prefs == null) return;

    _address = prefs.getString(_addressKey) ?? _address;
    _demoMode = prefs.getBool(_demoKey) ?? false;

    final raw = prefs.getString(_ordersKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final entry in list) {
          final order = Order.fromJson(
            entry as Map<String, dynamic>,
            places: placesById,
            products: productsById,
          );
          if (order != null) _orders.add(order);
        }
      } catch (_) {
        // Dados locais corrompidos: começa com histórico vazio.
        _orders.clear();
      }
    }

    if (_orders.isNotEmpty) {
      final highest = _orders
          .map((order) => int.tryParse(order.id.split('-').last) ?? 0)
          .reduce((a, b) => a > b ? a : b);
      _nextOrderNumber = highest + 1;
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _ordersKey,
      jsonEncode([for (final order in _orders) order.toJson()]),
    );
    await prefs.setString(_addressKey, _address);
    await prefs.setBool(_demoKey, _demoMode);
  }
}

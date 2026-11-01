import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../data/api_service.dart';
import '../models/models.dart';

enum SessionStatus { loading, signedOut, signedIn, guest }

/// Estado global da aplicação: sessão autenticada, moradas e carrinho.
///
/// Toda a informação de negócio (preços, totais, estados de pedido) vem da API;
/// aqui só se guardam cópias para apresentação e persistência local.
class AppState extends ChangeNotifier {
  factory AppState(
    SharedPreferences prefs, {
    ApiClient? client,
    NacalaApi? api,
  }) {
    final effectiveClient = client ?? ApiClient();
    return AppState._(
      prefs,
      effectiveClient,
      api ?? NacalaApi(effectiveClient),
    );
  }

  AppState._(this._prefs, this._client, this._api);

  static const _tokenKey = 'nacala.token.v2';
  static const _userKey = 'nacala.user.v2';
  static const _cartKey = 'nacala.cart.v2';

  final SharedPreferences _prefs;
  final ApiClient _client;
  final NacalaApi _api;

  NacalaApi get api => _api;
  ApiClient get client => _client;

  SessionStatus _status = SessionStatus.loading;
  UserAccount? _user;
  String? _token;
  String? _startupMessage;
  bool _busy = false;

  List<Address> _addresses = const [];
  List<CartLine> _cart = [];
  CartStore? _cartStore;
  int _couponDiscountCents = 0;
  String? _couponCode;

  SessionStatus get status => _status;
  UserAccount? get user => _user;
  bool get isSignedIn => _status == SessionStatus.signedIn && _user != null;
  bool get isGuest => _status == SessionStatus.guest;
  bool get isBusy => _busy;
  String? get startupMessage => _startupMessage;
  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get defaultAddress {
    if (_addresses.isEmpty) return null;
    for (final address in _addresses) {
      if (address.isDefault) return address;
    }
    return _addresses.first;
  }

  String get firstName {
    final name = _user?.name.trim() ?? '';
    if (name.isEmpty) return 'vizinho';
    return name.split(RegExp(r'\s+')).first;
  }

  String get apiBaseUrl => _client.baseUrl;

  // ------------------------------------------------------------------ sessão

  /// Restaura a sessão guardada e revalida-a junto da API.
  Future<void> bootstrap({
    Duration serverTimeout = const Duration(seconds: 5),
  }) async {
    _restoreCart();
    final token = _prefs.getString(_tokenKey);
    final cachedUser = _prefs.getString(_userKey);
    if (token == null || token.isEmpty) {
      _status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    _client.token = token;
    _token = token;
    if (cachedUser != null) {
      try {
        final json = jsonDecode(cachedUser);
        if (json is Map<String, dynamic>) {
          _user = UserAccount.fromJson(json);
          _status = SessionStatus.signedIn;
        }
      } on FormatException {
        _user = null;
      }
    }
    notifyListeners();
    try {
      final data = await _api.me().timeout(serverTimeout);
      _user = data.user;
      _addresses = data.addresses;
      _status = SessionStatus.signedIn;
      _startupMessage = null;
      await _persistSession();
    } on TimeoutException {
      _startupMessage = 'A ligação ao servidor está lenta. Podes tentar novamente mais tarde.';
      if (_user == null) _status = SessionStatus.signedOut;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _clearSession();
      } else if (_user == null) {
        _startupMessage = error.message;
        _status = SessionStatus.signedOut;
      }
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.login(identifier, password);
      await _applyAuth(result);
      await refreshAddresses();
      _startupMessage = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      await _applyAuth(result);
      await refreshAddresses();
      _startupMessage = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (_client.token != null) await _api.logout();
    } on ApiException {
      // Mesmo sem rede, a sessão local é terminada.
    }
    await _clearSession();
    notifyListeners();
  }

  Future<void> enterGuestMode() async {
    await _clearSession();
    _startupMessage = null;
    _status = SessionStatus.guest;
    notifyListeners();
  }

  void exitGuestMode() {
    if (!isGuest) return;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  /// Termina a sessão local (usado quando a API devolve 401).
  Future<void> forceSignOut() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _applyAuth(AuthResult result) async {
    _token = result.token;
    _client.token = result.token;
    _user = result.user;
    _status = SessionStatus.signedIn;
    await _persistSession();
    notifyListeners();
  }

  Future<void> _persistSession() async {
    if (_token == null || _user == null) return;
    await _prefs.setString(_tokenKey, _token!);
    await _prefs.setString(
      _userKey,
      jsonEncode({
        'id': _user!.id,
        'role': _user!.role,
        'name': _user!.name,
        'email': _user!.email,
        'phone': _user!.phone,
      }),
    );
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    _client.token = null;
    _addresses = const [];
    _status = SessionStatus.signedOut;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }

  Future<void> refreshMe() async {
    final data = await _api.me();
    _user = data.user;
    _addresses = data.addresses;
    await _persistSession();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    _user = await _api.updateProfile(name: name, phone: phone);
    await _persistSession();
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _applyAuth(result);
  }

  // ---------------------------------------------------------------- moradas

  Future<void> refreshAddresses() async {
    _addresses = await _api.addresses();
    notifyListeners();
  }

  Future<Address> addAddress({
    required String label,
    required String line,
    String? reference,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final address = await _api.createAddress(
      label: label,
      line: line,
      reference: reference,
      isDefault: isDefault,
      latitude: latitude,
      longitude: longitude,
    );
    await refreshAddresses();
    return address;
  }

  Future<Address> updateAddress(
    String id, {
    required String label,
    required String line,
    String? reference,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final address = await _api.updateAddress(
      id,
      label: label,
      line: line,
      reference: reference,
      isDefault: isDefault,
      latitude: latitude,
      longitude: longitude,
    );
    await refreshAddresses();
    return address;
  }

  Future<void> deleteAddress(String id) async {
    await _api.deleteAddress(id);
    await refreshAddresses();
  }

  // ----------------------------------------------------------------- carrinho

  List<CartLine> get cart => List.unmodifiable(_cart);
  CartStore? get cartStore => _cartStore;
  bool get isCartEmpty => _cart.isEmpty;
  int get cartItemCount => _cart.fold(0, (sum, line) => sum + line.quantity);
  int get cartSubtotalCents =>
      _cart.fold(0, (sum, line) => sum + line.totalCents);
  int get cartDeliveryFeeCents =>
      _cart.isEmpty ? 0 : (_cartStore?.deliveryFeeCents ?? 0);
  int get couponDiscountCents =>
      _couponDiscountCents.clamp(0, cartSubtotalCents).toInt();
  String? get couponCode => _couponCode;
  int get cartTotalCents =>
      (cartSubtotalCents + cartDeliveryFeeCents - couponDiscountCents)
          .clamp(0, 1 << 62)
          .toInt();

  bool cartBelongsTo(String storeId) =>
      _cartStore == null || _cartStore!.id == storeId;

  int quantityOf(String productId) {
    for (final line in _cart) {
      if (line.product.id == productId) return line.quantity;
    }
    return 0;
  }

  void addToCart(Product product, CartStore store, {int quantity = 1}) {
    if (_cartStore != null && _cartStore!.id != store.id) {
      _cart = [];
      _cartStore = null;
    }
    _cartStore = store;
    _resetCoupon();
    final amount = quantity.clamp(1, 99);
    final index = _cart.indexWhere((line) => line.product.id == product.id);
    if (index >= 0) {
      _cart[index].quantity = (_cart[index].quantity + amount).clamp(1, 99);
    } else {
      _cart = [..._cart, CartLine(product: product, quantity: amount)];
    }
    _saveCart();
    notifyListeners();
  }

  void increment(String productId) {
    final index = _cart.indexWhere((line) => line.product.id == productId);
    if (index < 0) return;
    if (_cart[index].quantity >= 99) return;
    _cart[index].quantity += 1;
    _resetCoupon();
    _saveCart();
    notifyListeners();
  }

  void decrement(String productId) {
    final index = _cart.indexWhere((line) => line.product.id == productId);
    if (index < 0) return;
    if (_cart[index].quantity <= 1) {
      _cart.removeAt(index);
    } else {
      _cart[index].quantity -= 1;
    }
    if (_cart.isEmpty) _cartStore = null;
    _resetCoupon();
    _saveCart();
    notifyListeners();
  }

  void removeLine(String productId) {
    _cart.removeWhere((line) => line.product.id == productId);
    if (_cart.isEmpty) _cartStore = null;
    _resetCoupon();
    _saveCart();
    notifyListeners();
  }

  void setLineNote(String productId, String? note) {
    final index = _cart.indexWhere((line) => line.product.id == productId);
    if (index < 0) return;
    _cart[index].note = (note == null || note.trim().isEmpty)
        ? null
        : note.trim();
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    _cartStore = null;
    _resetCoupon();
    _saveCart();
    notifyListeners();
  }

  void _resetCoupon() {
    _couponDiscountCents = 0;
    _couponCode = null;
  }

  /// Valida o cupão no servidor e guarda o desconto devolvido.
  Future<int> applyCoupon(String code) async {
    final discount = await _api.validateCoupon(code.trim(), cartSubtotalCents);
    _couponCode = code.trim().toUpperCase();
    _couponDiscountCents = discount;
    notifyListeners();
    return discount;
  }

  void removeCoupon() {
    _resetCoupon();
    notifyListeners();
  }

  Future<Order> placeOrder({
    required Address address,
    required String phone,
    required String paymentMethod,
    String? note,
  }) async {
    final store = _cartStore;
    if (store == null || _cart.isEmpty) {
      throw const ApiException('O carrinho está vazio.', code: 'empty_cart');
    }
    final order = await _api.createOrder(
      establishmentId: store.id,
      lines: _cart,
      addressLabel: address.label,
      addressLine: address.fullLine,
      addressLatitude: address.latitude,
      addressLongitude: address.longitude,
      phone: phone,
      paymentMethod: paymentMethod,
      note: note,
      couponCode: _couponCode,
    );
    clearCart();
    return order;
  }

  // ------------------------------------------------------------- persistência

  void _saveCart() {
    final payload = jsonEncode({
      'store': _cartStore?.toJson(),
      'lines': [for (final line in _cart) line.toJson()],
    });
    _prefs.setString(_cartKey, payload);
  }

  void _restoreCart() {
    final raw = _prefs.getString(_cartKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;
      final store = json['store'];
      if (store is Map<String, dynamic>) {
        _cartStore = CartStore.fromJson(store);
      }
      final lines = json['lines'];
      if (lines is List) {
        _cart = [
          for (final line in lines)
            if (line is Map<String, dynamic>) CartLine.fromJson(line),
        ];
      }
      if (_cart.isEmpty) _cartStore = null;
    } catch (_) {
      _cart = [];
      _cartStore = null;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../models/models.dart';

class MeData {
  const MeData({required this.user, required this.addresses});
  final UserAccount user;
  final List<Address> addresses;
}

/// Contrato tipado sobre a API HTTP. Nenhuma resposta é simulada aqui.
class NacalaApi {
  NacalaApi(this.client);

  final ApiClient client;

  // ------------------------------------------------------------------ sessão

  Future<AuthResult> login(String identifier, String password) async {
    final json = await client.post(
      '/api/auth/login',
      body: {'identifier': identifier, 'password': password},
    );
    return AuthResult.fromJson(json);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final json = await client.post(
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
    return AuthResult.fromJson(json);
  }

  Future<MeData> me() async {
    final json = await client.get('/api/auth/me');
    return MeData(
      user: UserAccount.fromJson(json['user'] as Map<String, dynamic>),
      addresses: [
        for (final item in (json['addresses'] as List? ?? const []))
          Address.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Future<UserAccount> updateProfile({
    required String name,
    required String phone,
    String? email,
  }) async {
    final json = await client.patch(
      '/api/auth/profile',
      body: {
        'name': name,
        'phone': phone,
        'email': ?email,
      },
    );
    return UserAccount.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// Envia a fotografia do utilizador e devolve o utilizador atualizado.
  Future<UserAccount> uploadAvatar({
    required String mimeType,
    required String dataBase64,
  }) async {
    final json = await client.post(
      '/api/auth/avatar',
      body: {'mime_type': mimeType, 'data_base64': dataBase64},
    );
    return UserAccount.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final json = await client.post(
      '/api/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    return AuthResult.fromJson(json);
  }

  Future<void> logout() async {
    await client.post('/api/auth/logout');
  }

  // --------------------------------------------------------------- catálogo

  Future<List<Category>> categories() async {
    final json = await client.get('/api/categories');
    return [
      for (final item in (json['categories'] as List? ?? const []))
        Category.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<Establishment>> establishments({
    String? category,
    String? query,
    String? sort,
    bool openOnly = false,
  }) async {
    final json = await client.get(
      '/api/establishments',
      query: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (query != null && query.isNotEmpty) 'q': query,
        'sort': ?sort,
        if (openOnly) 'open': '1',
      },
    );
    return [
      for (final item in (json['establishments'] as List? ?? const []))
        Establishment.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<EstablishmentDetail> establishment(String id) async {
    final json = await client.get('/api/establishments/$id');
    return EstablishmentDetail(
      establishment: Establishment.fromJson(
        json['establishment'] as Map<String, dynamic>,
      ),
      products: [
        for (final item in (json['products'] as List? ?? const []))
          Product.fromJson(item as Map<String, dynamic>),
      ],
      reviews: [
        for (final item in (json['reviews'] as List? ?? const []))
          Review.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Future<List<Product>> products({
    String? query,
    String? establishment,
    String? category,
  }) async {
    final json = await client.get(
      '/api/products',
      query: {
        if (query != null && query.isNotEmpty) 'q': query,
        'establishment': ?establishment,
        'category': ?category,
      },
    );
    return [
      for (final item in (json['products'] as List? ?? const []))
        Product.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<SearchResult> search(String query) async {
    final json = await client.get('/api/search', query: {'q': query});
    return SearchResult.fromJson(json);
  }

  // ------------------------------------------------------ moradas e favoritos

  /// Lista os favoritos do utilizador (estabelecimentos aprovados).
  Future<List<Establishment>> favorites() async {
    final json = await client.get('/api/favorites');
    return [
      for (final item in (json['establishments'] as List? ?? const []))
        Establishment.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> addFavorite(String establishmentId) =>
      client.post('/api/favorites/$establishmentId');

  Future<void> removeFavorite(String establishmentId) =>
      client.delete('/api/favorites/$establishmentId');

  Future<List<Address>> addresses() async {
    final json = await client.get('/api/addresses');
    return [
      for (final item in (json['addresses'] as List? ?? const []))
        Address.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Address> createAddress({
    required String label,
    required String line,
    String? reference,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final json = await client.post(
      '/api/addresses',
      body: {
        'label': label,
        'line': line,
        'reference': reference,
        'is_default': isDefault,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return Address.fromJson(json['address'] as Map<String, dynamic>);
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
    final json = await client.patch(
      '/api/addresses/$id',
      body: {
        'label': label,
        'line': line,
        'reference': reference,
        'is_default': isDefault,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return Address.fromJson(json['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await client.delete('/api/addresses/$id');
  }

  // ------------------------------------------------------------------ cupões

  Future<int> validateCoupon(String code, int subtotalCents) async {
    final json = await client.post(
      '/api/coupons/validate',
      body: {'code': code, 'subtotal_cents': subtotalCents},
    );
    final coupon = json['coupon'] as Map<String, dynamic>;
    return coupon['discount_cents'] as int;
  }

  // ----------------------------------------------------------------- pedidos

  Future<Order> createOrder({
    required String establishmentId,
    required List<CartLine> lines,
    required String addressLabel,
    required String addressLine,
    double? addressLatitude,
    double? addressLongitude,
    required String phone,
    required String paymentMethod,
    String? note,
    String? couponCode,
  }) async {
    final json = await client.post(
      '/api/orders',
      body: {
        'establishment_id': establishmentId,
        'items': [
          for (final line in lines)
            {
              'product_id': line.product.id,
              'quantity': line.quantity,
              if (line.note != null && line.note!.isNotEmpty) 'note': line.note,
            },
        ],
        'address_label': addressLabel,
        'address_line': addressLine,
        'address_latitude': addressLatitude,
        'address_longitude': addressLongitude,
        'phone': phone,
        'payment_method': paymentMethod,
        'note': note,
        'coupon_code': couponCode,
      },
    );
    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }

  Future<List<Order>> orders({String? status}) async {
    final json = await client.get(
      '/api/orders',
      query: {if (status != null && status != 'all') 'status': status},
    );
    return [
      for (final item in (json['orders'] as List? ?? const []))
        Order.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Order> order(String id) async {
    final json = await client.get('/api/orders/$id');
    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }

  Future<Order> cancelOrder(String id, String reason) async {
    final json = await client.post(
      '/api/orders/$id/cancel',
      body: {'reason': reason},
    );
    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }

  Future<void> reviewOrder(String id, int rating, String? comment) async {
    await client.post(
      '/api/orders/$id/review',
      body: {'rating': rating, 'comment': comment},
    );
  }

  // ----------------------------------------------------------------- parceiro

  Future<PartnerDashboardData> partnerDashboard() async {
    final json = await client.get('/api/partner/summary');
    return PartnerDashboardData(
      establishment: Establishment.fromJson(
        json['establishment'] as Map<String, dynamic>,
      ),
      summary: PartnerSummary.fromJson(json['summary'] as Map<String, dynamic>),
      recentOrders: [
        for (final item in (json['recent_orders'] as List? ?? const []))
          Order.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Future<List<Order>> partnerOrders({String? status}) async {
    final json = await client.get(
      '/api/partner/orders',
      query: {'status': ?status},
    );
    return [
      for (final item in (json['orders'] as List? ?? const []))
        Order.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Order> partnerAction(
    String id,
    String action, {
    String? reason,
  }) async {
    final json = await client.post(
      '/api/partner/orders/$id/$action',
      body: {'reason': ?reason},
    );
    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }

  Future<List<Product>> partnerProducts() async {
    final json = await client.get('/api/partner/products');
    return [
      for (final item in (json['products'] as List? ?? const []))
        Product.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<String> uploadProductImage(XFile file) async {
    final extension = file.name.toLowerCase().split('.').last;
    final mimeType = switch (file.mimeType?.toLowerCase()) {
      'image/jpeg' => 'image/jpeg',
      'image/png' => 'image/png',
      'image/webp' => 'image/webp',
      _ => switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      },
    };
    if (mimeType == null) {
      throw const ApiException(
        'Escolha uma imagem JPEG, PNG ou WebP.',
        code: 'invalid_image',
        status: 422,
      );
    }

    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      throw const ApiException(
        'Não foi possível ler a imagem selecionada.',
        code: 'image_read_failed',
      );
    }
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ApiException(
        'A imagem deve ter menos de 5 MB.',
        code: 'image_too_large',
        status: 413,
      );
    }
    final response = await client.post(
      '/api/partner/product-images',
      body: {'mime_type': mimeType, 'data_base64': base64Encode(bytes)},
    );
    final imagePath = response['image_url'];
    if (imagePath is! String || !imagePath.startsWith('/uploads/')) {
      throw const ApiException(
        'Resposta inválida ao carregar a imagem.',
        code: 'invalid_response',
        status: 502,
      );
    }
    return client.resolveUri(imagePath).toString();
  }

  Future<Product> saveProduct({
    String? id,
    required String name,
    required String description,
    required int priceCents,
    required String category,
    required bool isAvailable,
    int? stock,
    String? imageUrl,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'price_cents': priceCents,
      'category': category,
      'is_available': isAvailable,
      'stock': stock,
      'image_url': imageUrl,
    };
    final json = id == null
        ? await client.post('/api/partner/products', body: body)
        : await client.patch('/api/partner/products/$id', body: body);
    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }

  Future<bool> deleteProduct(String id) async {
    final json = await client.delete('/api/partner/products/$id');
    return json['deactivated'] == true;
  }

  Future<Establishment> partnerEstablishment() async {
    final json = await client.get('/api/partner/establishment');
    return Establishment.fromJson(
      json['establishment'] as Map<String, dynamic>,
    );
  }

  Future<Establishment> updatePartnerEstablishment({
    required String description,
    required String phone,
    required String address,
    required bool isOpen,
    required String opensAt,
    required String closesAt,
  }) async {
    final json = await client.patch(
      '/api/partner/establishment',
      body: {
        'description': description,
        'phone': phone,
        'address': address,
        'is_open': isOpen,
        'opens_at': opensAt,
        'closes_at': closesAt,
      },
    );
    return Establishment.fromJson(
      json['establishment'] as Map<String, dynamic>,
    );
  }

  // ---------------------------------------------------------------- entregas

  Future<List<DeliveryAssignment>> deliveryAssignments() async {
    final json = await client.get('/api/delivery/assignments');
    return [
      for (final item in (json['assignments'] as List? ?? const []))
        DeliveryAssignment.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<DeliveryAssignment>> deliveryHistory() async {
    final json = await client.get('/api/delivery/history');
    return [
      for (final item in (json['assignments'] as List? ?? const []))
        DeliveryAssignment.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> deliveryAction(String id, String action) async {
    await client.post('/api/delivery/assignments/$id/$action');
  }

  Future<void> updateDeliveryLocation(
    String id, {
    required double latitude,
    required double longitude,
  }) async {
    await client.post(
      '/api/delivery/assignments/$id/location',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  // -------------------------------------------------------------------- admin

  Future<AdminSummary> adminSummary() async {
    final json = await client.get('/api/admin/summary');
    return AdminSummary.fromJson(json);
  }

  Future<List<Establishment>> adminPartners() async {
    final json = await client.get('/api/admin/partners');
    return [
      for (final item in (json['partners'] as List? ?? const []))
        Establishment.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> adminPartnerAction(String id, String action) async {
    await client.post('/api/admin/partners/$id/$action');
  }

  /// Cria a conta do parceiro e o estabelecimento (apenas administração).
  Future<Establishment> adminCreatePartner({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String establishmentName,
    required String categoryId,
    String? description,
    String? address,
    String? establishmentPhone,
    required int deliveryFeeCents,
    required int prepMinutes,
    required String opensAt,
    required String closesAt,
    String? imageUrl,
  }) async {
    final json = await client.post(
      '/api/admin/partners',
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'establishment_name': establishmentName,
        'category_id': categoryId,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (address != null && address.isNotEmpty) 'address': address,
        if (establishmentPhone != null && establishmentPhone.isNotEmpty)
          'establishment_phone': establishmentPhone,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'delivery_fee_cents': deliveryFeeCents,
        'prep_minutes': prepMinutes,
        'opens_at': opensAt,
        'closes_at': closesAt,
      },
    );
    return Establishment.fromJson(
      json['establishment'] as Map<String, dynamic>,
    );
  }

  Future<List<AdminUser>> adminUsers({String? role}) async {
    final json = await client.get('/api/admin/users', query: {'role': ?role});
    return [
      for (final item in (json['users'] as List? ?? const []))
        AdminUser.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> adminUpdateUser(
    String id, {
    String? role,
    bool? isActive,
  }) async {
    await client.patch(
      '/api/admin/users/$id',
      body: {'role': ?role, 'is_active': ?isActive},
    );
  }

  Future<List<Order>> adminOrders({String? status}) async {
    final json = await client.get(
      '/api/admin/orders',
      query: {'status': ?status},
    );
    return [
      for (final item in (json['orders'] as List? ?? const []))
        Order.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<AuditLog>> adminAudit() async {
    final json = await client.get('/api/admin/audit');
    return [
      for (final item in (json['logs'] as List? ?? const []))
        AuditLog.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Category> createCategory(String name, {String? imageUrl}) async {
    final json = await client.post(
      '/api/admin/categories',
      body: {
        'name': name,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      },
    );
    return Category.fromJson(json['category'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await client.delete('/api/admin/categories/$id');
  }
}

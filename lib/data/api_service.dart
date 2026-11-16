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
    String? email,
    required String phone,
    String? whatsapp,
    required String password,
  }) async {
    final json = await client.post(
      '/api/auth/register',
      body: {
        'name': name,
        // E-mail opcional no registo de clientes: quando ausente o
        // servidor deriva um endereço interno a partir do telefone.
        if (email != null && email.trim().isNotEmpty) 'email': email,
        'phone': phone,
        if (whatsapp != null && whatsapp.trim().isNotEmpty)
          'whatsapp': whatsapp,
        'password': password,
      },
    );
    return AuthResult.fromJson(json);
  }

  /// Recupera o acesso com o código gerado no registo. Devolve uma nova
  /// sessão; o código é rotacionado e o novo valor vem em
  /// [AuthResult.recoveryCode] (única vez — não há envio por email/SMS).
  Future<AuthResult> recoverPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    final json = await client.post(
      '/api/auth/recover',
      body: {'identifier': identifier, 'code': code, 'password': password},
    );
    return AuthResult.fromJson(json);
  }

  /// Emite um novo código de recuperação para a conta autenticada (o
  /// anterior deixa de valer), devolvido uma única vez.
  Future<String> regenerateRecoveryCode() async {
    final json = await client.post('/api/auth/recovery-code');
    return (json['recovery_code'] as String?) ?? '';
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
    String? whatsapp,
  }) async {
    final json = await client.patch(
      '/api/auth/profile',
      body: {
        'name': name,
        'phone': phone,
        'email': ?email,
        // Omitido quando nulo (mantém o valor); string vazia limpa o campo.
        'whatsapp': ?whatsapp,
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

  // ----------------------------------------------------------- candidaturas

  /// Envia uma candidatura (estabelecimento ou entregador) para aprovação.
  ///
  /// [payload] contém os dados próprios de cada tipo (categoria, morada,
  /// coordenadas…). Quando o utilizador tem sessão iniciada, o servidor
  /// associa a candidatura à conta (reenvio de correções).
  Future<Application> submitApplication({
    required String kind,
    required String name,
    required String phone,
    required String password,
    String? email,
    String? whatsapp,
    Map<String, dynamic> payload = const {},
  }) async {
    final json = await client.post(
      '/api/applications',
      body: {
        'kind': kind,
        'name': name,
        'phone': phone,
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email,
        if (whatsapp != null && whatsapp.trim().isNotEmpty)
          'whatsapp': whatsapp,
        'payload': payload,
      },
    );
    return Application.fromJson(
      (json['application'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Candidatura da conta autenticada (acompanhar estado / corrigir).
  Future<Application> myApplication() async {
    final json = await client.get('/api/applications/me');
    return Application.fromJson(
      (json['application'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
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

  Future<String> uploadProductImage(XFile file) =>
      _uploadImage('/api/partner/product-images', file);

  /// Carrega uma imagem de candidatura (documentos do entregador). Endpoint
  /// público: o candidato ainda não tem sessão iniciada.
  Future<String> uploadApplicationImage(XFile file) =>
      _uploadImage('/api/applications/images', file);

  /// Carrega a fotografia do estabelecimento pela administração.
  Future<String> adminUploadPartnerImage(XFile file) =>
      _uploadImage('/api/admin/partner-images', file);

  /// Envia a imagem para [path] e devolve o URL absoluto guardado.
  Future<String> _uploadImage(String path, XFile file) async {
    final response = await client.post(path, body: await _imageBody(file));
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

  /// Monta o corpo `{mime_type, data_base64}` de um upload, validando tipo e
  /// tamanho antes de gastar rede (o servidor repete a validação).
  Future<Map<String, dynamic>> _imageBody(XFile file) async {
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
    return {'mime_type': mimeType, 'data_base64': base64Encode(bytes)};
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

  // -------------------------------------------------------- gestão de registos

  /// Candidaturas com contagens por estado (`Gestão de Registos`).
  /// [status] e [kind] são filtros opcionais passados ao servidor.
  Future<
    ({List<Application> applications, Map<String, int> counts})
  >
  adminApplications({String? status, String? kind}) async {
    final json = await client.get('/api/admin/applications', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (kind != null && kind.isNotEmpty) 'kind': kind,
    });
    final rawCounts = json['counts'];
    return (
      applications: [
        for (final item in (json['applications'] as List? ?? const []))
          Application.fromJson(item as Map<String, dynamic>),
      ],
      counts: {
        if (rawCounts is Map)
          for (final entry in rawCounts.entries)
            '${entry.key}': (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }

  Future<Application> adminApproveApplication(String id, {String? note}) async {
    final json = await client.post(
      '/api/admin/applications/$id/approve',
      body: {if (note != null && note.isNotEmpty) 'note': note},
    );
    return Application.fromJson(
      (json['application'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<Application> adminRejectApplication(String id, {String? note}) async {
    final json = await client.post(
      '/api/admin/applications/$id/reject',
      body: {if (note != null && note.isNotEmpty) 'note': note},
    );
    return Application.fromJson(
      (json['application'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Devolve a candidatura ao candidato com correções obrigatórias.
  Future<Application> adminRequestApplicationChanges(
    String id, {
    required String note,
  }) async {
    final json = await client.post(
      '/api/admin/applications/$id/changes',
      body: {'note': note},
    );
    return Application.fromJson(
      (json['application'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
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
    required String nuit,
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
        'nuit': nuit,
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

  // ------------------------------------------------------- funcionários (FASE 10)

  /// Lista as contas de funcionário (rota admin-only: `employees`).
  Future<List<AdminEmployee>> adminEmployees() async {
    final json = await client.get('/api/admin/employees');
    return [
      for (final item in (json['employees'] as List? ?? const []))
        AdminEmployee.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Cria um funcionário com nível e permissões (só o administrador).
  Future<AdminEmployee> adminCreateEmployee({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String level,
    List<String> permissions = const [],
  }) async {
    final json = await client.post(
      '/api/admin/employees',
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'level': level,
        'permissions': permissions,
      },
    );
    return AdminEmployee.fromJson(json['employee'] as Map<String, dynamic>);
  }

  /// Atualiza nível/permissões/estado de um funcionário.
  Future<AdminEmployee> adminUpdateEmployee(
    String id, {
    String? level,
    List<String>? permissions,
    bool? isActive,
  }) async {
    final json = await client.patch(
      '/api/admin/employees/$id',
      body: {
        'level': ?level,
        'permissions': ?permissions,
        'is_active': ?isActive,
      },
    );
    return AdminEmployee.fromJson(json['employee'] as Map<String, dynamic>);
  }

  /// Elimina a conta de funcionário em definitivo.
  Future<void> adminDeleteEmployee(String id) async {
    await client.delete('/api/admin/employees/$id');
  }

  // ------------------------------------------------------------ notificações

  /// Lista as notificações persistentes do utilizador autenticado.
  Future<List<AppNotification>> notifications({int limit = 50}) async {
    final json = await client.get(
      '/api/notifications',
      query: {'limit': '$limit'},
    );
    return [
      for (final item in (json['notifications'] as List? ?? const []))
        AppNotification.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Marca notificações como lidas (sem ids marca todas).
  Future<void> markNotificationsRead({List<String>? ids}) async {
    await client.post(
      '/api/notifications/read',
      body: {if (ids != null) 'ids': ids},
    );
  }

  // ------------------------------------------------------------ chat (FASE 13)

  /// Lista as conversas do utilizador autenticado.
  Future<List<Conversation>> conversations() async {
    final json = await client.get('/api/conversations');
    return [
      for (final item in (json['conversations'] as List? ?? const []))
        Conversation.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Cria (ou reutiliza) uma conversa com outro utilizador, opcionalmente
  /// ligada a uma encomenda.
  Future<Conversation> createConversation({
    required String otherUserId,
    String? orderId,
  }) async {
    final json = await client.post(
      '/api/conversations',
      body: {'other_user_id': otherUserId, if (orderId != null) 'order_id': orderId},
    );
    return Conversation.fromJson(json['conversation'] as Map<String, dynamic>);
  }

  /// Lista as mensagens de uma conversa.
  Future<List<Message>> messages(String conversationId, {int limit = 50, String? before}) async {
    final json = await client.get(
      '/api/conversations/$conversationId/messages',
      query: {'limit': '$limit', if (before != null) 'before': before},
    );
    return [
      for (final item in (json['messages'] as List? ?? const []))
        Message.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Envia uma mensagem numa conversa.
  Future<Message> sendMessage({
    required String conversationId,
    required String body,
    String type = 'text',
  }) async {
    final json = await client.post(
      '/api/conversations/$conversationId/messages',
      body: {'body': body, 'type': type},
    );
    return Message.fromJson(json['message'] as Map<String, dynamic>);
  }

  /// Marca as mensagens de uma conversa como lidas.
  Future<void> markMessagesRead(String conversationId) async {
    await client.post('/api/conversations/$conversationId/read', body: {});
  }

  // ------------------------------------------------------------ chamadas (FASE 13)

  /// Lista o histórico de chamadas do utilizador autenticado.
  Future<List<CallLog>> callLogs({int limit = 50}) async {
    final json = await client.get(
      '/api/call-logs',
      query: {'limit': '$limit'},
    );
    return [
      for (final item in (json['call_logs'] as List? ?? const []))
        CallLog.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Regista uma chamada (iniciada, atendida, recusada, perdida, terminada).
  Future<CallLog> logCall({
    required String calleeId,
    String? conversationId,
    String type = 'voice',
    String status = 'initiated',
  }) async {
    final json = await client.post(
      '/api/call-logs',
      body: {
        'callee_id': calleeId,
        if (conversationId != null) 'conversation_id': conversationId,
        'type': type,
        'status': status,
      },
    );
    return CallLog.fromJson(json['call_log'] as Map<String, dynamic>);
  }
}

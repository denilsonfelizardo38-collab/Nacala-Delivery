import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'auth.dart';
import 'db.dart';

class ApiError implements Exception {
  ApiError(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
}

Response jsonResponse(Object? data, {int status = 200}) => Response(
      status,
      body: jsonEncode(data),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Resposta 404 em JSON (a omissão do shelf_router devolve texto puro e o
/// cliente Flutter falha ao decodificar, mostrando "Resposta inválida").
Response _routeNotFoundJson(Request request) => jsonResponse(
      {
        'error': {
          'code': 'route_not_found',
          'message': 'Recurso não encontrado.',
        },
      },
      status: 404,
    );

class Api {
  Api({
    required this.db,
    required this.jwt,
    Directory? imageDirectory,
    this.allowedOrigin = '*',
  }) : imageDirectory = imageDirectory ?? Directory('data/uploads');

  final Database db;
  final JwtService jwt;
  final Directory imageDirectory;

  /// Origem(es) permitidas para CORS. `*` por omissão; em produção defina
  /// `CORS_ORIGIN` (ex.: `https://app.nacala.co.mz`) para restringir.
  final String allowedOrigin;

  Handler get handler => const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(_errors())
      .addMiddleware(_requestLogger())
      .addHandler(_router.call);

  late final Router _router = Router(notFoundHandler: _routeNotFoundJson)
    ..get('/health', _health)
    ..get('/uploads/<filename>', _productImage)
    ..get('/api/categories', _categories)
    ..get('/api/establishments', _establishments)
    ..get('/api/establishments/<id>', _establishment)
    ..get('/api/establishments/<id>/products', _establishmentProducts)
    ..get('/api/products', _products)
    ..get('/api/search', _search)
    ..post('/api/auth/register', _register)
    ..post('/api/auth/login', _login)
    ..get('/api/auth/me', _me)
    ..patch('/api/auth/profile', _updateProfile)
    ..post('/api/auth/avatar', _uploadAvatar)
    ..post('/api/auth/change-password', _changePassword)
    ..post('/api/auth/recover', _recover)
    ..post('/api/auth/recovery-code', _regenerateRecoveryCode)
    ..post('/api/auth/logout', _logout)
    ..get('/api/addresses', _listAddresses)
    ..post('/api/addresses', _createAddress)
    ..patch('/api/addresses/<id>', _updateAddress)
    ..delete('/api/addresses/<id>', _deleteAddress)
    ..get('/api/favorites', _listFavorites)
    ..post('/api/favorites/<id>', _addFavorite)
    ..delete('/api/favorites/<id>', _removeFavorite)
    ..post('/api/coupons/validate', _validateCoupon)
    ..post('/api/orders', _createOrder)
    ..get('/api/orders', _listOrders)
    ..get('/api/orders/<id>', _order)
    ..post('/api/orders/<id>/cancel', _cancelOrder)
    ..post('/api/orders/<id>/review', _reviewOrder)
    ..get('/api/partner/summary', _partnerSummary)
    ..get('/api/partner/orders', _partnerOrders)
    ..post('/api/partner/orders/<id>/accept', _partnerAccept)
    ..post('/api/partner/orders/<id>/reject', _partnerReject)
    ..post('/api/partner/orders/<id>/preparing', _partnerPreparing)
    ..post('/api/partner/orders/<id>/ready', _partnerReady)
    ..get('/api/partner/products', _partnerProducts)
    ..post('/api/partner/product-images', _partnerUploadProductImage)
    ..post('/api/partner/products', _partnerCreateProduct)
    ..patch('/api/partner/products/<id>', _partnerUpdateProduct)
    ..delete('/api/partner/products/<id>', _partnerDeleteProduct)
    ..get('/api/partner/establishment', _partnerEstablishment)
    ..patch('/api/partner/establishment', _partnerUpdateEstablishment)
    ..get('/api/delivery/assignments', _deliveryAssignments)
    ..get('/api/delivery/history', _deliveryHistory)
    ..post('/api/delivery/assignments/<id>/accept', _deliveryAccept)
    ..post('/api/delivery/assignments/<id>/decline', _deliveryDecline)
    ..post('/api/delivery/assignments/<id>/start', _deliveryStart)
    ..post('/api/delivery/assignments/<id>/location', _deliveryLocation)
    ..post('/api/delivery/assignments/<id>/complete', _deliveryComplete)
    ..get('/api/admin/summary', _adminSummary)
    ..get('/api/admin/partners', _adminPartners)
    ..post('/api/admin/partners', _adminCreatePartner)
    ..post('/api/admin/partner-images', _adminUploadPartnerImage)
    ..post('/api/admin/partners/<id>/approve', _adminApprovePartner)
    ..post('/api/admin/partners/<id>/reject', _adminRejectPartner)
    ..get('/api/admin/users', _adminUsers)
    ..patch('/api/admin/users/<id>', _adminUpdateUser)
    ..get('/api/admin/orders', _adminOrders)
    ..get('/api/admin/audit', _adminAudit)
    ..post('/api/admin/categories', _adminCreateCategory)
    ..patch('/api/admin/categories/<id>', _adminUpdateCategory)
    ..delete('/api/admin/categories/<id>', _adminDeleteCategory)
    ..delete('/api/admin/establishments/<id>', _adminDeleteEstablishment)
    ..delete('/api/admin/users/<id>', _adminDeleteUser)
    // Candidaturas públicas (estabelecimento / entregador).
    ..post('/api/applications', _createApplication)
    ..post('/api/applications/images', _uploadApplicationImage)
    ..get('/api/applications/me', _myApplication)
    // Admin: gestão de candidaturas.
    ..get('/api/admin/applications', _adminApplications)
    ..post('/api/admin/applications/<id>/approve', _adminApproveApplication)
    ..post('/api/admin/applications/<id>/reject', _adminRejectApplication)
    ..post('/api/admin/applications/<id>/changes', _adminRequestChanges)
    // Admin: funcionários e permissões.
    ..get('/api/admin/employees', _adminEmployees)
    ..post('/api/admin/employees', _adminCreateEmployee)
    ..patch('/api/admin/employees/<id>', _adminUpdateEmployee)
    ..delete('/api/admin/employees/<id>', _adminDeleteEmployee)
    // Notificações persistentes.
    ..get('/api/notifications', _listNotifications)
    ..post('/api/notifications/read', _markNotificationsRead)
    ..get('/api/admin/notifications', _adminNotifications)
    // Chat e chamadas (FASE 13).
    ..get('/api/conversations', _listConversations)
    ..post('/api/conversations', _createConversation)
    ..get('/api/conversations/<id>/messages', _listMessages)
    ..post('/api/conversations/<id>/messages', _sendMessage)
    ..post('/api/conversations/<id>/read', _markMessagesRead)
    ..get('/api/call-logs', _listCallLogs)
    ..post('/api/call-logs', _logCall);

  // ---------------------------------------------------------------- middleware

  Middleware _cors() => (inner) => (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };

  Map<String, String> get _corsHeaders => {
        'access-control-allow-origin': allowedOrigin,
        'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
        'access-control-allow-headers': 'content-type,authorization',
      };

  Middleware _requestLogger() => (inner) => (request) async {
        final watch = Stopwatch()..start();
        final response = await inner(request);
        watch.stop();
        // ignore: avoid_print
        print(
          '${request.method} ${request.url.path} -> ${response.statusCode} '
          '(${watch.elapsedMilliseconds} ms)',
        );
        return response;
      };

  Middleware _errors() => (inner) => (request) async {
        try {
          return await inner(request);
        } on ApiError catch (error) {
          return jsonResponse(
            {
              'error': {'code': error.code, 'message': error.message}
            },
            status: error.status,
          );
        } on JWTException {
          return jsonResponse(
            {
              'error': {
                'code': 'unauthorized',
                'message':
                    'Sessão inválida ou expirada. Inicie sessão novamente.',
              },
            },
            status: 401,
          );
        } catch (error, stack) {
          // ignore: avoid_print
          print('Erro interno: $error\n$stack');
          return jsonResponse(
            {
              'error': {
                'code': 'internal_error',
                'message': 'Ocorreu um erro interno. Tente novamente.',
              },
            },
            status: 500,
          );
        }
      };

  // ------------------------------------------------------------------- helpers

  /// Verifica a saúde do serviço tocando efectivamente na base de dados —
  /// um SQLite feito falhar deixa de reportar "ok" por engano.
  Future<Response> _health(Request _) async {
    try {
      db.select('SELECT 1');
      return jsonResponse({'status': 'ok'});
    } catch (error) {
      return jsonResponse(
        {
          'status': 'degraded',
          'detail': '$error',
        },
        status: 503,
      );
    }
  }

  /// IP do cliente: directo no shelf_io, ou o primeiro valor de
  /// `x-forwarded-for` quando atrás de um proxy (Render, nginx, etc.).
  static String _clientIp(Request request) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded.split(',').first.trim();
    }
    final info = request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) return info.remoteAddress.address;
    return 'unknown';
  }

  /// Registro em memória de tentativas por bucket. Suficiente para uma
  /// única instância SQLite; altamente específico para login/registo.
  final Map<String, List<DateTime>> _attempts = {};

  void _checkRateLimit(
    Request request, {
    required String bucket,
    required int maxAttempts,
    required Duration window,
  }) {
    final key = '$bucket|${_clientIp(request)}';
    final cutoff = DateTime.now().subtract(window);
    final hits = _attempts.putIfAbsent(key, () => <DateTime>[])
      ..removeWhere((hit) => hit.isBefore(cutoff));
    if (hits.length >= maxAttempts) {
      throw ApiError(
        429,
        'rate_limited',
        'Demasiadas tentativas. Aguarde um momento e tente novamente.',
      );
    }
  }

  /// Registra uma tentativa repórter (falha de credenciais, requisição de
  /// registo). Chamado *após* a verificação, o que deixa os logins legítimos
  /// contínuos sem acumular, ao mesmo tempo que bloqueia força-bruta pelas
  /// falhas repetidas.
  void _recordRateLimitHit(
    Request request, {
    required String bucket,
    required Duration window,
  }) {
    final key = '$bucket|${_clientIp(request)}';
    final cutoff = DateTime.now().subtract(window);
    _attempts.putIfAbsent(key, () => <DateTime>[])
      ..removeWhere((hit) => hit.isBefore(cutoff))
      ..add(DateTime.now());
  }

  Future<Map<String, dynamic>> readBody(Request request) => _readBodyLimited(
        request,
        maxBytes: 1024 * 1024,
        tooLargeCode: 'body_too_large',
        tooLargeMessage: 'O corpo do pedido é demasiado grande.',
      );

  Future<Map<String, dynamic>> _readBodyLimited(
    Request request, {
    required int maxBytes,
    String tooLargeCode = 'image_too_large',
    String tooLargeMessage = 'A imagem excede o tamanho máximo.',
  }) async {
    final contentLength = int.tryParse(request.headers['content-length'] ?? '');
    if (contentLength != null && contentLength > maxBytes) {
      throw ApiError(413, tooLargeCode, tooLargeMessage);
    }

    final bytes = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk in request.read()) {
      totalBytes += chunk.length;
      if (totalBytes > maxBytes) {
        throw ApiError(413, tooLargeCode, tooLargeMessage);
      }
      bytes.add(chunk);
    }

    final String raw;
    try {
      raw = utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw ApiError(400, 'invalid_body', 'Corpo do pedido inválido.');
    }
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw ApiError(400, 'invalid_body', 'Corpo do pedido inválido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiError(400, 'invalid_body', 'Corpo do pedido inválido.');
    }
    return decoded;
  }

  String requiredString(
    Map<String, dynamic> body,
    String key, {
    int min = 1,
    int max = 500,
    String label = 'campo',
  }) {
    final value = body[key];
    if (value is! String || value.trim().length < min) {
      throw ApiError(422, 'invalid_$key', 'Preencha corretamente o $label.');
    }
    final trimmed = value.trim();
    if (trimmed.length > max) {
      throw ApiError(422, 'invalid_$key', 'O $label é demasiado longo.');
    }
    return trimmed;
  }

  int intValue(dynamic value, {int? min, int? max, int fallback = 0}) {
    final parsed = value is int ? value : int.tryParse('$value') ?? fallback;
    if (min != null && parsed < min) {
      throw ApiError(422, 'invalid_value', 'Valor abaixo do mínimo.');
    }
    if (max != null && parsed > max) {
      throw ApiError(422, 'invalid_value', 'Valor acima do máximo.');
    }
    return parsed;
  }

  (double?, double?) coordinates(
    Map<String, dynamic> body, {
    String latitudeKey = 'latitude',
    String longitudeKey = 'longitude',
    double? currentLatitude,
    double? currentLongitude,
  }) {
    if (!body.containsKey(latitudeKey) && !body.containsKey(longitudeKey)) {
      return (currentLatitude, currentLongitude);
    }
    final latitude = body[latitudeKey];
    final longitude = body[longitudeKey];
    if (latitude == null && longitude == null) return (null, null);
    if (latitude is! num ||
        longitude is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ApiError(
        422,
        'invalid_coordinates',
        'Indique coordenadas válidas de latitude e longitude.',
      );
    }
    return (latitude.toDouble(), longitude.toDouble());
  }

  AuthUser? optionalUser(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return _userFromToken(header.substring(7));
  }

  AuthUser requireUser(Request request) {
    final user = optionalUser(request);
    if (user == null) {
      throw ApiError(401, 'unauthorized', 'Inicie sessão para continuar.');
    }
    return user;
  }

  AuthUser requireRole(Request request, List<String> roles) {
    final user = requireUser(request);
    if (!roles.contains(user.role)) {
      throw ApiError(
        403,
        'forbidden',
        'Não tem permissão para esta operação.',
      );
    }
    return user;
  }

  /// Admin **ou** funcionário com a permissão indicada (FASE 10).
  ///
  /// As permissões ficam na tabela `employees` e são aplicadas **no
  /// servidor**: a interface apenas esconde o que o backend recusa mesmo
  /// assim. Administradores têm acesso total.
  AuthUser requirePermission(Request request, String permission) {
    final user = requireUser(request);
    if (user.role == 'admin') return user;
    if (user.role != 'employee') {
      throw ApiError(
        403,
        'forbidden',
        'Não tem permissão para esta operação.',
      );
    }
    final rows = db.select(
      'SELECT permissions FROM employees WHERE user_id = ?',
      [user.id],
    );
    final permissions = rows.isEmpty
        ? const <String>[]
        : _decodeList(rows.first['permissions']);
    if (!permissions.contains(permission)) {
      throw ApiError(
        403,
        'missing_permission',
        'A sua conta não tem a permissão "$permission".',
      );
    }
    return user;
  }

  /// Papel **e** conta aprovada: parceiros e estafetas só usam o painel
  /// depois de o administrador aprovar a candidatura
  /// (`users.approval_status = 'approved'`).
  ///
  /// Candidaturas pendentes/recusadas continuam a poder iniciar sessão (para
  /// acompanhar o estado em `/api/applications/me`), mas não passam daqui.
  AuthUser requireApprovedRole(Request request, String role) {
    final user = requireRole(request, [role]);
    final rows = db.select(
      'SELECT approval_status FROM users WHERE id = ?',
      [user.id],
    );
    final status = rows.isEmpty ? null : rows.first['approval_status'];
    if (status != 'approved') {
      throw ApiError(
        403,
        'pending_approval',
        'A sua candidatura ainda não foi aprovada pela plataforma.',
      );
    }
    return user;
  }

  AuthUser _userFromToken(String token) {
    final claims = jwt.verify(token);
    final rows = db.select(
      'SELECT * FROM users WHERE id = ? AND is_active = 1',
      [claims['sub']],
    );
    if (rows.isEmpty) {
      throw ApiError(401, 'unauthorized', 'Conta não encontrada ou inativa.');
    }
    final row = rows.first;
    if (row['token_version'] != claims['ver']) {
      throw ApiError(401, 'unauthorized', 'Sessão terminada.');
    }
    return AuthUser(
      id: row['id'] as String,
      role: row['role'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String,
      tokenVersion: row['token_version'] as int,
    );
  }

  Map<String, dynamic> userJson(Row row) => {
        'id': row['id'],
        'role': row['role'],
        'name': row['name'],
        'email': row['email'],
        'phone': row['phone'],
        'whatsapp': row['whatsapp'],
        'avatar_url': row['avatar_url'],
        'is_active': row['is_active'] == 1,
        // Estado da candidatura: parceiros/estafetas pendentes usam isto
        // para abrir o ecrã de estado em vez do painel bloqueado.
        'approval_status': row['approval_status'],
        // Funcionário: as permissões vão na sessão para a aplicação
        // mostrar apenas os separadores permitidos — cada rota continua
        // validada no servidor por `requirePermission`.
        if (row['role'] == 'employee')
          'permissions': _permissionsForUser(row['id'] as String),
        'created_at': row['created_at'],
      };

  /// Permissões da linha `employees` para o utilizador dado (vazio se não
  /// for funcionário ou não tiver linha).
  List<String> _permissionsForUser(String userId) {
    final rows = db.select(
      'SELECT permissions FROM employees WHERE user_id = ?',
      [userId],
    );
    return rows.isEmpty ? const [] : _decodeList(rows.first['permissions']);
  }

  void audit(
    String? actorId,
    String action,
    String entity,
    String? entityId, [
    Map<String, dynamic>? metadata,
  ]) {
    db.execute(
      '''
      INSERT INTO audit_logs (id, actor_id, action, entity, entity_id,
        metadata, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        newId(),
        actorId,
        action,
        entity,
        entityId,
        metadata == null ? null : jsonEncode(metadata),
        nowIso()
      ],
    );
  }

  Map<String, dynamic>? partnerEstablishment(AuthUser user) {
    final rows = db.select(
      'SELECT * FROM establishments WHERE owner_user_id = ? LIMIT 1',
      [user.id],
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Map<String, dynamic> requirePartnerEstablishment(AuthUser user) {
    final establishment = partnerEstablishment(user);
    if (establishment == null) {
      throw ApiError(
        403,
        'no_establishment',
        'A sua conta não está associada a um estabelecimento.',
      );
    }
    return establishment;
  }

  Map<String, dynamic> establishmentJson(Row row) {
    final open = row['is_open'] == 1 && row['is_approved'] == 1;
    return {
      'id': row['id'],
      'name': row['name'],
      'slug': row['slug'],
      'description': row['description'],
      'phone': row['phone'],
      'address': row['address'],
      'owner_user_id': row['owner_user_id'],
      'image_url': row['image_url'],
      // Número de identificação tributária do contribuinte (FASE 13).
      'nuit': row['nuit'],
      'delivery_fee_cents': row['delivery_fee_cents'],
      'prep_minutes': row['prep_minutes'],
      'opens_at': row['opens_at'],
      'closes_at': row['closes_at'],
      'is_open': open,
      'is_approved': row['is_approved'] == 1,
      'rating': row['rating'],
      'review_count': row['review_count'],
      'product_count': row['product_count'],
      'category_id': row['category_id'],
      'category_name': row['category_name'],
      'category_slug': row['category_slug'],
      // Localização no mapa (FASE 11): nulos quando o parceiro ainda não
      // marcou o ponto — o cliente degradar sem mapa em vez de quebrar.
      'latitude': row['latitude'],
      'longitude': row['longitude'],
    };
  }

  Map<String, dynamic> productJson(Row row) => {
        'id': row['id'],
        'establishment_id': row['establishment_id'],
        'name': row['name'],
        'description': row['description'],
        'price_cents': row['price_cents'],
        'category': row['category'],
        'image_url': row['image_url'],
        'stock': row['stock'],
        'is_available': row['is_available'] == 1,
        'updated_at': row['updated_at'],
      };

  Map<String, dynamic> addressJson(Row row) => {
        'id': row['id'],
        'label': row['label'],
        'line': row['line'],
        'reference': row['reference'],
        'city': row['city'],
        'is_default': row['is_default'] == 1,
        'latitude': row['latitude'],
        'longitude': row['longitude'],
      };

  Map<String, dynamic> orderJson(
    Map<String, dynamic> order, {
    bool includeCustomer = false,
    bool includeCourier = false,
    bool includeTracking = false,
  }) {
    final items = db.select(
      'SELECT * FROM order_items WHERE order_id = ? ORDER BY rowid',
      [order['id']],
    );
    final events = db.select(
      'SELECT order_id, status, note, created_at FROM order_events '
      'WHERE order_id = ? ORDER BY created_at',
      [order['id']],
    );
    final assignments = db.select(
      '''
      SELECT d.*, u.name AS courier_name, u.phone AS courier_phone
      FROM delivery_assignments d
      LEFT JOIN users u ON u.id = d.courier_id
      WHERE d.order_id = ?
      ''',
      [order['id']],
    );
    final establishment = db.select(
      'SELECT * FROM establishments WHERE id = ?',
      [order['establishment_id']],
    ).first;
    final customer = db.select(
      'SELECT id, name, phone FROM users WHERE id = ?',
      [order['customer_id']],
    ).first;
    return _orderJson(
      [order],
      items: items,
      events: events,
      assignments: assignments,
      establishments: [establishment],
      customers: [customer],
      includeCustomer: includeCustomer,
      includeCourier: includeCourier,
      includeTracking: includeTracking,
    ).first;
  }

  /// Serializa uma *lista* de pedidos com consultas em lote: em vez das
  /// 5 consultas por pedido do N+1 (até ~1.000 consultas por request em
  /// /api/admin/orders), faz 5 consultas por listagem inteira.
  List<Map<String, dynamic>> ordersJson(
    List<Map<String, dynamic>> orders, {
    bool includeCustomer = false,
    bool includeCourier = false,
    bool includeTracking = false,
  }) {
    if (orders.isEmpty) return const [];
    final ids = orders.map((o) => o['id'] as String).toList();
    final marks = List.filled(ids.length, '?').join(',');

    final items = db.select(
      'SELECT * FROM order_items WHERE order_id IN ($marks) ORDER BY rowid',
      ids,
    );
    final events = db.select(
      'SELECT order_id, status, note, created_at FROM order_events '
      'WHERE order_id IN ($marks) ORDER BY order_id, created_at',
      ids,
    );
    final assignments = db.select(
      '''
      SELECT d.*, u.name AS courier_name, u.phone AS courier_phone
      FROM delivery_assignments d
      LEFT JOIN users u ON u.id = d.courier_id
      WHERE d.order_id IN ($marks)
      ''',
      ids,
    );
    final establishmentIds = {
      for (final order in orders) order['establishment_id'] as String,
    };
    final establishments = db.select(
      'SELECT * FROM establishments WHERE id IN '
      '(${List.filled(establishmentIds.length, '?').join(',')})',
      establishmentIds.toList(),
    );
    final customerIds = {
      for (final order in orders) order['customer_id'] as String,
    };
    final customers = db.select(
      'SELECT id, name, phone FROM users WHERE id IN '
      '(${List.filled(customerIds.length, '?').join(',')})',
      customerIds.toList(),
    );
    return _orderJson(
      orders,
      items: items,
      events: events,
      assignments: assignments,
      establishments: establishments,
      customers: customers,
      includeCustomer: includeCustomer,
      includeCourier: includeCourier,
      includeTracking: includeTracking,
    );
  }

  Map<String, List<Row>> _groupBy(
    List<Row> rows,
    String Function(Row) keyOf,
  ) {
    final result = <String, List<Row>>{};
    for (final row in rows) {
      result.putIfAbsent(keyOf(row), () => []).add(row);
    }
    return result;
  }

  Object? _col(Row? row, String key) => row == null ? null : row[key];

  List<Map<String, dynamic>> _orderJson(
    List<Map<String, dynamic>> orders, {
    required List<Row> items,
    required List<Row> events,
    required List<Row> assignments,
    required List<Row> establishments,
    required List<Row> customers,
    required bool includeCustomer,
    required bool includeCourier,
    required bool includeTracking,
  }) {
    final itemsByOrder = _groupBy(items, (row) => row['order_id'] as String);
    final eventsByOrder = _groupBy(events, (row) => row['order_id'] as String);
    final assignmentsByOrder =
        _groupBy(assignments, (row) => row['order_id'] as String);
    final establishmentById = {
      for (final row in establishments) row['id'] as String: row,
    };
    final customerById = {
      for (final row in customers) row['id'] as String: row,
    };

    return [
      for (final order in orders)
        () {
          final establishment = establishmentById[order['establishment_id']];
          final customer = customerById[order['customer_id']];
          final orderItems = itemsByOrder[order['id']] ?? const <Row>[];
          final orderEvents = eventsByOrder[order['id']] ?? const <Row>[];
          final orderAssignments =
              assignmentsByOrder[order['id']] ?? const <Row>[];
          return <String, dynamic>{
            'id': order['id'],
            'number': order['number'],
            'status': order['status'],
            'payment_method': order['payment_method'],
            'payment_status': order['payment_status'],
            'currency': order['currency'],
            'subtotal_cents': order['subtotal_cents'],
            'delivery_fee_cents': order['delivery_fee_cents'],
            'discount_cents': order['discount_cents'],
            'total_cents': order['total_cents'],
            'coupon_code': order['coupon_code'],
            'address_label': order['address_label'],
            'address_line': order['address_line'],
            if (includeTracking &&
                order['status'] == 'on_the_way' &&
                order['address_latitude'] != null &&
                order['address_longitude'] != null) ...{
              'address_latitude': order['address_latitude'],
              'address_longitude': order['address_longitude'],
            },
            'phone': order['phone'],
            'note': order['note'],
            'rejection_reason': order['rejection_reason'],
            'cancellation_reason': order['cancellation_reason'],
            'created_at': order['created_at'],
            'updated_at': order['updated_at'],
            'establishment': {
              'id': _col(establishment, 'id'),
              'name': _col(establishment, 'name'),
              'slug': _col(establishment, 'slug'),
              'address': _col(establishment, 'address'),
              'phone': _col(establishment, 'phone'),
              'category_id': _col(establishment, 'category_id'),
              'delivery_fee_cents': _col(establishment, 'delivery_fee_cents'),
            },
            'customer': {
              'name': _col(customer, 'name'),
              'phone': includeCustomer ? _col(customer, 'phone') : null,
            },
            'items': [
              for (final item in orderItems)
                {
                  'id': item['id'],
                  'product_id': item['product_id'],
                  'name': item['name_snapshot'],
                  'unit_price_cents': item['unit_price_cents'],
                  'quantity': item['quantity'],
                  'line_total_cents': item['line_total_cents'],
                  'note': item['note'],
                },
            ],
            'events': [
              for (final event in orderEvents)
                {
                  'status': event['status'],
                  'note': event['note'],
                  'created_at': event['created_at'],
                },
            ],
            'delivery': orderAssignments.isEmpty
                ? null
                : {
                    'id': orderAssignments.first['id'],
                    'status': orderAssignments.first['status'],
                    'courier_name': orderAssignments.first['courier_name'],
                    'courier_phone': includeCourier
                        ? orderAssignments.first['courier_phone']
                        : null,
                    'accepted_at': orderAssignments.first['accepted_at'],
                    'departed_at': orderAssignments.first['departed_at'],
                    'completed_at': orderAssignments.first['completed_at'],
                    if (includeTracking &&
                        order['status'] == 'on_the_way' &&
                        orderAssignments.first['latitude'] != null &&
                        orderAssignments.first['longitude'] != null) ...{
                      'latitude': orderAssignments.first['latitude'],
                      'longitude': orderAssignments.first['longitude'],
                      'location_updated_at':
                          orderAssignments.first['location_updated_at'],
                    },
                  },
          };
        }(),
    ];
  }

  Map<String, dynamic> loadOrder(String id) {
    final rows = db.select('SELECT * FROM orders WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Pedido não encontrado.');
    }
    return Map<String, dynamic>.from(rows.first);
  }

  bool canAccessOrder(AuthUser user, Map<String, dynamic> order) {
    if (user.isAdmin) return true;
    if (user.isCustomer && order['customer_id'] == user.id) return true;
    if (user.isPartner) {
      final establishment = partnerEstablishment(user);
      return establishment != null &&
          establishment['id'] == order['establishment_id'];
    }
    if (user.isDelivery) {
      final rows = db.select(
        'SELECT 1 FROM delivery_assignments WHERE order_id = ? AND '
        '(courier_id = ? OR status = ?)',
        [order['id'], user.id, 'available'],
      );
      return rows.isNotEmpty;
    }
    return false;
  }

  void addEvent(String orderId, String status, String? actorId,
      [String? note]) {
    db.execute(
      'INSERT INTO order_events (id, order_id, status, note, actor_id, '
      'created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [newId(), orderId, status, note, actorId, nowIso()],
    );
  }

  void setOrderStatus(
    String orderId,
    String status, {
    String? actorId,
    String? note,
    String? rejectionReason,
    String? cancellationReason,
  }) {
    db.execute(
      '''
      UPDATE orders SET status = ?, updated_at = ?,
        rejection_reason = COALESCE(?, rejection_reason),
        cancellation_reason = COALESCE(?, cancellation_reason)
      WHERE id = ?
      ''',
      [status, nowIso(), rejectionReason, cancellationReason, orderId],
    );
    addEvent(orderId, status, actorId, note);

    // Notificação persistente ao cliente (FASE 12): cada mudança de estado
    // da encomenda fica no centro de notificações. Quem cancela a própria
    // encomenda não recebe aviso do que já sabe fazer.
    final orderRows = db.select(
      'SELECT customer_id, number FROM orders WHERE id = ?',
      [orderId],
    );
    if (orderRows.isNotEmpty) {
      final customerId = orderRows.first['customer_id'] as String?;
      if (customerId != null && customerId != actorId) {
        final (title, body) = _orderStatusNotification(
          status,
          '${orderRows.first['number']}',
          note,
        );
        _notify(customerId, 'order_$status', title, body, data: {
          'order_id': orderId,
          'status': status,
        });
      }
    }
  }

  /// Texto da notificação de mudança de estado de uma encomenda.
  (String, String) _orderStatusNotification(
    String status,
    String number,
    String? note,
  ) {
    final suffix = (note == null || note.isEmpty) ? '' : ' $note';
    return switch (status) {
      'confirmed' => (
        'Encomenda confirmada',
        'O estabelecimento aceitou o teu pedido #$number.$suffix',
      ),
      'preparing' => (
        'Encomenda em preparação',
        'O estabelecimento está a preparar o teu pedido #$number.$suffix',
      ),
      'ready' => (
        'Encomenda pronta',
        'O pedido #$number está pronto para sair.$suffix',
      ),
      'on_the_way' => (
        'Encomenda a caminho',
        'O estafeta está a caminho com o teu pedido #$number.$suffix',
      ),
      'delivered' => (
        'Encomenda entregue',
        'O teu pedido #$number foi entregue. Bom apetite!',
      ),
      'rejected' => (
        'Encomenda recusada',
        'O estabelecimento recusou o pedido #$number.$suffix',
      ),
      'cancelled' => (
        'Encomenda cancelada',
        'O pedido #$number foi cancelado.$suffix',
      ),
      _ => ('Atualização do pedido', 'O pedido #$number foi atualizado.'),
    };
  }

  Map<String, dynamic> authResponse(Row user) => {
        'token': jwt.issue(
          AuthUser(
            id: user['id'] as String,
            role: user['role'] as String,
            name: user['name'] as String,
            email: user['email'] as String,
            phone: user['phone'] as String,
            tokenVersion: user['token_version'] as int,
          ),
        ),
        'user': userJson(user),
      };

  // --------------------------------------------------------------------- auth

  Future<Response> _register(Request request) async {
    const window = Duration(minutes: 10);
    _checkRateLimit(
      request,
      bucket: 'register',
      maxAttempts: 5,
      window: window,
    );
    _recordRateLimitHit(request, bucket: 'register', window: window);
    final body = await readBody(request);
    final name = requiredString(body, 'name', min: 2, max: 80, label: 'nome');
    final phone = requiredString(
      body,
      'phone',
      min: 9,
      max: 20,
      label: 'telemóvel',
    ).replaceAll(RegExp(r'[^0-9]'), '');
    final password = requiredString(
      body,
      'password',
      min: 8,
      max: 200,
      label: 'palavra-passe',
    );

    // E-mail opcional no registo de clientes: a coluna `users.email` é
    // NOT NULL UNIQUE e o SQLite não permite afrouxar isso por migração,
    // por isso, quando omitido, deriva-se um endereço interno estável a
    // partir do telefone (nunca recebe correspondência — não há SMTP).
    final rawEmail = body['email'];
    final String email;
    if (rawEmail is String && rawEmail.trim().isNotEmpty) {
      email = rawEmail.trim().toLowerCase();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        throw ApiError(422, 'invalid_email', 'Indique um email válido.');
      }
    } else {
      email = '$phone@clientes.nacala.delivery';
    }

    // WhatsApp opcional (pode diferir do telemóvel principal).
    final rawWhatsapp = body['whatsapp'];
    String? whatsapp;
    if (rawWhatsapp is String && rawWhatsapp.trim().isNotEmpty) {
      whatsapp = rawWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(whatsapp)) {
        throw ApiError(
          422,
          'invalid_whatsapp',
          'Indique um número de WhatsApp moçambicano válido (ex.: 84 123 4567).',
        );
      }
    }

    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      throw ApiError(
        422,
        'invalid_phone',
        'Indique um número moçambicano válido (ex.: 84 123 4567).',
      );
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw ApiError(
        422,
        'weak_password',
        'A palavra-passe deve ter letras e números (mínimo 8 caracteres).',
      );
    }

    final existing = db.select(
      'SELECT id FROM users WHERE email = ? OR phone = ?',
      [email, phone],
    );
    if (existing.isNotEmpty) {
      throw ApiError(
        409,
        'already_registered',
        'Já existe uma conta com este email ou telemóvel.',
      );
    }

    final digest = await hashPasswordAsync(password);
    // Código de recuperação: devolvido uma única vez nesta resposta e
    // guardado apenas como hash (não há email/SMS para o reenviar).
    final recoveryCode = generateRecoveryCode();
    // Hash sobre a forma canónica (sem traço/maiúsculas), para que
    // `_recover` aceite o código escrito de qualquer forma.
    final recoveryDigest = await hashPasswordAsync(
      canonicalRecoveryCode(recoveryCode),
    );
    final id = newId();
    db.execute(
      '''
      INSERT INTO users (id, role, name, email, phone, whatsapp,
        password_hash, password_salt, recovery_code_hash, recovery_code_salt,
        token_version, is_active, created_at)
      VALUES (?, 'customer', ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?)
      ''',
      [
        id,
        name,
        email,
        phone,
        whatsapp,
        digest.hash,
        digest.salt,
        recoveryDigest.hash,
        recoveryDigest.salt,
        nowIso(),
      ],
    );
    final user = db.select('SELECT * FROM users WHERE id = ?', [id]).first;
    return jsonResponse({
      ...authResponse(user),
      'recovery_code': recoveryCode,
    }, status: 201);
  }

  /// Troca a palavra-passe usando o código de recuperação gerado no
  /// registo. Em caso de sucesso: nova sessão (auto-login), rotação do
  /// código (o antigo deixa de valer) e invalidação das sessões antigas
  /// (`token_version + 1`).
  Future<Response> _recover(Request request) async {
    const window = Duration(minutes: 10);
    _checkRateLimit(
      request,
      bucket: 'recover',
      maxAttempts: 5,
      window: window,
    );
    _recordRateLimitHit(request, bucket: 'recover', window: window);
    final body = await readBody(request);
    final identifier = requiredString(
      body,
      'identifier',
      min: 3,
      max: 120,
      label: 'email ou telemóvel',
    );
    final code = requiredString(
      body,
      'code',
      min: 6,
      max: 32,
      label: 'código de recuperação',
    );
    final password = requiredString(
      body,
      'password',
      min: 8,
      max: 200,
      label: 'palavra-passe',
    );
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw ApiError(
        422,
        'weak_password',
        'A palavra-passe deve ter letras e números (mínimo 8 caracteres).',
      );
    }

    final digits = identifier.replaceAll(RegExp(r'[^0-9]'), '');
    final rows = db.select(
      'SELECT * FROM users WHERE lower(email) = ? OR phone = ?',
      [identifier.toLowerCase(), digits],
    );
    final row = rows.isEmpty ? null : rows.first;
    final storedHash = row?['recovery_code_hash'] as String?;
    final storedSalt = row?['recovery_code_salt'] as String?;
    final valid =
        row != null &&
        storedHash != null &&
        storedSalt != null &&
        await verifyPasswordAsync(
          canonicalRecoveryCode(code),
          storedHash,
          storedSalt,
        );
    if (row == null || !valid) {
      // Mensagem única para "não existe conta", "sem código" e "código
      // errado": não se revela qual dos casos falhou.
      throw ApiError(
        422,
        'invalid_recovery',
        'Identificador ou código de recuperação inválido.',
      );
    }

    final digest = await hashPasswordAsync(password);
    final rotatedCode = generateRecoveryCode();
    final rotatedDigest = await hashPasswordAsync(
      canonicalRecoveryCode(rotatedCode),
    );
    final userId = row['id'] as String;
    db.execute(
      '''
      UPDATE users SET password_hash = ?, password_salt = ?,
        recovery_code_hash = ?, recovery_code_salt = ?,
        token_version = token_version + 1
      WHERE id = ?
      ''',
      [
        digest.hash,
        digest.salt,
        rotatedDigest.hash,
        rotatedDigest.salt,
        userId,
      ],
    );
    audit(userId, 'auth.recover', 'user', userId);
    final updated = db.select('SELECT * FROM users WHERE id = ?', [userId]).first;
    return jsonResponse({
      ...authResponse(updated),
      'recovery_code': rotatedCode,
    });
  }

  /// Emite um novo código de recuperação para a conta autenticada (o
  /// anterior deixa de valer). Feito a partir da área de conta — também
  /// serve de substituto quando o utilizador perdeu o código original.
  Future<Response> _regenerateRecoveryCode(Request request) async {
    const window = Duration(minutes: 10);
    _checkRateLimit(
      request,
      bucket: 'recovery-code',
      maxAttempts: 5,
      window: window,
    );
    _recordRateLimitHit(request, bucket: 'recovery-code', window: window);
    final user = requireUser(request);
    final code = generateRecoveryCode();
    // Igual ao registo: hash sobre a forma canónica do código.
    final digest = await hashPasswordAsync(canonicalRecoveryCode(code));
    db.execute(
      'UPDATE users SET recovery_code_hash = ?, recovery_code_salt = ? '
      'WHERE id = ?',
      [digest.hash, digest.salt, user.id],
    );
    audit(user.id, 'auth.recovery_code.regenerate', 'user', user.id);
    return jsonResponse({'recovery_code': code});
  }

  Future<Response> _login(Request request) async {
    _checkRateLimit(
      request,
      bucket: 'login',
      maxAttempts: 10,
      window: const Duration(minutes: 1),
    );
    final body = await readBody(request);
    final identifier = requiredString(
      body,
      'identifier',
      min: 3,
      label: 'email ou telemóvel',
    );
    final password = requiredString(
      body,
      'password',
      min: 1,
      label: 'palavra-passe',
    );
    final cleaned =
        identifier.toLowerCase().replaceAll(RegExp(r'[^0-9a-z@._-]'), '');
    final rows = db.select(
      'SELECT * FROM users WHERE lower(email) = ? OR phone = ?',
      [cleaned, identifier.replaceAll(RegExp(r'[^0-9]'), '')],
    );
    final valid = rows.isNotEmpty &&
        await verifyPasswordAsync(
          password,
          rows.first['password_hash'] as String,
          rows.first['password_salt'] as String,
        );
    if (!valid) {
      _recordRateLimitHit(
        request,
        bucket: 'login',
        window: const Duration(minutes: 1),
      );
      audit(
        null,
        'login_failed',
        'auth',
        cleaned,
        {'ip': _clientIp(request)},
      );
      throw ApiError(
        401,
        'invalid_credentials',
        'Email/telemóvel ou palavra-passe incorretos.',
      );
    }
    if (rows.first['is_active'] != 1) {
      throw ApiError(403, 'inactive', 'Esta conta está desativada.');
    }
    return jsonResponse(authResponse(rows.first));
  }

  Future<Response> _me(Request request) async {
    final user = requireUser(request);
    final row = db.select('SELECT * FROM users WHERE id = ?', [user.id]).first;
    final addresses = db.select(
      'SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, '
      'created_at',
      [user.id],
    );
    return jsonResponse({
      'user': userJson(row),
      'addresses': [for (final a in addresses) addressJson(a)],
    });
  }

  Future<Response> _updateProfile(Request request) async {
    final user = requireUser(request);
    final body = await readBody(request);
    final name = requiredString(body, 'name', min: 2, max: 80, label: 'nome');
    final phone = requiredString(
      body,
      'phone',
      min: 9,
      max: 20,
      label: 'telemóvel',
    ).replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      throw ApiError(422, 'invalid_phone', 'Número de telemóvel inválido.');
    }
    final taken = db.select(
      'SELECT id FROM users WHERE phone = ? AND id != ?',
      [phone, user.id],
    );
    if (taken.isNotEmpty) {
      throw ApiError(409, 'phone_taken', 'Este telemóvel já está em uso.');
    }
    final email = (body['email'] as String?)?.trim() ?? '';
    if (email.isNotEmpty) {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        throw ApiError(422, 'invalid_email', 'Indique um email válido.');
      }
      final owner = db.select(
        'SELECT id FROM users WHERE email = ? AND id != ?',
        [email, user.id],
      );
      if (owner.isNotEmpty) {
        throw ApiError(409, 'email_taken', 'Este email já está em uso.');
      }
    }
    // WhatsApp: chave ausente → mantém o valor atual; vazia → limpa;
    // preenchida → valida o formato moçambicano.
    final hasWhatsappKey = body.containsKey('whatsapp');
    String? whatsapp;
    if (hasWhatsappKey) {
      final raw = (body['whatsapp'] as String?)?.trim() ?? '';
      if (raw.isNotEmpty) {
        whatsapp = raw.replaceAll(RegExp(r'[^0-9]'), '');
        if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(whatsapp)) {
          throw ApiError(
            422,
            'invalid_whatsapp',
            'Indique um número de WhatsApp moçambicano válido.',
          );
        }
      }
    }
    final sets = <String>['name = ?', 'phone = ?'];
    final args = <Object?>[name, phone];
    if (email.isNotEmpty) {
      sets.add('email = ?');
      args.add(email);
    }
    if (hasWhatsappKey) {
      sets.add('whatsapp = ?');
      args.add(whatsapp);
    }
    args.add(user.id);
    db.execute(
      'UPDATE users SET ${sets.join(', ')} WHERE id = ?',
      args,
    );
    final row = db.select('SELECT * FROM users WHERE id = ?', [user.id]).first;
    return jsonResponse({'user': userJson(row)});
  }

  Future<Response> _changePassword(Request request) async {
    final user = requireUser(request);
    final body = await readBody(request);
    final current = requiredString(
      body,
      'current_password',
      min: 1,
      label: 'palavra-passe atual',
    );
    final next = requiredString(
      body,
      'new_password',
      min: 8,
      max: 200,
      label: 'nova palavra-passe',
    );
    final row = db.select('SELECT * FROM users WHERE id = ?', [user.id]).first;
    if (!await verifyPasswordAsync(
      current,
      row['password_hash'] as String,
      row['password_salt'] as String,
    )) {
      throw ApiError(
          422, 'wrong_password', 'A palavra-passe atual não confere.');
    }
    final digest = await hashPasswordAsync(next);
    db.execute(
      'UPDATE users SET password_hash = ?, password_salt = ?, '
      'token_version = token_version + 1 WHERE id = ?',
      [digest.hash, digest.salt, user.id],
    );
    final updated =
        db.select('SELECT * FROM users WHERE id = ?', [user.id]).first;
    return jsonResponse(authResponse(updated));
  }

  Future<Response> _logout(Request request) async {
    final user = requireUser(request);
    db.execute(
      'UPDATE users SET token_version = token_version + 1 WHERE id = ?',
      [user.id],
    );
    return jsonResponse({'ok': true});
  }

  // ----------------------------------------------------------------- catalogue

  Future<Response> _categories(Request request) async {
    final rows = db.select(
      '''
      SELECT c.*, (SELECT COUNT(*) FROM establishments e
        WHERE e.category_id = c.id AND e.is_approved = 1) AS establishment_count
      FROM categories c ORDER BY c.sort_order, c.name
      ''',
    );
    return jsonResponse({
      'categories': [
        for (final row in rows)
          {
            'id': row['id'],
            'name': row['name'],
            'slug': row['slug'],
            'icon': row['icon'],
            'image_url': row['image_url'],
            'establishment_count': row['establishment_count'],
          },
      ],
    });
  }

  static const _establishmentSelect = '''
    SELECT e.*, c.name AS category_name, c.slug AS category_slug,
      COALESCE((SELECT ROUND(AVG(r.rating), 1) FROM reviews r
        WHERE r.establishment_id = e.id), 0) AS rating,
      (SELECT COUNT(*) FROM reviews r WHERE r.establishment_id = e.id)
        AS review_count,
      (SELECT COUNT(*) FROM products p WHERE p.establishment_id = e.id
        AND p.is_available = 1) AS product_count
    FROM establishments e
    JOIN categories c ON c.id = e.category_id
  ''';

  Future<Response> _establishments(Request request) async {
    final params = request.url.queryParameters;
    final where = <String>['e.is_approved = 1'];
    final args = <Object?>[];
    if (params['category'] != null && params['category']!.isNotEmpty) {
      where.add('(c.slug = ? OR c.id = ?)');
      args.add(params['category']);
      args.add(params['category']);
    }
    if (params['q'] != null && params['q']!.trim().isNotEmpty) {
      where
          .add('(normalize(e.name) LIKE ? OR normalize(e.description) LIKE ?)');
      final term = '%${normalizeText(params['q']!.trim())}%';
      args.add(term);
      args.add(term);
    }
    if (params['open'] == '1') {
      where.add('e.is_open = 1');
    }
    final sort = switch (params['sort']) {
      'fee' => 'e.delivery_fee_cents ASC',
      'time' => 'e.prep_minutes ASC',
      'rating' => 'rating DESC',
      _ => 'e.name ASC',
    };
    final (limit, offset) = _pagination(request, defaultLimit: 200);
    final rows = db.select(
      '$_establishmentSelect WHERE ${where.join(' AND ')} '
      'ORDER BY $sort LIMIT ? OFFSET ?',
      [...args, limit + 1, offset],
    );
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit).toList() : rows;
    return jsonResponse({
      'establishments': [for (final row in pageRows) establishmentJson(row)],
      'has_more': hasMore,
    });
  }

  Future<Response> _establishment(Request request, String id) async {
    final rows = db.select(
      '$_establishmentSelect WHERE e.id = ? AND e.is_approved = 1',
      [id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Estabelecimento não encontrado.');
    }
    final products = db.select(
      'SELECT * FROM products WHERE establishment_id = ? '
      'ORDER BY category, name',
      [id],
    );
    final reviews = db.select(
      '''
      SELECT r.rating, r.comment, r.created_at, u.name AS customer_name
      FROM reviews r JOIN users u ON u.id = r.customer_id
      WHERE r.establishment_id = ? ORDER BY r.created_at DESC LIMIT 10
      ''',
      [id],
    );
    return jsonResponse({
      'establishment': establishmentJson(rows.first),
      'products': [for (final p in products) productJson(p)],
      'reviews': [
        for (final r in reviews)
          {
            'rating': r['rating'],
            'comment': r['comment'],
            'created_at': r['created_at'],
            'customer_name': r['customer_name'],
          },
      ],
    });
  }

  Future<Response> _establishmentProducts(Request request, String id) async {
    final rows = db.select(
      'SELECT * FROM products WHERE establishment_id = ? ORDER BY category, name',
      [id],
    );
    return jsonResponse({
      'products': [for (final p in rows) productJson(p)],
    });
  }

  Future<Response> _products(Request request) async {
    final params = request.url.queryParameters;
    final where = <String>['p.is_available = 1', 'e.is_approved = 1'];
    final args = <Object?>[];
    if (params['q'] != null && params['q']!.trim().isNotEmpty) {
      where
          .add('(normalize(p.name) LIKE ? OR normalize(p.description) LIKE ?)');
      final term = '%${normalizeText(params['q']!.trim())}%';
      args.add(term);
      args.add(term);
    }
    if (params['establishment'] != null) {
      where.add('p.establishment_id = ?');
      args.add(params['establishment']);
    }
    if (params['category'] != null) {
      where.add('p.category = ?');
      args.add(params['category']);
    }
    final rows = db.select(
      '''
      SELECT p.*, e.name AS establishment_name
      FROM products p JOIN establishments e ON e.id = p.establishment_id
      WHERE ${where.join(' AND ')}
      ORDER BY p.name LIMIT 60
      ''',
      args,
    );
    return jsonResponse({
      'products': [
        for (final row in rows)
          {
            ...productJson(row),
            'establishment_name': row['establishment_name']
          },
      ],
    });
  }

  Future<Response> _search(Request request) async {
    final q = request.url.queryParameters['q']?.trim() ?? '';
    if (q.length < 2) {
      return jsonResponse({
        'query': q,
        'establishments': <Object>[],
        'products': <Object>[],
        'categories': <Object>[],
      });
    }
    final term = '%${normalizeText(q)}%';
    final establishments = db.select(
      '$_establishmentSelect WHERE e.is_approved = 1 AND '
      '(normalize(e.name) LIKE ? OR normalize(e.description) LIKE ?) '
      'ORDER BY e.name LIMIT 20',
      [term, term],
    );
    final products = db.select(
      '''
      SELECT p.*, e.name AS establishment_name
      FROM products p JOIN establishments e ON e.id = p.establishment_id
      WHERE e.is_approved = 1 AND p.is_available = 1 AND
        (p.name LIKE ? OR p.description LIKE ?)
      ORDER BY p.name LIMIT 30
      ''',
      [term, term],
    );
    final categories = db.select(
      'SELECT * FROM categories WHERE normalize(name) LIKE ? '
      'ORDER BY sort_order',
      [term],
    );
    return jsonResponse({
      'query': q,
      'establishments': [for (final e in establishments) establishmentJson(e)],
      'products': [
        for (final p in products)
          {...productJson(p), 'establishment_name': p['establishment_name']},
      ],
      'categories': [
        for (final c in categories)
          {'id': c['id'], 'name': c['name'], 'slug': c['slug']},
      ],
    });
  }

  // ------------------------------------------------------------------ addresses

  Future<Response> _listAddresses(Request request) async {
    final user = requireUser(request);
    final rows = db.select(
      'SELECT * FROM addresses WHERE user_id = ? '
      'ORDER BY is_default DESC, created_at',
      [user.id],
    );
    return jsonResponse({
      'addresses': [for (final row in rows) addressJson(row)],
    });
  }

  Future<Response> _createAddress(Request request) async {
    final user = requireUser(request);
    final body = await readBody(request);
    final label = requiredString(body, 'label', max: 40, label: 'rótulo');
    final line =
        requiredString(body, 'line', min: 5, max: 200, label: 'morada');
    final reference = (body['reference'] as String?)?.trim();
    final city = (body['city'] as String?)?.trim() ?? 'Nacala-Porto';
    final isDefault = body['is_default'] == true;
    final (latitude, longitude) = coordinates(body);
    if (isDefault) {
      db.execute(
          'UPDATE addresses SET is_default = 0 WHERE user_id = ?', [user.id]);
    }
    final id = newId();
    db.execute(
      'INSERT INTO addresses (id, user_id, label, line, reference, city, '
      'is_default, created_at, latitude, longitude) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        user.id,
        label,
        line,
        reference,
        city,
        isDefault ? 1 : 0,
        nowIso(),
        latitude,
        longitude,
      ],
    );
    final row = db.select('SELECT * FROM addresses WHERE id = ?', [id]).first;
    return jsonResponse({'address': addressJson(row)}, status: 201);
  }

  Future<Response> _updateAddress(Request request, String id) async {
    final user = requireUser(request);
    final rows = db.select(
      'SELECT * FROM addresses WHERE id = ? AND user_id = ?',
      [id, user.id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Morada não encontrada.');
    }
    final body = await readBody(request);
    final label = (body['label'] as String?)?.trim() ?? rows.first['label'];
    final line = (body['line'] as String?)?.trim() ?? rows.first['line'];
    final reference = body.containsKey('reference')
        ? (body['reference'] as String?)?.trim()
        : rows.first['reference'];
    final (latitude, longitude) = coordinates(
      body,
      currentLatitude: (rows.first['latitude'] as num?)?.toDouble(),
      currentLongitude: (rows.first['longitude'] as num?)?.toDouble(),
    );
    final isDefault = body['is_default'] == true;
    if (isDefault) {
      db.execute(
          'UPDATE addresses SET is_default = 0 WHERE user_id = ?', [user.id]);
    }
    db.execute(
      'UPDATE addresses SET label = ?, line = ?, reference = ?, '
      'is_default = ?, latitude = ?, longitude = ? WHERE id = ?',
      [
        label,
        line,
        reference,
        isDefault ? 1 : rows.first['is_default'],
        latitude,
        longitude,
        id,
      ],
    );
    final row = db.select('SELECT * FROM addresses WHERE id = ?', [id]).first;
    return jsonResponse({'address': addressJson(row)});
  }

  Future<Response> _deleteAddress(Request request, String id) async {
    final user = requireUser(request);
    final result = db.select(
      'SELECT * FROM addresses WHERE id = ? AND user_id = ?',
      [id, user.id],
    );
    if (result.isEmpty) {
      throw ApiError(404, 'not_found', 'Morada não encontrada.');
    }
    db.execute('DELETE FROM addresses WHERE id = ?', [id]);
    return jsonResponse({'ok': true});
  }

  // -------------------------------------------------------------- favorites

  Future<Response> _listFavorites(Request request) async {
    final user = requireUser(request);
    final rows = db.select(
      '''
      $_establishmentSelect
      JOIN favorites f ON f.establishment_id = e.id
      WHERE f.user_id = ? AND e.is_approved = 1
      ORDER BY f.created_at DESC
      ''',
      [user.id],
    );
    return jsonResponse({
      'establishments': [for (final row in rows) establishmentJson(row)],
    });
  }

  Future<Response> _addFavorite(Request request, String id) async {
    final user = requireUser(request);
    final target = db.select(
      'SELECT id FROM establishments WHERE id = ? AND is_approved = 1',
      [id],
    );
    if (target.isEmpty) {
      throw ApiError(404, 'not_found', 'Estabelecimento não encontrado.');
    }
    db.execute(
      'INSERT OR IGNORE INTO favorites (user_id, establishment_id, created_at)'
      ' VALUES (?, ?, ?)',
      [user.id, id, nowIso()],
    );
    return jsonResponse({'ok': true}, status: 201);
  }

  Future<Response> _removeFavorite(Request request, String id) async {
    final user = requireUser(request);
    db.execute(
        'DELETE FROM favorites WHERE user_id = ? AND establishment_id = ?', [
      user.id,
      id,
    ]);
    return jsonResponse({'ok': true});
  }

  // -------------------------------------------------------------------- coupons

  Future<Response> _validateCoupon(Request request) async {
    requireUser(request);
    final body = await readBody(request);
    final code =
        requiredString(body, 'code', max: 40, label: 'cupão').toUpperCase();
    final subtotal = intValue(body['subtotal_cents'], min: 0);
    final rows = db.select(
      'SELECT * FROM coupons WHERE code = ? AND is_active = 1',
      [code],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'coupon_not_found', 'Cupão inválido.');
    }
    final coupon = rows.first;
    if (coupon['expires_at'] != null &&
        DateTime.parse(coupon['expires_at'] as String)
            .isBefore(DateTime.now())) {
      throw ApiError(422, 'coupon_expired', 'Este cupão já expirou.');
    }
    if (coupon['max_uses'] != null &&
        (coupon['used_count'] as int) >= (coupon['max_uses'] as int)) {
      throw ApiError(422, 'coupon_exhausted', 'Este cupão já foi utilizado.');
    }
    if (subtotal < (coupon['min_subtotal_cents'] as int)) {
      throw ApiError(
        422,
        'coupon_minimum',
        'O cupão exige um subtotal mínimo de '
            '${(coupon['min_subtotal_cents'] as int) ~/ 100} MT.',
      );
    }
    final discount = coupon['kind'] == 'percent'
        ? (subtotal * (coupon['value'] as int) ~/ 100)
        : (coupon['value'] as int);
    return jsonResponse({
      'coupon': {
        'code': coupon['code'],
        'kind': coupon['kind'],
        'value': coupon['value'],
        'discount_cents': discount > subtotal ? subtotal : discount,
      },
    });
  }

  // --------------------------------------------------------------------- orders

  Future<Response> _createOrder(Request request) async {
    final user = requireRole(request, ['customer']);
    final body = await readBody(request);
    final establishmentId = requiredString(
      body,
      'establishment_id',
      max: 60,
      label: 'estabelecimento',
    );
    final rawItems = body['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw ApiError(422, 'empty_cart', 'O carrinho está vazio.');
    }
    final addressLine = requiredString(
      body,
      'address_line',
      min: 5,
      max: 250,
      label: 'morada de entrega',
    );
    final addressLabel =
        (body['address_label'] as String?)?.trim().isNotEmpty == true
            ? (body['address_label'] as String).trim()
            : 'Entrega';
    final (addressLatitude, addressLongitude) = coordinates(
      body,
      latitudeKey: 'address_latitude',
      longitudeKey: 'address_longitude',
    );
    final phoneRaw = requiredString(
      body,
      'phone',
      min: 9,
      max: 20,
      label: 'telemóvel',
    );
    final phone = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      throw ApiError(422, 'invalid_phone', 'Número de telemóvel inválido.');
    }
    final payment = requiredString(body, 'payment_method', max: 20);
    if (!['mpesa', 'emola', 'mkesh', 'cash'].contains(payment)) {
      throw ApiError(422, 'invalid_payment', 'Método de pagamento inválido.');
    }
    final note = (body['note'] as String?)?.trim();
    final couponCode = (body['coupon_code'] as String?)?.trim().toUpperCase();

    final establishmentRows = db.select(
      'SELECT * FROM establishments WHERE id = ? AND is_approved = 1',
      [establishmentId],
    );
    if (establishmentRows.isEmpty) {
      throw ApiError(404, 'not_found', 'Estabelecimento indisponível.');
    }
    final establishment = establishmentRows.first;
    if (establishment['is_open'] != 1) {
      throw ApiError(
        409,
        'closed',
        'Este estabelecimento encontra-se encerrado.',
      );
    }

    final normalized = <String, int>{};
    for (final raw in rawItems) {
      if (raw is! Map) {
        throw ApiError(422, 'invalid_items', 'Itens inválidos.');
      }
      final productId = raw['product_id'] as String?;
      final quantity = intValue(raw['quantity'], min: 1, max: 99);
      if (productId == null) {
        throw ApiError(422, 'invalid_items', 'Produto inválido.');
      }
      normalized[productId] = (normalized[productId] ?? 0) + quantity;
      if (normalized[productId]! > 99) {
        throw ApiError(422, 'invalid_quantity', 'Quantidade excessiva.');
      }
    }

    final lines = <Map<String, dynamic>>[];
    var subtotal = 0;
    for (final entry in normalized.entries) {
      final rows = db.select(
        'SELECT * FROM products WHERE id = ? AND establishment_id = ?',
        [entry.key, establishmentId],
      );
      if (rows.isEmpty) {
        throw ApiError(
          422,
          'invalid_product',
          'Um dos produtos já não está disponível.',
        );
      }
      final product = rows.first;
      if (product['is_available'] != 1) {
        throw ApiError(
          409,
          'product_unavailable',
          '${product['name']} já não está disponível.',
        );
      }
      if (product['stock'] != null && (product['stock'] as int) < entry.value) {
        throw ApiError(
          409,
          'insufficient_stock',
          'Stock insuficiente para ${product['name']}.',
        );
      }
      final unit = product['price_cents'] as int;
      final lineTotal = unit * entry.value;
      subtotal += lineTotal;
      lines.add({
        'product': product,
        'quantity': entry.value,
        'unit': unit,
        'line_total': lineTotal,
      });
    }

    final fee = establishment['delivery_fee_cents'] as int;
    var discount = 0;
    String? appliedCoupon;
    if (couponCode != null && couponCode.isNotEmpty) {
      final coupons = db.select(
        'SELECT * FROM coupons WHERE code = ? AND is_active = 1',
        [couponCode],
      );
      if (coupons.isEmpty) {
        throw ApiError(404, 'coupon_not_found', 'Cupão inválido.');
      }
      final coupon = coupons.first;
      if (coupon['expires_at'] != null &&
          DateTime.parse(coupon['expires_at'] as String)
              .isBefore(DateTime.now())) {
        throw ApiError(422, 'coupon_expired', 'Este cupão já expirou.');
      }
      if (coupon['max_uses'] != null &&
          (coupon['used_count'] as int) >= (coupon['max_uses'] as int)) {
        throw ApiError(422, 'coupon_exhausted', 'Este cupão já foi utilizado.');
      }
      if (subtotal < (coupon['min_subtotal_cents'] as int)) {
        throw ApiError(
          422,
          'coupon_minimum',
          'O cupão exige um subtotal mínimo.',
        );
      }
      discount = coupon['kind'] == 'percent'
          ? (subtotal * (coupon['value'] as int) ~/ 100)
          : (coupon['value'] as int);
      if (discount > subtotal) discount = subtotal;
      appliedCoupon = coupon['code'] as String;
    }

    final total = subtotal + fee - discount;
    final paymentStatus =
        payment == 'cash' ? 'cash_on_delivery' : 'pending_integration';

    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute("UPDATE counters SET value = value + 1 WHERE name = 'order'");
      final seq = db
          .select("SELECT value FROM counters WHERE name = 'order'")
          .first['value'] as int;
      final number = 'NC-$seq';
      final id = newId();
      final timestamp = nowIso();
      db.execute(
        '''
        INSERT INTO orders (id, number, customer_id, establishment_id,
          address_label, address_line, address_latitude, address_longitude,
          phone, note, payment_method, payment_status, status, subtotal_cents,
          delivery_fee_cents, discount_cents, total_cents, currency,
          coupon_code, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?,
          'MZN', ?, ?, ?)
        ''',
        [
          id,
          number,
          user.id,
          establishmentId,
          addressLabel,
          addressLine,
          addressLatitude,
          addressLongitude,
          phone,
          note,
          payment,
          paymentStatus,
          subtotal,
          fee,
          discount,
          total,
          appliedCoupon,
          timestamp,
          timestamp
        ],
      );
      for (final line in lines) {
        final product = line['product'] as Row;
        final quantity = line['quantity'] as int;
        db.execute(
          '''
          INSERT INTO order_items (id, order_id, product_id, name_snapshot,
            unit_price_cents, quantity, line_total_cents)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            newId(),
            id,
            product['id'],
            product['name'],
            line['unit'],
            quantity,
            line['line_total']
          ],
        );
        if (product['stock'] != null) {
          db.execute(
            'UPDATE products SET stock = stock - ? WHERE id = ?',
            [quantity, product['id']],
          );
        }
      }
      if (appliedCoupon != null) {
        db.execute(
          'UPDATE coupons SET used_count = used_count + 1 WHERE code = ?',
          [appliedCoupon],
        );
      }
      addEvent(id, 'pending', user.id, 'Pedido recebido pela plataforma.');
      db.execute('COMMIT');
      // Avisa o dono do estabelecimento: novo pedido (som próprio no cliente).
      final ownerId = establishment['owner_user_id'] as String?;
      if (ownerId != null && ownerId != user.id) {
        _notify(
          ownerId,
          'new_order',
          'Novo pedido $number',
          'Novo pedido de ${user.name} no valor de '
          '${(total / 100).toStringAsFixed(2)} MZN. Toca para aceitar.',
          data: {'order_id': id, 'status': 'pending'},
        );
      }
      final order = loadOrder(id);
      return jsonResponse(
        {'order': orderJson(order)},
        status: 201,
      );
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Response> _listOrders(Request request) async {
    final user = requireUser(request);
    final params = request.url.queryParameters;
    final where = <String>[];
    final args = <Object?>[];
    if (user.isCustomer) {
      where.add('customer_id = ?');
      args.add(user.id);
    } else if (user.isPartner) {
      final establishment = requirePartnerEstablishment(user);
      where.add('establishment_id = ?');
      args.add(establishment['id']);
    } else if (user.isDelivery) {
      where.add(
        'id IN (SELECT order_id FROM delivery_assignments WHERE courier_id = ?)',
      );
      args.add(user.id);
    }
    final status = params['status'];
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'in_progress') {
        where.add(
          "status IN ('pending','confirmed','preparing','ready','on_the_way')",
        );
      } else if (status == 'completed') {
        where.add("status = 'delivered'");
      } else {
        where.add('status = ?');
        args.add(status);
      }
    }
    final sql = 'SELECT * FROM orders '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY created_at DESC LIMIT ? OFFSET ?';
    final (limit, offset) = _pagination(request, defaultLimit: 100);
    final rows = db.select(sql, [...args, limit + 1, offset]);
    final hasMore = rows.length > limit;
    return jsonResponse({
      'orders': ordersJson(
        [
          for (final row in hasMore ? rows.take(limit) : rows)
            Map<String, dynamic>.from(row)
        ],
        includeCustomer: !user.isCustomer,
        includeCourier: user.isCustomer || user.isAdmin,
      ),
      'has_more': hasMore,
    });
  }

  /// Lê `limit` e `offset` do query string, com teto de segurança —
  /// paginação semi-fincada nas listagens sem quebrar clientes antigos,
  /// que continuam a receber o comportamento por omissão.
  (int, int) _pagination(
    Request request, {
    required int defaultLimit,
    int maxLimit = 500,
  }) {
    final params = request.url.queryParameters;
    final limit = (int.tryParse(params['limit'] ?? '') ?? defaultLimit)
        .clamp(1, maxLimit)
        .toInt();
    final offset =
        (int.tryParse(params['offset'] ?? '') ?? 0).clamp(0, 100000).toInt();
    return (limit, offset);
  }

  Future<Response> _order(Request request, String id) async {
    final user = requireUser(request);
    final order = loadOrder(id);
    if (!canAccessOrder(user, order)) {
      throw ApiError(403, 'forbidden', 'Sem acesso a este pedido.');
    }
    return jsonResponse({
      'order': orderJson(
        order,
        includeCustomer: !user.isCustomer,
        includeCourier: true,
        includeTracking: user.isCustomer,
      ),
    });
  }

  Future<Response> _cancelOrder(Request request, String id) async {
    final user = requireUser(request);
    final order = loadOrder(id);
    if (!user.isAdmin && order['customer_id'] != user.id) {
      throw ApiError(403, 'forbidden', 'Sem acesso a este pedido.');
    }
    if (!['pending', 'confirmed'].contains(order['status'])) {
      throw ApiError(
        409,
        'invalid_transition',
        'Este pedido já não pode ser cancelado.',
      );
    }
    final body = await readBody(request);
    final reason =
        (body['reason'] as String?)?.trim() ?? 'Cancelado pelo cliente.';
    setOrderStatus(
      id,
      'cancelled',
      actorId: user.id,
      note: reason,
      cancellationReason: reason,
    );
    audit(user.id, 'order.cancelled', 'order', id, {'reason': reason});
    return jsonResponse({'order': orderJson(loadOrder(id))});
  }

  Future<Response> _reviewOrder(Request request, String id) async {
    final user = requireRole(request, ['customer']);
    final order = loadOrder(id);
    if (order['customer_id'] != user.id) {
      throw ApiError(403, 'forbidden', 'Sem acesso a este pedido.');
    }
    if (order['status'] != 'delivered') {
      throw ApiError(
        409,
        'not_delivered',
        'Só pode avaliar pedidos entregues.',
      );
    }
    final existing = db.select(
      'SELECT id FROM reviews WHERE order_id = ?',
      [id],
    );
    if (existing.isNotEmpty) {
      throw ApiError(409, 'already_reviewed', 'Este pedido já foi avaliado.');
    }
    final body = await readBody(request);
    final rating = intValue(body['rating'], min: 1, max: 5);
    final comment = (body['comment'] as String?)?.trim();
    db.execute(
      '''
      INSERT INTO reviews (id, order_id, customer_id, establishment_id,
        rating, comment, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        newId(),
        id,
        user.id,
        order['establishment_id'],
        rating,
        comment,
        nowIso()
      ],
    );
    return jsonResponse({'ok': true}, status: 201);
  }

  // -------------------------------------------------------------------- partner

  Future<Response> _partnerSummary(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final establishmentId = establishment['id'];
    final today = DateTime.now().toUtc();
    final start =
        DateTime.utc(today.year, today.month, today.day).toIso8601String();
    final stats = db.select(
      '''
      SELECT
        (SELECT COUNT(*) FROM orders WHERE establishment_id = ? AND
          created_at >= ?) AS orders_today,
        (SELECT COALESCE(SUM(total_cents),0) FROM orders
          WHERE establishment_id = ? AND created_at >= ? AND
          status = 'delivered') AS sales_today_cents,
        (SELECT COUNT(*) FROM orders WHERE establishment_id = ? AND
          status IN ('pending','confirmed')) AS pending_orders,
        (SELECT COUNT(*) FROM orders WHERE establishment_id = ? AND
          status IN ('preparing','ready','on_the_way')) AS active_orders,
        (SELECT COUNT(*) FROM orders WHERE establishment_id = ?) AS total_orders,
        (SELECT COALESCE(SUM(total_cents),0) FROM orders
          WHERE establishment_id = ? AND status = 'delivered') AS sales_total_cents
      ''',
      [
        establishmentId,
        start,
        establishmentId,
        start,
        establishmentId,
        establishmentId,
        establishmentId,
        establishmentId
      ],
    ).first;
    final rating = db.select(
      'SELECT COALESCE(ROUND(AVG(rating),1),0) AS rating, COUNT(*) AS count '
      'FROM reviews WHERE establishment_id = ?',
      [establishmentId],
    ).first;
    final recent = db.select(
      'SELECT * FROM orders WHERE establishment_id = ? '
      'ORDER BY created_at DESC LIMIT 8',
      [establishmentId],
    );
    return jsonResponse({
      'establishment': establishmentJson(
        db.select(
          '$_establishmentSelect WHERE e.id = ?',
          [establishmentId],
        ).first,
      ),
      'summary': {
        'orders_today': stats['orders_today'],
        'sales_today_cents': stats['sales_today_cents'],
        'pending_orders': stats['pending_orders'],
        'active_orders': stats['active_orders'],
        'total_orders': stats['total_orders'],
        'sales_total_cents': stats['sales_total_cents'],
        'rating': rating['rating'],
        'review_count': rating['count'],
      },
      'recent_orders': ordersJson(
        [for (final row in recent) Map<String, dynamic>.from(row)],
        includeCustomer: true,
      ),
    });
  }

  Future<Response> _partnerOrders(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final status = request.url.queryParameters['status'];
    final where = <String>['establishment_id = ?'];
    final args = <Object?>[establishment['id']];
    if (status != null && status.isNotEmpty && status != 'all') {
      if (status == 'in_progress') {
        where.add(
          "status IN ('pending','confirmed','preparing','ready','on_the_way')",
        );
      } else if (status == 'completed') {
        where.add("status IN ('delivered','cancelled','rejected')");
      } else {
        where.add('status = ?');
        args.add(status);
      }
    }
    final (limit, offset) = _pagination(request, defaultLimit: 100);
    final rows = db.select(
      'SELECT * FROM orders WHERE ${where.join(' AND ')} '
      'ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit).toList() : rows;
    return jsonResponse({
      'orders': ordersJson(
        [for (final row in pageRows) Map<String, dynamic>.from(row)],
        includeCustomer: true,
      ),
      'has_more': hasMore,
    });
  }

  Future<Response> _partnerTransition(
    Request request,
    String id,
    String action,
  ) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final order = loadOrder(id);
    if (order['establishment_id'] != establishment['id']) {
      throw ApiError(403, 'forbidden', 'Pedido de outro estabelecimento.');
    }
    final body = await readBody(request);
    switch (action) {
      case 'accept':
        if (order['status'] != 'pending') {
          throw ApiError(
            409,
            'invalid_transition',
            'Só pedidos pendentes podem ser aceites.',
          );
        }
        setOrderStatus(id, 'confirmed',
            actorId: user.id, note: 'Pedido aceite pelo parceiro.');
      case 'reject':
        if (!['pending', 'confirmed'].contains(order['status'])) {
          throw ApiError(
            409,
            'invalid_transition',
            'Este pedido já não pode ser rejeitado.',
          );
        }
        final reason = requiredString(
          body,
          'reason',
          min: 3,
          max: 200,
          label: 'motivo',
        );
        setOrderStatus(
          id,
          'rejected',
          actorId: user.id,
          note: reason,
          rejectionReason: reason,
        );
      case 'preparing':
        if (order['status'] != 'confirmed') {
          throw ApiError(
            409,
            'invalid_transition',
            'Aceite o pedido antes de iniciar a preparação.',
          );
        }
        setOrderStatus(id, 'preparing',
            actorId: user.id, note: 'O pedido está a ser preparado.');
        final existing = db.select(
          'SELECT id FROM delivery_assignments WHERE order_id = ?',
          [id],
        );
        if (existing.isEmpty) {
          db.execute(
            'INSERT INTO delivery_assignments (id, order_id, status, '
            'created_at) VALUES (?, ?, ?, ?)',
            [newId(), id, 'available', nowIso()],
          );
        }
      case 'ready':
        if (order['status'] != 'preparing') {
          throw ApiError(
            409,
            'invalid_transition',
            'O pedido não está em preparação.',
          );
        }
        setOrderStatus(id, 'ready',
            actorId: user.id, note: 'Pedido pronto para recolha.');
      default:
        throw ApiError(400, 'invalid_action', 'Ação inválida.');
    }
    audit(user.id, 'order.$action', 'order', id);
    return jsonResponse(
        {'order': orderJson(loadOrder(id), includeCustomer: true)});
  }

  Future<Response> _partnerAccept(Request request, String id) =>
      _partnerTransition(request, id, 'accept');

  Future<Response> _partnerReject(Request request, String id) =>
      _partnerTransition(request, id, 'reject');

  Future<Response> _partnerPreparing(Request request, String id) =>
      _partnerTransition(request, id, 'preparing');

  Future<Response> _partnerReady(Request request, String id) =>
      _partnerTransition(request, id, 'ready');

  Future<Response> _partnerProducts(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final rows = db.select(
      'SELECT * FROM products WHERE establishment_id = ? ORDER BY category, name',
      [establishment['id']],
    );
    return jsonResponse({
      'products': [for (final row in rows) productJson(row)],
    });
  }

  /// Valida e guarda uma imagem codificada em base64 enviada por JSON.
  /// Devolve o caminho público `/uploads/<ficheiro>`.
  Future<String> _saveImageUpload({
    required String? mimeType,
    required String? encoded,
  }) async {
    const maxImageBytes = 5 * 1024 * 1024;
    if (mimeType is! String ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType) ||
        encoded is! String ||
        encoded.isEmpty ||
        encoded.length > ((maxImageBytes + 2) ~/ 3) * 4) {
      throw ApiError(
        422,
        'invalid_image',
        'Escolha uma imagem JPEG, PNG ou WebP até 5 MB.',
      );
    }

    final Uint8List imageBytes;
    try {
      imageBytes = base64Decode(encoded);
    } on FormatException {
      throw ApiError(422, 'invalid_image', 'O ficheiro da imagem é inválido.');
    }
    if (imageBytes.isEmpty ||
        imageBytes.length > maxImageBytes ||
        !_matchesImageSignature(imageBytes, mimeType)) {
      throw ApiError(
        422,
        'invalid_image',
        'O conteúdo da imagem não corresponde ao formato indicado.',
      );
    }

    final extension = switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw StateError('Formato de imagem não suportado.'),
    };
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final filename = '$id.$extension';
    await imageDirectory.create(recursive: true);
    await File('${imageDirectory.path}/$filename').writeAsBytes(
      imageBytes,
      flush: true,
    );
    return '/uploads/$filename';
  }

  Future<Response> _partnerUploadProductImage(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    requirePartnerEstablishment(user);
    final body = await _readBodyLimited(
      request,
      maxBytes: 7 * 1024 * 1024,
    );
    final imageUrl = await _saveImageUpload(
      mimeType: body['mime_type'] as String?,
      encoded: body['data_base64'] as String?,
    );
    audit(user.id, 'product.image_uploaded', 'product_image', 'image');
    return jsonResponse({'image_url': imageUrl}, status: 201);
  }

  /// Carrega a fotografia do utilizador autenticado (qualquer papel).
  Future<Response> _uploadAvatar(Request request) async {
    final user = requireUser(request);
    final body = await _readBodyLimited(
      request,
      maxBytes: 7 * 1024 * 1024,
    );
    final imageUrl = await _saveImageUpload(
      mimeType: body['mime_type'] as String?,
      encoded: body['data_base64'] as String?,
    );
    db.execute('UPDATE users SET avatar_url = ? WHERE id = ?', [
      imageUrl,
      user.id,
    ]);
    audit(user.id, 'user.avatar_uploaded', 'user', user.id);
    return jsonResponse({
      'user': userJson(
        db.select('SELECT * FROM users WHERE id = ?', [user.id]).first,
      ),
      'image_url': imageUrl,
    }, status: 201);
  }

  bool _matchesImageSignature(Uint8List bytes, String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff;
      case 'image/png':
        return bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0d &&
            bytes[5] == 0x0a &&
            bytes[6] == 0x1a &&
            bytes[7] == 0x0a;
      case 'image/webp':
        return bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      default:
        return false;
    }
  }

  Future<Response> _productImage(Request request, String filename) async {
    if (!RegExp(r'^[a-f0-9]{32}\.(jpg|png|webp)$').hasMatch(filename)) {
      throw ApiError(404, 'not_found', 'Imagem não encontrada.');
    }
    final file = File('${imageDirectory.path}/$filename');
    if (!await file.exists()) {
      throw ApiError(404, 'not_found', 'Imagem não encontrada.');
    }
    final contentType = switch (filename.split('.').last) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': contentType,
        'content-length': '${await file.length()}',
        'cache-control': 'public, max-age=31536000, immutable',
        'x-content-type-options': 'nosniff',
      },
    );
  }

  Future<Response> _partnerCreateProduct(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final body = await readBody(request);
    final name = requiredString(body, 'name', min: 2, max: 120, label: 'nome');
    final description = (body['description'] as String?)?.trim() ?? '';
    final price = intValue(body['price_cents'], min: 1, max: 100000000);
    final category = (body['category'] as String?)?.trim() ?? 'Geral';
    final available = body['is_available'] != false;
    final stock =
        body['stock'] == null ? null : intValue(body['stock'], min: 0);
    final imageUrl = _productImageUrl(
      body['image_url'],
      requestUri: request.requestedUri,
    );
    final id = newId();
    final timestamp = nowIso();
    db.execute(
      '''
      INSERT INTO products (id, establishment_id, name, description,
        price_cents, category, image_url, stock, is_available, created_at,
        updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        establishment['id'],
        name,
        description,
        price,
        category,
        imageUrl,
        stock,
        available ? 1 : 0,
        timestamp,
        timestamp
      ],
    );
    final row = db.select('SELECT * FROM products WHERE id = ?', [id]).first;
    audit(user.id, 'product.created', 'product', id, {'name': name});
    return jsonResponse({'product': productJson(row)}, status: 201);
  }

  Future<Response> _partnerUpdateProduct(Request request, String id) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final rows = db.select(
      'SELECT * FROM products WHERE id = ? AND establishment_id = ?',
      [id, establishment['id']],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Produto não encontrado.');
    }
    final current = rows.first;
    final body = await readBody(request);
    final name = body.containsKey('name')
        ? requiredString(body, 'name', min: 2, max: 120, label: 'nome')
        : current['name'];
    final description = body.containsKey('description')
        ? (body['description'] as String?)?.trim() ?? ''
        : current['description'];
    final price = body.containsKey('price_cents')
        ? intValue(body['price_cents'], min: 1, max: 100000000)
        : current['price_cents'];
    final category = body.containsKey('category')
        ? (body['category'] as String?)?.trim() ?? 'Geral'
        : current['category'];
    final available = body.containsKey('is_available')
        ? body['is_available'] == true
        : current['is_available'] == 1;
    final stock = body.containsKey('stock')
        ? (body['stock'] == null ? null : intValue(body['stock'], min: 0))
        : current['stock'];
    final imageUrl = body.containsKey('image_url')
        ? _productImageUrl(
            body['image_url'],
            requestUri: request.requestedUri,
          )
        : current['image_url'];
    db.execute(
      'UPDATE products SET name = ?, description = ?, price_cents = ?, '
      'category = ?, image_url = ?, stock = ?, is_available = ?, '
      'updated_at = ? WHERE id = ?',
      [
        name,
        description,
        price,
        category,
        imageUrl,
        stock,
        available ? 1 : 0,
        nowIso(),
        id
      ],
    );
    final row = db.select('SELECT * FROM products WHERE id = ?', [id]).first;
    audit(user.id, 'product.updated', 'product', id, {'name': name});
    return jsonResponse({'product': productJson(row)});
  }

  String? _productImageUrl(Object? value, {required Uri requestUri}) {
    if (value == null) return null;
    if (value is! String) {
      throw ApiError(422, 'invalid_image_url', 'O link da imagem é inválido.');
    }
    final text = value.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final isHttps = uri != null &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.scheme == 'https';
    final isUploadedImage = uri != null &&
        uri.scheme == requestUri.scheme &&
        uri.authority == requestUri.authority &&
        RegExp(r'^/uploads/[a-f0-9]{32}\.(jpg|png|webp)$').hasMatch(uri.path) &&
        !uri.hasQuery &&
        !uri.hasFragment;
    // Caminho devolvido pelos uploads desta API, sem origem explícita
    // (`/uploads/…`): guardado tal e qual e resolvido no cliente.
    final isStoredPath = uri != null &&
        !uri.hasScheme &&
        uri.authority.isEmpty &&
        RegExp(r'^/uploads/[a-f0-9]{32}\.(jpg|png|webp)$').hasMatch(uri.path) &&
        !uri.hasQuery &&
        !uri.hasFragment;
    if (uri == null ||
        text.length > 2048 ||
        (!isHttps && !isUploadedImage && !isStoredPath)) {
      throw ApiError(
        422,
        'invalid_image_url',
        'Indique um link HTTPS ou uma imagem carregada nesta API.',
      );
    }
    return text;
  }

  Future<Response> _partnerDeleteProduct(Request request, String id) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final rows = db.select(
      'SELECT * FROM products WHERE id = ? AND establishment_id = ?',
      [id, establishment['id']],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Produto não encontrado.');
    }
    final used = db.select(
      'SELECT 1 FROM order_items WHERE product_id = ? LIMIT 1',
      [id],
    );
    if (used.isNotEmpty) {
      // Preserva o histórico: desativa em vez de apagar.
      db.execute(
        'UPDATE products SET is_available = 0, updated_at = ? WHERE id = ?',
        [nowIso(), id],
      );
      audit(user.id, 'product.deactivated', 'product', id);
      return jsonResponse({'ok': true, 'deactivated': true});
    }
    db.execute('DELETE FROM products WHERE id = ?', [id]);
    audit(user.id, 'product.deleted', 'product', id);
    return jsonResponse({'ok': true, 'deactivated': false});
  }

  Future<Response> _partnerEstablishment(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final row = db.select(
      '$_establishmentSelect WHERE e.id = ?',
      [establishment['id']],
    ).first;
    return jsonResponse({'establishment': establishmentJson(row)});
  }

  Future<Response> _partnerUpdateEstablishment(Request request) async {
    final user = requireApprovedRole(request, 'partner');
    final establishment = requirePartnerEstablishment(user);
    final body = await readBody(request);
    final description = body.containsKey('description')
        ? (body['description'] as String?)?.trim() ?? ''
        : establishment['description'];
    final phone = body.containsKey('phone')
        ? (body['phone'] as String?)?.trim() ?? ''
        : establishment['phone'];
    final address = body.containsKey('address')
        ? (body['address'] as String?)?.trim() ?? ''
        : establishment['address'];
    final isOpen = body.containsKey('is_open')
        ? body['is_open'] == true
        : establishment['is_open'] == 1;
    final opensAt =
        (body['opens_at'] as String?)?.trim() ?? establishment['opens_at'];
    final closesAt =
        (body['closes_at'] as String?)?.trim() ?? establishment['closes_at'];
    final imageUrl = body.containsKey('image_url')
        ? _imageUrlFromBody(body, request)
        : (establishment['image_url'] as String?);
    db.execute(
      'UPDATE establishments SET description = ?, phone = ?, address = ?, '
      'image_url = ?, is_open = ?, opens_at = ?, closes_at = ? WHERE id = ?',
      [
        description,
        phone,
        address,
        imageUrl,
        isOpen ? 1 : 0,
        opensAt,
        closesAt,
        establishment['id']
      ],
    );
    final row = db.select(
      '$_establishmentSelect WHERE e.id = ?',
      [establishment['id']],
    ).first;
    audit(user.id, 'establishment.updated', 'establishment',
        establishment['id'] as String);
    return jsonResponse({'establishment': establishmentJson(row)});
  }

  // ------------------------------------------------------------------- delivery

  Future<Response> _deliveryAssignments(Request request) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      '''
      SELECT d.*, o.number, o.status AS order_status, o.total_cents,
        o.address_line, o.address_label, o.phone AS customer_phone,
        o.address_latitude, o.address_longitude, o.note,
        o.customer_id,
        e.name AS establishment_name, e.address AS establishment_address,
        e.phone AS establishment_phone, e.owner_user_id AS establishment_owner_id
      FROM delivery_assignments d
      JOIN orders o ON o.id = d.order_id
      JOIN establishments e ON e.id = o.establishment_id
      WHERE (d.status = 'available' AND o.status = 'ready')
        OR (d.courier_id = ? AND d.status IN ('accepted'))
      ORDER BY d.created_at
      ''',
      [user.id],
    );
    return jsonResponse({
      'assignments': [
        for (final row in rows)
          {
            'id': row['id'],
            'status': row['status'],
            'order_id': row['order_id'],
            'number': row['number'],
            'order_status': row['order_status'],
            'total_cents': row['total_cents'],
            'address_label': row['address_label'],
            'address_line': row['address_line'],
            'address_latitude': row['order_status'] == 'on_the_way'
                ? row['address_latitude']
                : null,
            'address_longitude': row['order_status'] == 'on_the_way'
                ? row['address_longitude']
                : null,
            'courier_latitude': row['latitude'],
            'courier_longitude': row['longitude'],
            'location_updated_at': row['location_updated_at'],
            'departed_at': row['departed_at'],
            'customer_phone': row['customer_phone'],
            'note': row['note'],
            'establishment_name': row['establishment_name'],
            'establishment_address': row['establishment_address'],
            'establishment_phone': row['establishment_phone'],
            'customer_id': row['customer_id'],
            'establishment_owner_id': row['establishment_owner_id'],
            'created_at': row['created_at'],
          },
      ],
    });
  }

  Future<Response> _deliveryHistory(Request request) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      '''
      SELECT d.*, o.number, o.status AS order_status, o.total_cents,
        o.address_line, e.name AS establishment_name
      FROM delivery_assignments d
      JOIN orders o ON o.id = d.order_id
      JOIN establishments e ON e.id = o.establishment_id
      WHERE d.courier_id = ? AND d.status IN ('accepted','completed','declined')
      ORDER BY d.created_at DESC LIMIT 60
      ''',
      [user.id],
    );
    return jsonResponse({
      'assignments': [
        for (final row in rows)
          {
            'id': row['id'],
            'status': row['status'],
            'order_id': row['order_id'],
            'number': row['number'],
            'order_status': row['order_status'],
            'total_cents': row['total_cents'],
            'address_line': row['address_line'],
            'establishment_name': row['establishment_name'],
            'accepted_at': row['accepted_at'],
            'completed_at': row['completed_at'],
          },
      ],
    });
  }

  Future<Response> _deliveryAccept(Request request, String id) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      'SELECT d.*, o.id AS order_id, o.status AS order_status FROM '
      'delivery_assignments d JOIN orders o ON o.id = d.order_id WHERE d.id = ?',
      [id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Entrega não encontrada.');
    }
    final assignment = rows.first;
    if (assignment['status'] != 'available') {
      throw ApiError(409, 'already_taken', 'Esta entrega já foi atribuída.');
    }
    if (assignment['order_status'] != 'ready') {
      throw ApiError(
        409,
        'invalid_transition',
        'O pedido ainda não está pronto para recolha.',
      );
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        'UPDATE delivery_assignments SET courier_id = ?, status = ?, '
        'accepted_at = ? WHERE id = ? AND status = ?',
        [user.id, 'accepted', nowIso(), id, 'available'],
      );
      if (db.updatedRows == 0) {
        throw ApiError(409, 'already_taken', 'Esta entrega já foi atribuída.');
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    audit(user.id, 'delivery.accepted', 'delivery', id);
    return jsonResponse({
      'assignment': {'id': id, 'status': 'accepted'},
      'order': orderJson(
        loadOrder(assignment['order_id'] as String),
        includeCustomer: true,
        includeCourier: true,
      ),
    });
  }

  Future<Response> _deliveryStart(Request request, String id) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      'SELECT d.*, o.status AS order_status, o.address_latitude, '
      'o.address_longitude FROM delivery_assignments d '
      'JOIN orders o ON o.id = d.order_id '
      'WHERE d.id = ? AND d.courier_id = ?',
      [id, user.id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Entrega não encontrada.');
    }
    final assignment = rows.first;
    if (assignment['status'] != 'accepted' ||
        assignment['order_status'] != 'ready') {
      throw ApiError(
        409,
        'invalid_transition',
        'A entrega ainda não pode ser iniciada.',
      );
    }
    if (assignment['address_latitude'] == null ||
        assignment['address_longitude'] == null) {
      throw ApiError(
        409,
        'missing_destination',
        'O cliente ainda não indicou o ponto de entrega no mapa.',
      );
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        'UPDATE delivery_assignments SET departed_at = ? '
        'WHERE id = ? AND status = ? AND departed_at IS NULL',
        [nowIso(), id, 'accepted'],
      );
      if (db.updatedRows == 0) {
        throw ApiError(
          409,
          'invalid_transition',
          'A entrega já foi iniciada.',
        );
      }
      setOrderStatus(
        assignment['order_id'] as String,
        'on_the_way',
        actorId: user.id,
        note: 'O estafeta saiu para entregar o pedido.',
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    audit(user.id, 'delivery.started', 'delivery', id);
    return jsonResponse({
      'order': orderJson(
        loadOrder(assignment['order_id'] as String),
        includeCustomer: true,
        includeCourier: true,
        includeTracking: true,
      ),
    });
  }

  Future<Response> _deliveryLocation(Request request, String id) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      'SELECT d.id, d.status AS assignment_status, '
      'o.status AS order_status FROM delivery_assignments d '
      'JOIN orders o ON o.id = d.order_id '
      'WHERE d.id = ? AND d.courier_id = ?',
      [id, user.id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Entrega não encontrada.');
    }
    if (rows.first['assignment_status'] != 'accepted' ||
        rows.first['order_status'] != 'on_the_way') {
      throw ApiError(
        409,
        'invalid_transition',
        'A localização só pode ser partilhada durante uma entrega em curso.',
      );
    }
    final body = await readBody(request);
    final (latitude, longitude) = coordinates(body);
    if (latitude == null || longitude == null) {
      throw ApiError(
        422,
        'invalid_coordinates',
        'Indique a localização atual do estafeta.',
      );
    }
    final updatedAt = nowIso();
    db.execute(
      'UPDATE delivery_assignments SET latitude = ?, longitude = ?, '
      'location_updated_at = ? WHERE id = ?',
      [latitude, longitude, updatedAt, id],
    );
    return jsonResponse({'ok': true, 'location_updated_at': updatedAt});
  }

  Future<Response> _deliveryDecline(Request request, String id) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      'SELECT * FROM delivery_assignments WHERE id = ? AND courier_id = ?',
      [id, user.id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Entrega não encontrada.');
    }
    db.execute(
      'UPDATE delivery_assignments SET courier_id = NULL, status = ?, '
      'accepted_at = NULL, departed_at = NULL, latitude = NULL, '
      'longitude = NULL, location_updated_at = NULL WHERE id = ?',
      ['available', id],
    );
    db.execute(
      "UPDATE orders SET status = 'ready', updated_at = ? WHERE id = ? AND "
      "status = 'on_the_way'",
      [nowIso(), rows.first['order_id']],
    );
    audit(user.id, 'delivery.declined', 'delivery', id);
    return jsonResponse({'ok': true});
  }

  Future<Response> _deliveryComplete(Request request, String id) async {
    final user = requireApprovedRole(request, 'delivery');
    final rows = db.select(
      'SELECT d.*, o.status AS order_status FROM delivery_assignments d '
      'JOIN orders o ON o.id = d.order_id WHERE d.id = ? AND d.courier_id = ?',
      [id, user.id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Entrega não encontrada.');
    }
    if (rows.first['order_status'] != 'on_the_way') {
      throw ApiError(
        409,
        'invalid_transition',
        'O pedido não está em entrega.',
      );
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        "UPDATE delivery_assignments SET status = 'completed', completed_at = ?, "
        'latitude = NULL, longitude = NULL, location_updated_at = NULL '
        'WHERE id = ?',
        [nowIso(), id],
      );
      final orderId = rows.first['order_id'] as String;
      setOrderStatus(
        orderId,
        'delivered',
        actorId: user.id,
        note: 'Pedido entregue ao cliente.',
      );
      db.execute(
        'UPDATE orders SET address_latitude = NULL, address_longitude = NULL '
        'WHERE id = ?',
        [orderId],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    audit(user.id, 'delivery.completed', 'delivery', id);
    return jsonResponse({'ok': true});
  }

  // ---------------------------------------------------------------------- admin

  Future<Response> _adminSummary(Request request) async {
    requireRole(request, ['admin']);
    final stats = db.select(
      '''
      SELECT
        (SELECT COUNT(*) FROM users WHERE role = 'customer') AS customers,
        (SELECT COUNT(*) FROM users WHERE role = 'partner') AS partners,
        (SELECT COUNT(*) FROM users WHERE role = 'delivery') AS couriers,
        (SELECT COUNT(*) FROM establishments WHERE is_approved = 1)
          AS active_partners,
        (SELECT COUNT(*) FROM establishments WHERE is_approved = 0)
          AS pending_partners,
        (SELECT COUNT(*) FROM orders) AS total_orders,
        (SELECT COUNT(*) FROM orders WHERE status IN
          ('pending','confirmed','preparing','ready','on_the_way'))
          AS orders_in_progress,
        (SELECT COALESCE(SUM(total_cents),0) FROM orders WHERE
          status = 'delivered') AS sales_total_cents,
        (SELECT COALESCE(SUM(total_cents),0) FROM orders WHERE
          status = 'delivered' AND created_at >= ?) AS sales_today_cents,
        (SELECT COUNT(*) FROM orders WHERE created_at >= ?) AS orders_today
      ''',
      [
        DateTime.utc(
          DateTime.now().toUtc().year,
          DateTime.now().toUtc().month,
          DateTime.now().toUtc().day,
        ).toIso8601String(),
        DateTime.utc(
          DateTime.now().toUtc().year,
          DateTime.now().toUtc().month,
          DateTime.now().toUtc().day,
        ).toIso8601String(),
      ],
    ).first;
    final recent = db.select(
      'SELECT * FROM orders ORDER BY created_at DESC LIMIT 10',
    );
    final pending = db.select(
      '''
      SELECT e.*, c.name AS category_name, c.slug AS category_slug,
        0.0 AS rating, 0 AS review_count, 0 AS product_count
      FROM establishments e JOIN categories c ON c.id = e.category_id
      WHERE e.is_approved = 0 ORDER BY e.created_at
      ''',
    );
    return jsonResponse({
      'summary': {
        'customers': stats['customers'],
        'partners': stats['partners'],
        'couriers': stats['couriers'],
        'active_partners': stats['active_partners'],
        'pending_partners': stats['pending_partners'],
        'total_orders': stats['total_orders'],
        'orders_in_progress': stats['orders_in_progress'],
        'sales_total_cents': stats['sales_total_cents'],
        'sales_today_cents': stats['sales_today_cents'],
        'orders_today': stats['orders_today'],
      },
      'recent_orders': ordersJson(
        [for (final row in recent) Map<String, dynamic>.from(row)],
        includeCustomer: true,
      ),
      'pending_partners': [
        for (final row in pending) establishmentJson(row),
      ],
    });
  }

  Future<Response> _adminPartners(Request request) async {
    requirePermission(request, 'establishments');
    final rows = db.select(
      '$_establishmentSelect ORDER BY e.is_approved, e.name',
    );
    return jsonResponse({
      'partners': [for (final row in rows) establishmentJson(row)],
    });
  }

  /// Fotografia do estabelecimento carregada pela administração (ficheiro,
  /// em vez de um link externo que o parceiro não controla).
  Future<Response> _adminUploadPartnerImage(Request request) async {
    final actor = requirePermission(request, 'establishments');
    final body = await _readBodyLimited(
      request,
      maxBytes: 7 * 1024 * 1024,
    );
    final imageUrl = await _saveImageUpload(
      mimeType: body['mime_type'] as String?,
      encoded: body['data_base64'] as String?,
    );
    audit(actor.id, 'partner.image_uploaded', 'establishment', 'image');
    return jsonResponse({'image_url': imageUrl}, status: 201);
  }

  /// Registo de um parceiro real pela administração: cria a conta de acesso
  /// (papel `partner`) e o estabelecimento aprovado numa única transação.
  Future<Response> _adminCreatePartner(Request request) async {
    final actor = requirePermission(request, 'establishments');
    final body = await readBody(request);

    final name = requiredString(body, 'name', min: 2, max: 80, label: 'nome');
    final email = requiredString(
      body,
      'email',
      min: 5,
      max: 120,
      label: 'email',
    ).toLowerCase();
    final phone = requiredString(
      body,
      'phone',
      min: 9,
      max: 20,
      label: 'telemóvel',
    ).replaceAll(RegExp(r'[^0-9]'), '');
    final password = requiredString(
      body,
      'password',
      min: 8,
      max: 200,
      label: 'palavra-passe',
    );
    final establishmentName = requiredString(
      body,
      'establishment_name',
      min: 2,
      max: 80,
      label: 'nome do estabelecimento',
    );
    final categoryId = requiredString(
      body,
      'category_id',
      min: 1,
      max: 60,
      label: 'categoria',
    );

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ApiError(422, 'invalid_email', 'Indique um email válido.');
    }
    final nuit = requiredString(
      body,
      'nuit',
      min: 9,
      max: 20,
      label: 'NUIT',
    ).replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^[0-9]{9}$').hasMatch(nuit)) {
      throw ApiError(
        422,
        'invalid_nuit',
        'Indique um NUIT válido (9 dígitos).',
      );
    }
    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      throw ApiError(
        422,
        'invalid_phone',
        'Indique um número moçambicano válido (ex.: 84 123 4567).',
      );
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw ApiError(
        422,
        'weak_password',
        'A palavra-passe deve ter letras e números (mínimo 8 caracteres).',
      );
    }

    final duplicate = db.select(
      'SELECT id FROM users WHERE email = ? OR phone = ?',
      [email, phone],
    );
    if (duplicate.isNotEmpty) {
      throw ApiError(
        409,
        'already_registered',
        'Já existe uma conta com este email ou telemóvel.',
      );
    }

    final category = db.select(
      'SELECT id FROM categories WHERE id = ?',
      [categoryId],
    );
    if (category.isEmpty) {
      throw ApiError(422, 'invalid_category', 'Categoria inexistente.');
    }

    final fee = intValue(
      body['delivery_fee_cents'],
      min: 0,
      max: 1000000,
      fallback: 0,
    );
    final prep = intValue(
      body['prep_minutes'],
      min: 5,
      max: 240,
      fallback: 30,
    );
    final opensAt = (body['opens_at'] as String?)?.trim() ?? '08:00';
    final closesAt = (body['closes_at'] as String?)?.trim() ?? '21:00';
    final timePattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
    if (!timePattern.hasMatch(opensAt) || !timePattern.hasMatch(closesAt)) {
      throw ApiError(422, 'invalid_hours', 'Horário inválido (use HH:MM).');
    }
    final description = (body['description'] as String?)?.trim() ?? '';
    final address = (body['address'] as String?)?.trim() ?? '';
    final establishmentPhone =
        (body['establishment_phone'] as String?)?.trim().isNotEmpty == true
            ? (body['establishment_phone'] as String).trim()
            : phone;
    final imageUrl = _imageUrlFromBody(body, request);

    var slug = normalizeText(establishmentName)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'parceiro';
    var candidate = slug;
    var suffix = 2;
    while (db.select('SELECT id FROM establishments WHERE slug = ?',
        [candidate]).isNotEmpty) {
      candidate = '$slug-$suffix';
      suffix++;
    }

    final digest = hashPassword(password);
    final userId = newId();
    final establishmentId = newId();
    final now = nowIso();

    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        '''
        INSERT INTO users (id, role, name, email, phone, password_hash,
          password_salt, token_version, is_active, created_at)
        VALUES (?, 'partner', ?, ?, ?, ?, ?, 0, 1, ?)
        ''',
        [userId, name, email, phone, digest.hash, digest.salt, now],
      );
      db.execute(
        '''
        INSERT INTO establishments (id, owner_user_id, category_id, name, slug,
          description, phone, address, image_url, delivery_fee_cents, prep_minutes,
          opens_at, closes_at, is_open, is_approved, nuit, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, ?, ?)
        ''',
        [
          establishmentId,
          userId,
          categoryId,
          establishmentName,
          candidate,
          description,
          establishmentPhone,
          address,
          imageUrl,
          fee,
          prep,
          opensAt,
          closesAt,
          nuit,
          now,
        ],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'partner.created', 'establishment', establishmentId, {
      'name': establishmentName,
      'owner': email,
    });

    final userRow =
        db.select('SELECT * FROM users WHERE id = ?', [userId]).first;
    final establishmentRow = db.select(
      '$_establishmentSelect WHERE e.id = ?',
      [establishmentId],
    ).first;
    return jsonResponse({
      'user': userJson(userRow),
      'establishment': establishmentJson(establishmentRow),
    }, status: 201);
  }

  Future<Response> _adminApprovePartner(Request request, String id) async {
    final user = requirePermission(request, 'establishments');
    final rows = db.select('SELECT * FROM establishments WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Parceiro não encontrado.');
    }
    db.execute(
      'UPDATE establishments SET is_approved = 1, is_open = 1 WHERE id = ?',
      [id],
    );
    audit(user.id, 'partner.approved', 'establishment', id);
    final row = db.select(
      '$_establishmentSelect WHERE e.id = ?',
      [id],
    ).first;
    return jsonResponse({'establishment': establishmentJson(row)});
  }

  Future<Response> _adminRejectPartner(Request request, String id) async {
    final user = requirePermission(request, 'establishments');
    final rows = db.select('SELECT * FROM establishments WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Parceiro não encontrado.');
    }
    db.execute(
      'UPDATE establishments SET is_approved = 0, is_open = 0 WHERE id = ?',
      [id],
    );
    audit(user.id, 'partner.rejected', 'establishment', id);
    return jsonResponse({'ok': true});
  }

  Future<Response> _adminUsers(Request request) async {
    requirePermission(request, 'customers');
    final role = request.url.queryParameters['role'];
    final (limit, offset) = _pagination(request, defaultLimit: 200);
    final rows = role == null || role.isEmpty
        ? db.select(
            'SELECT * FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?',
            [limit + 1, offset],
          )
        : db.select(
            'SELECT * FROM users WHERE role = ? '
            'ORDER BY created_at DESC LIMIT ? OFFSET ?',
            [role, limit + 1, offset],
          );
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit).toList() : rows;
    return jsonResponse({
      'users': [for (final row in pageRows) userJson(row)],
      'has_more': hasMore,
    });
  }

  Future<Response> _adminUpdateUser(Request request, String id) async {
    final actor = requirePermission(request, 'customers');
    final rows = db.select('SELECT * FROM users WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Utilizador não encontrado.');
    }
    // Funcionários só gerem contas de clientes/parceiros/estafetas.
    if (actor.role != 'admin' &&
        (rows.first['role'] == 'admin' ||
            rows.first['role'] == 'employee')) {
      throw ApiError(
        403,
        'forbidden',
        'Contas administrativas só são alteradas por administradores.',
      );
    }
    final body = await readBody(request);
    if (body.containsKey('role')) {
      if (actor.role != 'admin') {
        throw ApiError(
          403,
          'forbidden',
          'Só administradores alteram o papel das contas.',
        );
      }
      if (id == actor.id) {
        throw ApiError(
          422,
          'self_role_change',
          'Não pode alterar o seu próprio papel.',
        );
      }
      final role = requiredString(body, 'role', max: 20);
      if (!['customer', 'partner', 'delivery', 'admin'].contains(role)) {
        throw ApiError(422, 'invalid_role', 'Papel inválido.');
      }
      db.execute(
        'UPDATE users SET role = ?, token_version = token_version + 1 '
        'WHERE id = ?',
        [role, id],
      );
      audit(actor.id, 'user.role_changed', 'user', id, {'role': role});
    }
    if (body.containsKey('is_active')) {
      if (id == actor.id && body['is_active'] == false) {
        throw ApiError(
          422,
          'self_deactivate',
          'Não pode desativar a sua própria conta.',
        );
      }
      db.execute(
        'UPDATE users SET is_active = ?, token_version = token_version + 1 '
        'WHERE id = ?',
        [body['is_active'] == true ? 1 : 0, id],
      );
      audit(actor.id, 'user.activation_changed', 'user', id, {
        'is_active': body['is_active'] == true,
      });
    }
    final row = db.select('SELECT * FROM users WHERE id = ?', [id]).first;
    return jsonResponse({'user': userJson(row)});
  }

  Future<Response> _adminOrders(Request request) async {
    requirePermission(request, 'orders');
    final status = request.url.queryParameters['status'];
    final (limit, offset) = _pagination(request, defaultLimit: 200);
    final rows = status == null || status.isEmpty || status == 'all'
        ? db.select(
            'SELECT * FROM orders ORDER BY created_at DESC LIMIT ? OFFSET ?',
            [limit + 1, offset],
          )
        : db.select(
            'SELECT * FROM orders WHERE status = ? '
            'ORDER BY created_at DESC LIMIT ? OFFSET ?',
            [status, limit + 1, offset],
          );
    final hasMore = rows.length > limit;
    final pageRows = hasMore ? rows.take(limit).toList() : rows;
    return jsonResponse({
      'orders': ordersJson(
        [for (final row in pageRows) Map<String, dynamic>.from(row)],
        includeCustomer: true,
      ),
      'has_more': hasMore,
    });
  }

  Future<Response> _adminAudit(Request request) async {
    requireRole(request, ['admin']);
    final rows = db.select(
      '''
      SELECT a.*, u.name AS actor_name FROM audit_logs a
      LEFT JOIN users u ON u.id = a.actor_id
      ORDER BY a.created_at DESC LIMIT 100
      ''',
    );
    return jsonResponse({
      'logs': [
        for (final row in rows)
          {
            'id': row['id'],
            'actor': row['actor_name'],
            'action': row['action'],
            'entity': row['entity'],
            'entity_id': row['entity_id'],
            'metadata': row['metadata'],
            'created_at': row['created_at'],
          },
      ],
    });
  }

  Future<Response> _adminCreateCategory(Request request) async {
    final user = requirePermission(request, 'products');
    final body = await readBody(request);
    final name = requiredString(body, 'name', min: 2, max: 60, label: 'nome');
    final slug = (body['slug'] as String?)?.trim().isNotEmpty == true
        ? (body['slug'] as String).trim().toLowerCase()
        : name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final icon = (body['icon'] as String?)?.trim() ?? 'store';
    final existing = db.select(
      'SELECT id FROM categories WHERE slug = ?',
      [slug],
    );
    if (existing.isNotEmpty) {
      throw ApiError(
          409, 'slug_taken', 'Já existe uma categoria com este nome.');
    }
    final id = newId();
    final imageUrl = _imageUrlFromBody(body, request);
    db.execute(
      'INSERT INTO categories (id, name, slug, icon, sort_order, image_url) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [id, name, slug, icon, 99, imageUrl],
    );
    audit(user.id, 'category.created', 'category', id, {'name': name});
    return jsonResponse(
      {
        'category': {
          'id': id,
          'name': name,
          'slug': slug,
          'icon': icon,
          'image_url': imageUrl,
        }
      },
      status: 201,
    );
  }

  String? _imageUrlFromBody(
    Map<String, dynamic> body,
    Request request, {
    String? field = 'image_url',
  }) {
    final value = body[field];
    if (value == null) return null;
    if (value is! String) {
      throw ApiError(422, 'invalid_image_url', 'O link da imagem é inválido.');
    }
    final text = value.trim();
    if (text.isEmpty) return null;
    return _productImageUrl(text, requestUri: request.requestedUri);
  }

  Future<Response> _adminUpdateCategory(Request request, String id) async {
    final user = requirePermission(request, 'products');
    final rows = db.select('SELECT * FROM categories WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Categoria não encontrada.');
    }
    final body = await readBody(request);
    final name = body.containsKey('name')
        ? requiredString(body, 'name', min: 2, max: 60, label: 'nome')
        : rows.first['name'];
    final icon = body.containsKey('icon')
        ? (body['icon'] as String?)?.trim() ?? 'store'
        : rows.first['icon'];
    final imageUrl = body.containsKey('image_url')
        ? _imageUrlFromBody(body, request)
        : (rows.first['image_url'] as String?);
    db.execute(
      'UPDATE categories SET name = ?, icon = ?, image_url = ? WHERE id = ?',
      [name, icon, imageUrl, id],
    );
    audit(user.id, 'category.updated', 'category', id);
    return jsonResponse({'ok': true});
  }

  Future<Response> _adminDeleteCategory(Request request, String id) async {
    final user = requirePermission(request, 'products');
    final used = db.select(
      'SELECT 1 FROM establishments WHERE category_id = ? LIMIT 1',
      [id],
    );
    if (used.isNotEmpty) {
      throw ApiError(
        409,
        'category_in_use',
        'Esta categoria está associada a estabelecimentos.',
      );
    }
    db.execute('DELETE FROM categories WHERE id = ?', [id]);
    audit(user.id, 'category.deleted', 'category', id);
    return jsonResponse({'ok': true});
  }

  /// Elimina um estabelecimento, os seus produtos, favoritos, avaliações
  /// e as encomendas feitas a essa loja. Pensado para limpar dados de
  /// demonstração semeados no servidor; não toca em nenhum utilizador.
  Future<Response> _adminDeleteEstablishment(Request request, String id) async {
    final user = requirePermission(request, 'establishments');
    final rows = db.select(
      'SELECT id, name FROM establishments WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Estabelecimento não encontrado.');
    }
    final name = rows.first['name'] as String;
    final deletedOrders = db.select(
      'SELECT COUNT(*) AS n FROM orders WHERE establishment_id = ?',
      [id],
    ).first['n'] as int;

    db.execute('BEGIN');
    try {
      // Encomendas primeiro: a FK orders→establishments não apaga em
      // cascata; os itens, eventos, atribuições e avaliações ligados à
      // encomenda são removidos automaticamente.
      db.execute('DELETE FROM orders WHERE establishment_id = ?', [id]);
      // Produtos, favoritos e avaliações caem em cascata com a loja.
      db.execute('DELETE FROM establishments WHERE id = ?', [id]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    audit(user.id, 'establishment.deleted', 'establishment', id, {
      'name': name,
      'removed_orders': deletedOrders,
    });
    return jsonResponse({'ok': true, 'removed_orders': deletedOrders});
  }

  /// Elimina uma conta (por exemplo, contas de demonstração semeadas).
  /// Contas de administração ficam protegidas; clientes com encomendas
  /// no histórico exigem que a loja correspondente seja eliminada antes.
  Future<Response> _adminDeleteUser(Request request, String id) async {
    final user = requirePermission(request, 'customers');
    if (id == user.id) {
      throw ApiError(409, 'self_delete', 'Não podes eliminar a tua conta.');
    }
    final rows = db.select(
      'SELECT id, role, name FROM users WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Utilizador não encontrado.');
    }
    if (rows.first['role'] == 'admin') {
      throw ApiError(
        403,
        'admin_protected',
        'As contas de administração não podem ser eliminadas.',
      );
    }
    if (rows.first['role'] == 'employee' && user.role != 'admin') {
      throw ApiError(
        403,
        'forbidden',
        'Contas de funcionários só são eliminadas por administradores.',
      );
    }
    final hasOrders = db.select(
      'SELECT 1 FROM orders WHERE customer_id = ? LIMIT 1',
      [id],
    );
    if (hasOrders.isNotEmpty) {
      throw ApiError(
        409,
        'user_has_orders',
        'Esta conta tem encomendas no histórico. Elimina primeiro o '
            'estabelecimento dessas encomendas.',
      );
    }
    db.execute('DELETE FROM users WHERE id = ?', [id]);
    audit(user.id, 'user.deleted', 'user', id, {
      'name': rows.first['name'],
      'role': rows.first['role'],
    });
    return jsonResponse({'ok': true});
  }

  // ------------------------------------- candidaturas (FASE 5/6/7)

  /// Permissões que um administrador pode atribuir a um funcionário. A
  /// FASE 10 mapeia cada chave para acções concretas do painel; aqui já se
  /// valida o conjunto para nada chegar malformado à base de dados.
  static const _employeePermissions = <String>{
    'orders',
    'products',
    'establishments',
    'customers',
    'applications',
    'notifications',
  };

  /// Níveis de funcionário (o `super_admin` é reservado à configuração
  /// directa da plataforma e não é criável pela API).
  static const _employeeLevels = <String>{'admin', 'staff'};

  /// Corpo opcional: rotas administrativas POST/PATCH podem vir sem corpo.
  Future<Map<String, dynamic>> _optionalBody(Request request) async {
    try {
      return await readBody(request);
    } on ApiError catch (error) {
      if (error.code == 'invalid_body') return const {};
      rethrow;
    }
  }

  /// Insere uma notificação persistente para [userId].
  void _notify(
    String userId,
    String kind,
    String title,
    String body, {
    Map<String, dynamic> data = const {},
  }) {
    db.execute(
      '''
      INSERT INTO notifications (id, user_id, kind, title, body, data,
        is_read, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 0, ?)
      ''',
      [newId(), userId, kind, title, body, jsonEncode(data), nowIso()],
    );
  }

  /// Avisa todos os administradores activos (ex.: nova candidatura).
  void _notifyAdmins(
    String kind,
    String title,
    String body,
    Map<String, dynamic> data,
  ) {
    final admins = db.select(
      "SELECT id FROM users WHERE role = 'admin' AND is_active = 1",
    );
    for (final admin in admins) {
      _notify(admin['id'] as String, kind, title, body, data: data);
    }
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FormatException {
      // Corrompido: devolver vazio em vez de rebentar listagens.
    }
    return const {};
  }

  List<String> _decodeList(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return [for (final item in decoded) '$item'];
    } on FormatException {
      // Idem.
    }
    return const [];
  }

  Map<String, dynamic> applicationJson(Row row) => {
        'id': row['id'],
        'kind': row['kind'],
        'status': row['status'],
        'name': row['name'],
        'email': row['email'],
        'phone': row['phone'],
        'whatsapp': row['whatsapp'],
        'payload': _decodeMap(row['payload']),
        'admin_note': row['admin_note'],
        'reviewed_at': row['reviewed_at'],
        'user_id': row['user_id'],
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      };

  Map<String, dynamic> employeeJson(Row row) => {
        'id': row['id'],
        'user_id': row['user_id'],
        'establishment_id': row['establishment_id'],
        'name': row['name'],
        'email': row['email'],
        'phone': row['phone'],
        'level': row['level'],
        'permissions': _decodeList(row['permissions']),
        'is_active': row['is_active'] == 1 && row['user_active'] == 1,
        'created_at': row['created_at'],
      };

  Map<String, dynamic> notificationJson(Row row, {bool withUser = false}) => {
        'id': row['id'],
        'kind': row['kind'],
        'title': row['title'],
        'body': row['body'],
        'data': _decodeMap(row['data']),
        'is_read': row['is_read'] == 1,
        'created_at': row['created_at'],
        if (withUser) ...{
          'user_id': row['user_id'],
          'user_name': row['user_name'],
          'user_email': row['user_email'],
        },
      };

  String? _optionalString(dynamic value, {required int max}) {
    if (value == null) return null;
    if (value is! String) {
      throw ApiError(422, 'invalid_payload', 'Dados da candidatura inválidos.');
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > max) {
      throw ApiError(
        422,
        'invalid_payload',
        'Campo da candidatura demasiado longo.',
      );
    }
    return trimmed;
  }

  String? _optionalHours(dynamic value) {
    final text = _optionalString(value, max: 5);
    if (text == null) return null;
    if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(text)) {
      throw ApiError(422, 'invalid_hours', 'Horário inválido (use HH:MM).');
    }
    return text;
  }

  /// Valida e normaliza o `payload` da candidatura por tipo.
  ///
  /// Estabelecimento: nome, categoria (validada contra a tabela), morada,
  /// coordenadas, horário e taxas — tudo o que a aprovação vai necessitar
  /// para criar a linha em `establishments`. Entregador: dados livres
  /// normalizados (a aprovação só activa a conta).
  Map<String, dynamic> _applicationPayload(
    Map<String, dynamic> body,
    String kind,
  ) {
    final raw = body['payload'];
    final Map<String, dynamic> payload;
    if (raw == null) {
      payload = const {};
    } else if (raw is Map<String, dynamic>) {
      payload = raw;
    } else if (raw is Map) {
      payload = raw.cast<String, dynamic>();
    } else {
      throw ApiError(422, 'invalid_payload', 'Dados da candidatura inválidos.');
    }
    final normalized = Map<String, dynamic>.from(payload);

    if (kind == 'establishment') {
      final name = _optionalString(payload['establishment_name'], max: 80);
      if (name == null || name.length < 2) {
        throw ApiError(
          422,
          'invalid_establishment_name',
          'Indique o nome do estabelecimento.',
        );
      }
      final categoryId = _optionalString(payload['category_id'], max: 60);
      if (categoryId == null ||
          db.select('SELECT id FROM categories WHERE id = ?', [categoryId])
              .isEmpty) {
        throw ApiError(422, 'invalid_category', 'Categoria inexistente.');
      }
      final phone = _optionalString(payload['phone'], max: 20);
      if (phone != null &&
          !RegExp(r'^8[2-7][0-9]{7}$')
              .hasMatch(phone.replaceAll(RegExp(r'[^0-9]'), ''))) {
        throw ApiError(
          422,
          'invalid_phone',
          'Indique um número de contacto moçambicano válido.',
        );
      }
      final whatsapp = _optionalString(payload['whatsapp'], max: 20);
      if (whatsapp != null &&
          !RegExp(r'^8[2-7][0-9]{7}$')
              .hasMatch(whatsapp.replaceAll(RegExp(r'[^0-9]'), ''))) {
        throw ApiError(
          422,
          'invalid_whatsapp',
          'Indique um número de WhatsApp moçambicano válido.',
        );
      }
      final (latitude, longitude) = coordinates(payload);
      normalized['establishment_name'] = name;
      normalized['category_id'] = categoryId;
      normalized['description'] =
          _optionalString(payload['description'], max: 500) ?? '';
      normalized['address'] = _optionalString(payload['address'], max: 200) ??
          '';
      normalized['phone'] = phone;
      normalized['whatsapp'] = whatsapp;
      normalized['latitude'] = latitude;
      normalized['longitude'] = longitude;
      normalized['delivery_fee_cents'] = intValue(
        payload['delivery_fee_cents'],
        min: 0,
        max: 1000000,
        fallback: 0,
      );
      normalized['prep_minutes'] = intValue(
        payload['prep_minutes'],
        min: 5,
        max: 240,
        fallback: 30,
      );
      normalized['opens_at'] = _optionalHours(payload['opens_at']) ?? '08:00';
      normalized['closes_at'] = _optionalHours(payload['closes_at']) ?? '21:00';
      normalized['image_url'] = _optionalString(payload['image_url'], max: 300);
      normalized['nuit'] = _requiredNuit(payload['nuit']);
      return normalized;
    }

    normalized['nuit'] = _requiredNuit(payload['nuit']);
    normalized['documents'] = _courierDocuments(payload['documents']);
    normalized['vehicle_type'] = _optionalString(payload['vehicle_type'], max: 40);
    normalized['address'] = _optionalString(payload['address'], max: 200) ?? '';
    normalized['notes'] = _optionalString(payload['notes'], max: 500) ?? '';
    final (latitude, longitude) = coordinates(payload);
    normalized['latitude'] = latitude;
    normalized['longitude'] = longitude;
    return normalized;
  }

  /// NUIT (Número Único de Identificação Tributária) obrigatório para
  /// contribuintes: estabelecimentos e entregadores. Aceita separadores
  /// visuais, mas guarda só os 9 dígitos.
  String _requiredNuit(Object? value) {
    final digits = '${value ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^[0-9]{9}$').hasMatch(digits)) {
      throw ApiError(
        422,
        'invalid_nuit',
        'Indique um NUIT válido (9 dígitos).',
      );
    }
    return digits;
  }

  /// Documentos obrigatórios do candidato a entregador: selfie, B.I (frente e
  /// verso) e carta de condução, já carregados em `/api/applications/images`.
  Map<String, String> _courierDocuments(Object? value) {
    if (value is! Map) {
      throw ApiError(
        422,
        'missing_documents',
        'Carregue os documentos obrigatórios: selfie, B.I (frente e verso) e '
            'carta de condução.',
      );
    }
    const labels = {
      'selfie': 'a selfie',
      'bi_front': 'a frente do B.I',
      'bi_back': 'o verso do B.I',
      'license': 'a carta de condução',
    };
    final documents = <String, String>{};
    for (final entry in labels.entries) {
      final raw = value[entry.key];
      final path = raw is String ? raw.trim() : '';
      if (!_isStoredImage(path)) {
        throw ApiError(
          422,
          'missing_document',
          'Falta a fotografia de ${entry.value}.',
        );
      }
      documents[entry.key] = path;
    }
    return documents;
  }

  /// Caminho `/uploads/…` com formato válido e ficheiro efectivamente
  /// guardado — impede referências a imagens que nunca foram carregadas.
  bool _isStoredImage(String path) {
    if (!RegExp(r'^/uploads/[a-f0-9]{32}\.(jpg|png|webp)$').hasMatch(path)) {
      return false;
    }
    final filename = path.substring('/uploads/'.length);
    return File('${imageDirectory.path}/$filename').existsSync();
  }

  String _uniqueEstablishmentSlug(String name) {
    var slug = normalizeText(name)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'estabelecimento';
    var candidate = slug;
    var suffix = 2;
    while (db
        .select('SELECT id FROM establishments WHERE slug = ?', [candidate])
        .isNotEmpty) {
      candidate = '$slug-$suffix';
      suffix++;
    }
    return candidate;
  }

  /// Carrega uma imagem de candidatura (fotos dos documentos do entregador).
  ///
  /// O candidato ainda não tem conta, por isso o endpoint é público — mas com
  /// limite de tentativas por IP e a mesma validação de imagens do resto da
  /// API (JPEG/PNG/WebP até 5 MB, assinatura verificada).
  Future<Response> _uploadApplicationImage(Request request) async {
    const window = Duration(minutes: 10);
    _checkRateLimit(
      request,
      bucket: 'application_image',
      maxAttempts: 40,
      window: window,
    );
    _recordRateLimitHit(
      request,
      bucket: 'application_image',
      window: window,
    );
    final body = await _readBodyLimited(
      request,
      maxBytes: 7 * 1024 * 1024,
    );
    final imageUrl = await _saveImageUpload(
      mimeType: body['mime_type'] as String?,
      encoded: body['data_base64'] as String?,
    );
    return jsonResponse({'image_url': imageUrl}, status: 201);
  }

  /// Candidatura pública (estabelecimento ou entregador).
  ///
  /// Cria a linha em `applications` e, para quem não tem conta, também uma
  /// conta de candidatura (`role` partner/delivery com
  /// `approval_status = 'pending'`) para poder entrar e consultar o estado.
  /// Reenvio de candidaturas `changes_requested` exige a sessão do dono.
  Future<Response> _createApplication(Request request) async {
    const window = Duration(minutes: 10);
    _checkRateLimit(
      request,
      bucket: 'application',
      maxAttempts: 5,
      window: window,
    );
    _recordRateLimitHit(request, bucket: 'application', window: window);
    final body = await readBody(request);

    final kind = requiredString(
      body,
      'kind',
      max: 20,
      label: 'tipo de candidatura',
    );
    if (kind != 'establishment' && kind != 'delivery') {
      throw ApiError(422, 'invalid_kind', 'Tipo de candidatura inválido.');
    }
    final name = requiredString(body, 'name', min: 2, max: 80, label: 'nome');
    final phone = requiredString(
      body,
      'phone',
      min: 9,
      max: 20,
      label: 'telemóvel',
    ).replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      throw ApiError(
        422,
        'invalid_phone',
        'Indique um número moçambicano válido (ex.: 84 123 4567).',
      );
    }
    final password = requiredString(
      body,
      'password',
      min: 8,
      max: 200,
      label: 'palavra-passe',
    );
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw ApiError(
        422,
        'weak_password',
        'A palavra-passe deve ter letras e números (mínimo 8 caracteres).',
      );
    }

    final rawEmail = body['email'];
    final String email;
    if (rawEmail is String && rawEmail.trim().isNotEmpty) {
      email = rawEmail.trim().toLowerCase();
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        throw ApiError(422, 'invalid_email', 'Indique um email válido.');
      }
    } else {
      final domain = kind == 'establishment'
          ? 'estabelecimentos'
          : 'entregadores';
      email = '$phone@$domain.nacala.delivery';
    }

    final rawWhatsapp = body['whatsapp'];
    String? whatsapp;
    if (rawWhatsapp is String && rawWhatsapp.trim().isNotEmpty) {
      whatsapp = rawWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(whatsapp)) {
        throw ApiError(
          422,
          'invalid_whatsapp',
          'Indique um número de WhatsApp moçambicano válido '
              '(ex.: 84 123 4567).',
        );
      }
    }

    final payload = _applicationPayload(body, kind);

    // Sessão opcional: candidato com conta pendente reenvia a própria
    // candidatura; uma conta de cliente candidata-se mantendo a conta.
    AuthUser? actor;
    try {
      actor = optionalUser(request);
    } on ApiError {
      actor = null; // conta inativa/removida: trata como anónimo
    } on JWTException {
      actor = null; // token expirado num pedido público
    }

    Row? existing;
    if (actor != null) {
      final own = db.select(
        'SELECT * FROM applications WHERE user_id = ? '
        'ORDER BY created_at DESC LIMIT 1',
        [actor.id],
      );
      if (own.isNotEmpty) {
        existing = own.first;
      } else if (actor.role != 'customer') {
        // Uma conta tem um só papel: parceiro/estafeta/admin/funcionário
        // não cria uma segunda identidade por cima.
        throw ApiError(
          409,
          'account_has_role',
          'Esta conta já tem um papel na plataforma. Cria uma nova conta '
              'para te candidatares.',
        );
      }
    }
    if (existing == null) {
      final byContact = db.select(
        'SELECT * FROM applications WHERE email = ? OR phone = ?',
        [email, phone],
      );
      if (byContact.isNotEmpty) existing = byContact.first;
    }

    if (existing != null) {
      final status = existing['status'] as String;
      if (status == 'pending') {
        throw ApiError(
          409,
          'already_applied',
          'Já existe uma candidatura em análise. Entra na tua conta para '
              'acompanhar o estado.',
        );
      }
      if (status == 'approved') {
        throw ApiError(
          409,
          'already_registered',
          'Esta candidatura já foi aprovada.',
        );
      }
      if (status == 'rejected') {
        throw ApiError(
          409,
          'application_rejected',
          'A candidatura foi recusada. Contacta a equipa da plataforma.',
        );
      }
      // `changes_requested` → só o dono, com sessão, pode reenviar.
      if (existing['kind'] != kind) {
        throw ApiError(
          409,
          'kind_mismatch',
          'A candidatura existente é de outro tipo de conta.',
        );
      }
      if (actor == null || actor.id != existing['user_id']) {
        throw ApiError(
          403,
          'login_required',
          'Entra na tua conta para reenviar a candidatura corrigida.',
        );
      }
      return _resubmitApplication(
        actor,
        application: existing,
        name: name,
        email: email,
        phone: phone,
        whatsapp: whatsapp,
        password: password,
        payload: payload,
      );
    }

    final reuseCustomerAccount = actor != null;
    if (actor == null) {
      final registered = db.select(
        'SELECT id FROM users WHERE email = ? OR phone = ?',
        [email, phone],
      );
      if (registered.isNotEmpty) {
        throw ApiError(
          409,
          'already_registered',
          'Já existe uma conta com este email ou telemóvel. Entra na tua '
              'conta para candidatar-te.',
        );
      }
    } else {
      final registered = db.select(
        'SELECT id FROM users WHERE (email = ? OR phone = ?) AND id != ?',
        [email, phone, actor.id],
      );
      if (registered.isNotEmpty) {
        throw ApiError(
          409,
          'already_registered',
          'Já existe uma conta com este email ou telemóvel.',
        );
      }
    }

    final digest = await hashPasswordAsync(password);
    final id = newId();
    final now = nowIso();
    final applicantUserId = reuseCustomerAccount ? actor.id : newId();

    db.execute('BEGIN IMMEDIATE');
    try {
      if (!reuseCustomerAccount) {
        // Conta de candidatura: entra para consultar o estado; o painel
        // fica bloqueado no servidor até `approval_status = 'approved'`.
        db.execute(
          '''
          INSERT INTO users (id, role, name, email, phone, whatsapp,
            password_hash, password_salt, token_version, is_active,
            approval_status, application_id, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 1, 'pending', ?, ?)
          ''',
          [
            applicantUserId,
            kind == 'establishment' ? 'partner' : 'delivery',
            name,
            email,
            phone,
            whatsapp,
            digest.hash,
            digest.salt,
            id,
            now,
          ],
        );
      }
      db.execute(
        '''
        INSERT INTO applications (id, kind, status, name, email, phone,
          whatsapp, password_hash, password_salt, payload, user_id,
          created_at, updated_at)
        VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          id,
          kind,
          name,
          email,
          phone,
          whatsapp,
          digest.hash,
          digest.salt,
          jsonEncode(payload),
          applicantUserId,
          now,
          now,
        ],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor?.id, 'application.create', 'application', id, {
      'kind': kind,
      'email': email,
    });
    _notifyAdmins(
      'application_new',
      kind == 'establishment'
          ? 'Nova candidatura de estabelecimento'
          : 'Nova candidatura de entregador',
      '$name candidatou-se. Revê os dados em Gestão de Registos.',
      {'application_id': id, 'kind': kind},
    );

    final row =
        db.select('SELECT * FROM applications WHERE id = ?', [id]).first;
    return jsonResponse({'application': applicationJson(row)}, status: 201);
  }

  /// Reenvio de uma candidatura `changes_requested` pelo próprio dono.
  Future<Response> _resubmitApplication(
    AuthUser actor, {
    required Row application,
    required String name,
    required String email,
    required String phone,
    required String? whatsapp,
    required String password,
    required Map<String, dynamic> payload,
  }) async {
    final id = application['id'] as String;
    final ownerUserId = application['user_id'] as String?;

    final appClash = db.select(
      'SELECT id FROM applications WHERE (email = ? OR phone = ?) AND id != ?',
      [email, phone, id],
    );
    if (appClash.isNotEmpty) {
      throw ApiError(
        409,
        'already_registered',
        'Já existe uma conta ou candidatura com este email ou telemóvel.',
      );
    }
    if (ownerUserId != null) {
      final userClash = db.select(
        'SELECT id FROM users WHERE (email = ? OR phone = ?) AND id != ?',
        [email, phone, ownerUserId],
      );
      if (userClash.isNotEmpty) {
        throw ApiError(
          409,
          'already_registered',
          'Já existe uma conta com este email ou telemóvel.',
        );
      }
    }

    final digest = await hashPasswordAsync(password);
    final now = nowIso();
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        '''
        UPDATE applications SET name = ?, email = ?, phone = ?, whatsapp = ?,
          payload = ?, password_hash = ?, password_salt = ?,
          status = 'pending', updated_at = ?
        WHERE id = ?
        ''',
        [
          name,
          email,
          phone,
          whatsapp,
          jsonEncode(payload),
          digest.hash,
          digest.salt,
          now,
          id,
        ],
      );
      // Sincroniza apenas a conta criada pela própria candidatura (nunca
      // uma conta de cliente — o papel dela não muda com um reenvio).
      if (ownerUserId != null) {
        final users = db.select(
          'SELECT * FROM users WHERE id = ?',
          [ownerUserId],
        );
        if (users.isNotEmpty && users.first['application_id'] == id) {
          db.execute(
            '''
            UPDATE users SET name = ?, email = ?, phone = ?, whatsapp = ?,
              password_hash = ?, password_salt = ?, approval_status = 'pending'
            WHERE id = ?
            ''',
            [
              name,
              email,
              phone,
              whatsapp,
              digest.hash,
              digest.salt,
              ownerUserId,
            ],
          );
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'application.resubmit', 'application', id, {
      'kind': application['kind'],
    });
    _notifyAdmins(
      'application_new',
      'Candidatura reenviada',
      '$name corrigiu a candidatura e reenviou para revisão.',
      {'application_id': id},
    );

    final updated =
        db.select('SELECT * FROM applications WHERE id = ?', [id]).first;
    return jsonResponse({'application': applicationJson(updated)});
  }

  /// Candidatura da conta autenticada (para o candidato consultar o estado).
  Future<Response> _myApplication(Request request) async {
    final user = requireUser(request);
    final rows = db.select(
      'SELECT * FROM applications WHERE user_id = ? '
      'ORDER BY created_at DESC LIMIT 1',
      [user.id],
    );
    if (rows.isEmpty) {
      throw ApiError(
        404,
        'not_found',
        'Não existe nenhuma candidatura associada a esta conta.',
      );
    }
    return jsonResponse({'application': applicationJson(rows.first)});
  }

  Future<Response> _adminApplications(Request request) async {
    requirePermission(request, 'applications');
    const statuses = {'pending', 'approved', 'rejected', 'changes_requested'};
    const kinds = {'establishment', 'delivery'};
    final query = request.url.queryParameters;
    final status = (query['status'] ?? '').trim();
    final kind = (query['kind'] ?? '').trim();
    if (status.isNotEmpty && !statuses.contains(status)) {
      throw ApiError(422, 'invalid_status', 'Estado de candidatura inválido.');
    }
    if (kind.isNotEmpty && !kinds.contains(kind)) {
      throw ApiError(422, 'invalid_kind', 'Tipo de candidatura inválido.');
    }
    final where = <String>[];
    final args = <Object?>[];
    if (status.isNotEmpty) {
      where.add('status = ?');
      args.add(status);
    }
    if (kind.isNotEmpty) {
      where.add('kind = ?');
      args.add(kind);
    }
    final rows = db.select(
      'SELECT * FROM applications '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY created_at DESC',
      args,
    );
    final counts = db.select(
      'SELECT status, COUNT(*) AS total FROM applications GROUP BY status',
    );
    return jsonResponse({
      'applications': [for (final row in rows) applicationJson(row)],
      'counts': {
        for (final row in counts) row['status'] as String: row['total'],
      },
    });
  }

  Future<Response> _adminApproveApplication(Request request, String id) async {
    final actor = requirePermission(request, 'applications');
    final body = await _optionalBody(request);
    final note = (body['note'] as String?)?.trim();
    final rows = db.select('SELECT * FROM applications WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Candidatura inexistente.');
    }
    final application = rows.first;
    final status = application['status'] as String;
    if (status == 'approved') {
      throw ApiError(409, 'already_approved', 'Candidatura já aprovada.');
    }
    if (status == 'rejected') {
      throw ApiError(
        409,
        'already_reviewed',
        'Candidatura já avaliada (recusada).',
      );
    }

    final kind = application['kind'] as String;
    final payload = _decodeMap(application['payload']);
    final userId = application['user_id'];
    if (userId is! String) {
      throw ApiError(
        409,
        'application_unlinked',
        'Candidatura sem conta associada.',
      );
    }
    if (db.select('SELECT id FROM users WHERE id = ?', [userId]).isEmpty) {
      throw ApiError(
        409,
        'application_unlinked',
        'Candidatura sem conta associada.',
      );
    }

    final applicantPhone = application['phone'] as String;
    final now = nowIso();
    String? establishmentId;

    db.execute('BEGIN IMMEDIATE');
    try {
      if (kind == 'establishment') {
        final categoryId = payload['category_id'] as String? ?? '';
        if (db
            .select('SELECT id FROM categories WHERE id = ?', [categoryId])
            .isEmpty) {
          throw ApiError(
            422,
            'invalid_category',
            'A categoria da candidatura já não existe.',
          );
        }
        final establishmentName =
            (payload['establishment_name'] as String? ?? '').trim();
        if (establishmentName.length < 2) {
          throw ApiError(
            422,
            'invalid_establishment_name',
            'Nome do estabelecimento em falta na candidatura.',
          );
        }
        final contactPhone =
            (payload['phone'] as String? ?? '').replaceAll(
              RegExp(r'[^0-9]'),
              '',
            );
        establishmentId = newId();
        db.execute(
          '''
          INSERT INTO establishments (id, owner_user_id, category_id, name,
            slug, description, phone, address, image_url, delivery_fee_cents,
            prep_minutes, opens_at, closes_at, is_open, is_approved,
            latitude, longitude, whatsapp, nuit, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, ?, ?, ?, ?, ?)
          ''',
          [
            establishmentId,
            userId,
            categoryId,
            establishmentName,
            _uniqueEstablishmentSlug(establishmentName),
            payload['description'] ?? '',
            contactPhone.isEmpty ? applicantPhone : contactPhone,
            payload['address'] ?? '',
            payload['image_url'],
            intValue(
              payload['delivery_fee_cents'],
              min: 0,
              max: 1000000,
              fallback: 0,
            ),
            intValue(
              payload['prep_minutes'],
              min: 5,
              max: 240,
              fallback: 30,
            ),
            payload['opens_at'] ?? '08:00',
            payload['closes_at'] ?? '21:00',
            payload['latitude'],
            payload['longitude'],
            payload['whatsapp'],
            payload['nuit'],
            now,
          ],
        );
      }

      // Conta: papel final e aprovação (levanta o bloqueio do painel).
      db.execute(
        '''
        UPDATE users SET role = ?, approval_status = 'approved',
          application_id = ?
        WHERE id = ?
        ''',
        [kind == 'establishment' ? 'partner' : 'delivery', id, userId],
      );
      db.execute(
        '''
        UPDATE applications SET status = 'approved', admin_note = ?,
          reviewed_by = ?, reviewed_at = ?, updated_at = ?
        WHERE id = ?
        ''',
        [note, actor.id, now, now, id],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'application.approve', 'application', id, {'kind': kind});
    _notify(
      userId,
      'application_approved',
      'Candidatura aprovada',
      kind == 'establishment'
          ? 'O teu estabelecimento foi aprovado. Entra na tua conta para '
                'publicar produtos.'
          : 'A tua candidatura de entregador foi aprovada. Entra na tua '
                'conta para aceitar entregas.',
      data: {'application_id': id},
    );

    final updated =
        db.select('SELECT * FROM applications WHERE id = ?', [id]).first;
    return jsonResponse({
      'application': applicationJson(updated),
      if (establishmentId != null) 'establishment_id': establishmentId,
    });
  }

  Future<Response> _adminRejectApplication(Request request, String id) async {
    final actor = requirePermission(request, 'applications');
    final body = await _optionalBody(request);
    final note = (body['note'] as String?)?.trim();
    final rows = db.select('SELECT * FROM applications WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Candidatura inexistente.');
    }
    final application = rows.first;
    final status = application['status'] as String;
    if (status == 'approved') {
      throw ApiError(
        409,
        'already_approved',
        'Candidatura já aprovada; elimina a conta se for caso disso.',
      );
    }
    if (status == 'rejected') {
      throw ApiError(409, 'already_reviewed', 'Candidatura já recusada.');
    }

    final userId = application['user_id'] as String?;
    final now = nowIso();
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        '''
        UPDATE applications SET status = 'rejected', admin_note = ?,
          reviewed_by = ?, reviewed_at = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          (note == null || note.isEmpty) ? 'Candidatura recusada.' : note,
          actor.id,
          now,
          now,
          id,
        ],
      );
      // Conta criada pela candidatura fica bloqueada no painel, mas
      // mantém o acesso para consultar o estado e o motivo.
      if (userId != null) {
        final users = db.select(
          'SELECT * FROM users WHERE id = ? AND application_id = ?',
          [userId, id],
        );
        if (users.isNotEmpty) {
          db.execute(
            "UPDATE users SET approval_status = 'rejected' WHERE id = ?",
            [userId],
          );
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'application.reject', 'application', id, {
      'kind': application['kind'],
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (userId != null) {
      _notify(
        userId,
        'application_rejected',
        'Candidatura recusada',
        (note == null || note.isEmpty)
            ? 'A tua candidatura não foi aprovada. Contacta a equipa da '
                  'plataforma para saber mais.'
            : note,
        data: {'application_id': id},
      );
    }

    final updated =
        db.select('SELECT * FROM applications WHERE id = ?', [id]).first;
    return jsonResponse({'application': applicationJson(updated)});
  }

  Future<Response> _adminRequestChanges(Request request, String id) async {
    final actor = requirePermission(request, 'applications');
    final body = await _optionalBody(request);
    final note = (body['note'] as String?)?.trim() ?? '';
    if (note.isEmpty) {
      throw ApiError(
        422,
        'missing_note',
        'Indique o que o candidato deve corrigir.',
      );
    }
    final rows = db.select('SELECT * FROM applications WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Candidatura inexistente.');
    }
    final application = rows.first;
    final status = application['status'] as String;
    if (status == 'approved' || status == 'rejected') {
      throw ApiError(
        409,
        'already_reviewed',
        'A candidatura já foi avaliada em definitivo.',
      );
    }

    final userId = application['user_id'] as String?;
    final now = nowIso();
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        '''
        UPDATE applications SET status = 'changes_requested', admin_note = ?,
          reviewed_by = ?, reviewed_at = ?, updated_at = ?
        WHERE id = ?
        ''',
        [note, actor.id, now, now, id],
      );
      // O candidato continua a poder entrar para corrigir e reenviar.
      if (userId != null) {
        final users = db.select(
          'SELECT * FROM users WHERE id = ? AND application_id = ?',
          [userId, id],
        );
        if (users.isNotEmpty) {
          db.execute(
            "UPDATE users SET approval_status = 'pending' WHERE id = ?",
            [userId],
          );
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'application.changes', 'application', id, {
      'kind': application['kind'],
      'note': note,
    });
    if (userId != null) {
      _notify(
        userId,
        'application_changes',
        'Precisamos de mais informações',
        note,
        data: {'application_id': id},
      );
    }

    final updated =
        db.select('SELECT * FROM applications WHERE id = ?', [id]).first;
    return jsonResponse({'application': applicationJson(updated)});
  }

  // ------------------------------------- funcionários (FASE 10)

  List<String> _parsePermissions(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw ApiError(422, 'invalid_permissions', 'Permissões inválidas.');
    }
    final result = <String>{};
    for (final item in raw) {
      final key = item is String ? item.trim() : '';
      if (!_employeePermissions.contains(key)) {
        throw ApiError(
          422,
          'invalid_permissions',
          'Permissão desconhecida: $item.',
        );
      }
      result.add(key);
    }
    return result.toList()..sort();
  }

  static const _employeeSelect = '''
    SELECT e.*, u.name, u.email, u.phone, u.is_active AS user_active
    FROM employees e
    JOIN users u ON u.id = e.user_id
  ''';

  Future<Response> _adminEmployees(Request request) async {
    requireRole(request, ['admin']);
    final rows = db.select('$_employeeSelect ORDER BY e.created_at DESC');
    return jsonResponse({
      'employees': [for (final row in rows) employeeJson(row)],
    });
  }

  Future<Response> _adminCreateEmployee(Request request) async {
    final actor = requireRole(request, ['admin']);
    final body = await readBody(request);
    final name = requiredString(body, 'name', min: 2, max: 80, label: 'nome');
    final email = requiredString(
      body,
      'email',
      min: 5,
      max: 120,
      label: 'email',
    ).toLowerCase();
    final phone = requiredString(
      body,
      'phone',
      min: 9,
      max: 20,
      label: 'telemóvel',
    ).replaceAll(RegExp(r'[^0-9]'), '');
    final password = requiredString(
      body,
      'password',
      min: 8,
      max: 200,
      label: 'palavra-passe',
    );
    final level = requiredString(body, 'level', max: 20, label: 'nível');
    final permissions = _parsePermissions(body['permissions']);
    final establishmentId =
        (body['establishment_id'] as String?)?.trim() ?? '';

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ApiError(422, 'invalid_email', 'Indique um email válido.');
    }
    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      throw ApiError(
        422,
        'invalid_phone',
        'Indique um número moçambicano válido (ex.: 84 123 4567).',
      );
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw ApiError(
        422,
        'weak_password',
        'A palavra-passe deve ter letras e números (mínimo 8 caracteres).',
      );
    }
    if (!_employeeLevels.contains(level)) {
      throw ApiError(
        422,
        'invalid_level',
        'Nível inválido (use admin ou staff).',
      );
    }
    if (establishmentId.isNotEmpty &&
        db
            .select('SELECT id FROM establishments WHERE id = ?', [
              establishmentId,
            ])
            .isEmpty) {
      throw ApiError(
        422,
        'invalid_establishment',
        'Estabelecimento inexistente.',
      );
    }
    final duplicate = db.select(
      'SELECT id FROM users WHERE email = ? OR phone = ?',
      [email, phone],
    );
    if (duplicate.isNotEmpty) {
      throw ApiError(
        409,
        'already_registered',
        'Já existe uma conta com este email ou telemóvel.',
      );
    }

    final digest = await hashPasswordAsync(password);
    final userId = newId();
    final employeeId = newId();
    final now = nowIso();
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        '''
        INSERT INTO users (id, role, name, email, phone, password_hash,
          password_salt, token_version, is_active, approval_status, created_at)
        VALUES (?, 'employee', ?, ?, ?, ?, ?, 0, 1, 'approved', ?)
        ''',
        [userId, name, email, phone, digest.hash, digest.salt, now],
      );
      db.execute(
        '''
        INSERT INTO employees (id, user_id, establishment_id, level,
          permissions, is_active, created_by, created_at)
        VALUES (?, ?, ?, ?, ?, 1, ?, ?)
        ''',
        [
          employeeId,
          userId,
          establishmentId.isEmpty ? null : establishmentId,
          level,
          jsonEncode(permissions),
          actor.id,
          now,
        ],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'employee.create', 'employee', employeeId, {
      'name': name,
      'email': email,
      'level': level,
      'permissions': permissions,
    });
    final row = db.select(
      '$_employeeSelect WHERE e.id = ?',
      [employeeId],
    ).first;
    return jsonResponse({'employee': employeeJson(row)}, status: 201);
  }

  Future<Response> _adminUpdateEmployee(Request request, String id) async {
    final actor = requireRole(request, ['admin']);
    final body = await _optionalBody(request);
    final rows = db.select(
      '$_employeeSelect WHERE e.id = ?',
      [id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Funcionário não encontrado.');
    }
    final employee = rows.first;
    final userId = employee['user_id'] as String;
    if (userId == actor.id) {
      throw ApiError(
        409,
        'self_modify',
        'Não podes alterar o teu próprio registo de funcionário.',
      );
    }

    final level = body.containsKey('level')
        ? requiredString(body, 'level', max: 20, label: 'nível')
        : employee['level'] as String;
    if (!_employeeLevels.contains(level)) {
      throw ApiError(
        422,
        'invalid_level',
        'Nível inválido (use admin ou staff).',
      );
    }
    final permissions = body.containsKey('permissions')
        ? _parsePermissions(body['permissions'])
        : _decodeList(employee['permissions']);
    var active = employee['is_active'] == 1 && employee['user_active'] == 1;
    if (body.containsKey('is_active')) {
      final raw = body['is_active'];
      if (raw is! bool) {
        throw ApiError(422, 'invalid_value', 'Estado inválido.');
      }
      active = raw;
    }

    final activeFlag = active ? 1 : 0;
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        'UPDATE employees SET level = ?, permissions = ?, is_active = ? '
        'WHERE id = ?',
        [level, jsonEncode(permissions), activeFlag, id],
      );
      // A conta de acesso espelha o estado: desactivar corta o login e
      // invalida as sessões abertas (token_version + 1).
      db.execute(
        'UPDATE users SET is_active = ?, '
        'token_version = token_version + CASE WHEN ? = 0 THEN 1 ELSE 0 END '
        'WHERE id = ?',
        [activeFlag, activeFlag, userId],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    audit(actor.id, 'employee.update', 'employee', id, {
      'level': level,
      'permissions': permissions,
      'is_active': active,
    });
    final updated = db.select(
      '$_employeeSelect WHERE e.id = ?',
      [id],
    ).first;
    return jsonResponse({'employee': employeeJson(updated)});
  }

  Future<Response> _adminDeleteEmployee(Request request, String id) async {
    final actor = requireRole(request, ['admin']);
    final rows = db.select(
      '$_employeeSelect WHERE e.id = ?',
      [id],
    );
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Funcionário não encontrado.');
    }
    final employee = rows.first;
    final userId = employee['user_id'] as String;
    if (userId == actor.id) {
      throw ApiError(
        409,
        'self_delete',
        'Não podes eliminar o teu próprio registo.',
      );
    }
    final hasOrders = db.select(
      'SELECT 1 FROM orders WHERE customer_id = ? LIMIT 1',
      [userId],
    );
    if (hasOrders.isNotEmpty) {
      throw ApiError(
        409,
        'user_has_orders',
        'Esta conta tem encomendas no histórico e não pode ser eliminada.',
      );
    }
    // A remoção da conta remove também a linha de funcionários (CASCADE).
    db.execute('DELETE FROM users WHERE id = ?', [userId]);
    audit(actor.id, 'employee.delete', 'employee', id, {
      'name': employee['name'],
      'email': employee['email'],
    });
    return jsonResponse({'ok': true});
  }

  // ------------------------------------- notificações (FASE 12)

  Future<Response> _listNotifications(Request request) async {
    final user = requireUser(request);
    final limit = intValue(
      request.url.queryParameters['limit'],
      min: 1,
      max: 100,
      fallback: 50,
    );
    final rows = db.select(
      'SELECT * FROM notifications WHERE user_id = ? '
      'ORDER BY created_at DESC, id DESC LIMIT ?',
      [user.id, limit],
    );
    final unread = db
        .select(
          'SELECT COUNT(*) AS total FROM notifications '
          'WHERE user_id = ? AND is_read = 0',
          [user.id],
        )
        .first['total'];
    return jsonResponse({
      'notifications': [for (final row in rows) notificationJson(row)],
      'unread_count': unread,
    });
  }

  Future<Response> _markNotificationsRead(Request request) async {
    final user = requireUser(request);
    final body = await _optionalBody(request);
    final rawIds = body['ids'];
    if (rawIds != null) {
      if (rawIds is! List) {
        throw ApiError(422, 'invalid_ids', 'Lista de notificações inválida.');
      }
      final ids = <String>[];
      for (final item in rawIds) {
        if (item is! String || item.isEmpty) {
          throw ApiError(
            422,
            'invalid_ids',
            'Lista de notificações inválida.',
          );
        }
        ids.add(item);
      }
      if (ids.isEmpty) return jsonResponse({'updated': 0});
      final placeholders = List.filled(ids.length, '?').join(', ');
      final args = <Object?>[user.id, ...ids];
      final pending = db
          .select(
            'SELECT COUNT(*) AS total FROM notifications '
            'WHERE user_id = ? AND is_read = 0 AND id IN ($placeholders)',
            args,
          )
          .first['total'];
      db.execute(
        'UPDATE notifications SET is_read = 1 '
        'WHERE user_id = ? AND id IN ($placeholders)',
        args,
      );
      return jsonResponse({'updated': pending});
    }
    final pending = db
        .select(
          'SELECT COUNT(*) AS total FROM notifications '
          'WHERE user_id = ? AND is_read = 0',
          [user.id],
        )
        .first['total'];
    db.execute(
      'UPDATE notifications SET is_read = 1 WHERE user_id = ?',
      [user.id],
    );
    return jsonResponse({'updated': pending});
  }

  Future<Response> _adminNotifications(Request request) async {
    requirePermission(request, 'notifications');
    final query = request.url.queryParameters;
    final targetUser = (query['user_id'] ?? '').trim();
    final limit = intValue(
      query['limit'],
      min: 1,
      max: 200,
      fallback: 100,
    );
    final where = <String>[];
    final args = <Object?>[];
    if (targetUser.isNotEmpty) {
      where.add('n.user_id = ?');
      args.add(targetUser);
    }
    args.add(limit);
    final rows = db.select(
      'SELECT n.*, u.name AS user_name, u.email AS user_email '
      'FROM notifications n JOIN users u ON u.id = n.user_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY n.created_at DESC LIMIT ?',
      args,
    );
    return jsonResponse({
      'notifications': [
        for (final row in rows) notificationJson(row, withUser: true),
      ],
    });
  }

  // ============================================================ CHAT (FASE 13)

  /// Lista as conversas do utilizador autenticado (cliente, parceiro ou
  /// estafeta), com a última mensagem e o nome do outro participante.
  Future<Response> _listConversations(Request request) async {
    final user = requireUser(request);
    final rows = db.select(
      '''
      SELECT c.*,
        (SELECT m.body FROM messages m
          WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1)
          AS last_body,
        (SELECT m.created_at FROM messages m
          WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1)
          AS last_created,
        (SELECT m.sender_id FROM messages m
          WHERE m.conversation_id = c.id ORDER BY m.created_at DESC LIMIT 1)
          AS last_sender_id,
        (SELECT COUNT(*) FROM messages m
          WHERE m.conversation_id = c.id AND m.sender_id != ? AND m.read_at IS NULL)
          AS unread_count
      FROM conversations c
      WHERE c.customer_id = ? OR c.partner_id = ? OR c.courier_id = ?
      ORDER BY COALESCE(c.last_message_at, c.created_at) DESC
      ''',
      [user.id, user.id, user.id, user.id],
    );
    return jsonResponse({
      'conversations': [
        for (final row in rows) conversationJson(row, currentUserId: user.id),
      ],
    });
  }

  /// Cria (ou reutiliza) uma conversa entre dois utilizadores, opcionalmente
  /// ligada a uma encomenda. Participantes válidos:
  /// cliente↔parceiro, cliente↔estafeta, parceiro↔estafeta.
  Future<Response> _createConversation(Request request) async {
    final user = requireUser(request);
    final body = await _optionalBody(request);
    final otherId = (body['other_user_id'] ?? '').toString().trim();
    final orderId = (body['order_id'] ?? '').toString().trim();
    if (otherId.isEmpty) {
      throw ApiError(422, 'missing_other_user', 'Informe o outro participante.');
    }
    if (otherId == user.id) {
      throw ApiError(422, 'self_conversation', 'Não podes criar conversa contigo.');
    }
    // Valida que o outro utilizador existe e está ativo.
    final other = db.select('SELECT id, role FROM users WHERE id = ?', [otherId]);
    if (other.isEmpty) {
      throw ApiError(404, 'user_not_found', 'Utilizador não encontrado.');
    }
    // Valida a combinação de papéis.
    final allowed = <String, Set<String>>{
      'customer': {'partner', 'delivery'},
      'partner': {'customer', 'delivery'},
      'delivery': {'customer', 'partner'},
    };
    final myAllowed = allowed[user.role];
    if (myAllowed == null || !myAllowed.contains(other.first['role'] as String)) {
      throw ApiError(403, 'forbidden_pair', 'Esta combinação de participantes não é permitida.');
    }
    // Se houver encomenda, valida que pertence ao cliente e ao parceiro da conversa.
    if (orderId.isNotEmpty) {
      final order = db.select('SELECT * FROM orders WHERE id = ?', [orderId]);
      if (order.isEmpty) {
        throw ApiError(404, 'order_not_found', 'Encomenda não encontrada.');
      }
      final orderRow = order.first;
      final customerId = orderRow['customer_id'] as String;
      final establishmentId = orderRow['establishment_id'] as String;
      // O cliente da conversa deve ser o dono da encomenda.
      if (user.role == 'customer' && user.id != customerId) {
        throw ApiError(403, 'forbidden_order', 'Esta encomenda não é tua.');
      }
      // O parceiro deve ser o dono do estabelecimento da encomenda.
      final establishment = db.select(
        'SELECT owner_user_id FROM establishments WHERE id = ?',
        [establishmentId],
      );
      if (establishment.isEmpty) {
        throw ApiError(404, 'establishment_not_found', 'Estabelecimento não encontrado.');
      }
      final ownerId = establishment.first['owner_user_id'] as String?;
      if (user.role == 'partner' && ownerId != user.id) {
        throw ApiError(403, 'forbidden_order', 'Este estabelecimento não é teu.');
      }
    }
    // Reutiliza conversa existente entre os dois (mesma ordem, se indicada).
    final existing = db.select(
      '''
      SELECT * FROM conversations
      WHERE ((customer_id = ? AND partner_id = ?)
         OR (customer_id = ? AND partner_id = ?)
         OR (customer_id = ? AND courier_id = ?)
         OR (customer_id = ? AND courier_id = ?)
         OR (partner_id = ? AND courier_id = ?)
         OR (partner_id = ? AND courier_id = ?))
        AND (order_id IS NULL OR order_id = ?)
      ''',
      [
        user.id, otherId,
        otherId, user.id,
        user.id, otherId,
        otherId, user.id,
        user.id, otherId,
        otherId, user.id,
        orderId.isEmpty ? null : orderId,
      ],
    );
    if (existing.isNotEmpty) {
      final row = existing.first;
      return jsonResponse({'conversation': conversationJson(row, currentUserId: user.id)});
    }
    final id = newId();
    final now = nowIso();
    // Determina papéis com base no utilizador autenticado e no outro.
    String? customerId, partnerId, courierId;
    if (user.role == 'customer') {
      customerId = user.id;
      if (other.first['role'] == 'partner') partnerId = otherId;
      if (other.first['role'] == 'delivery') courierId = otherId;
    } else if (user.role == 'partner') {
      partnerId = user.id;
      if (other.first['role'] == 'customer') customerId = otherId;
      if (other.first['role'] == 'delivery') courierId = otherId;
    } else if (user.role == 'delivery') {
      courierId = user.id;
      if (other.first['role'] == 'customer') customerId = otherId;
      if (other.first['role'] == 'partner') partnerId = otherId;
    }
    db.execute(
      '''
      INSERT INTO conversations (id, order_id, customer_id, partner_id,
        courier_id, status, last_message_at, created_at)
      VALUES (?, ?, ?, ?, ?, 'active', ?, ?)
      ''',
      [id, orderId.isEmpty ? null : orderId, customerId, partnerId, courierId,
        now, now],
    );
    audit(user.id, 'conversation.create', 'conversation', id, {
      'other_user_id': otherId,
      'order_id': orderId.isEmpty ? null : orderId,
    });
    final row = db.select('SELECT * FROM conversations WHERE id = ?', [id]).first;
    return jsonResponse({'conversation': conversationJson(row, currentUserId: user.id)}, status: 201);
  }

  /// Lista as mensagens de uma conversa (apenas participantes).
  Future<Response> _listMessages(Request request) async {
    final user = requireUser(request);
    final conversationId = request.params['id'] ?? '';
    final limit = intValue(request.url.queryParameters['limit'], min: 1, max: 200, fallback: 50);
    final before = request.url.queryParameters['before'];
    final conversation = db.select('SELECT * FROM conversations WHERE id = ?', [conversationId]);
    if (conversation.isEmpty) {
      throw ApiError(404, 'conversation_not_found', 'Conversa não encontrada.');
    }
    final row = conversation.first;
    if (row['customer_id'] != user.id &&
        row['partner_id'] != user.id &&
        row['courier_id'] != user.id) {
      throw ApiError(403, 'forbidden', 'Não és participante desta conversa.');
    }
    final where = <String>['conversation_id = ?'];
    final args = <Object?>[conversationId];
    if (before != null && before.isNotEmpty) {
      where.add('created_at < ?');
      args.add(before);
    }
    args.add(limit);
    final rows = db.select(
      'SELECT * FROM messages WHERE ${where.join(' AND ')} '
      'ORDER BY created_at DESC, id DESC LIMIT ?',
      args,
    );
    return jsonResponse({
      'messages': [for (final r in rows.reversed) messageJson(r)],
    });
  }

  /// Envia uma mensagem numa conversa (apenas participantes).
  Future<Response> _sendMessage(Request request) async {
    final user = requireUser(request);
    final conversationId = request.params['id'] ?? '';
    final body = await _optionalBody(request);
    final text = (body['body'] ?? '').toString().trim();
    final type = (body['type'] ?? 'text').toString();
    if (!{'text', 'image', 'location', 'order_status'}.contains(type)) {
      throw ApiError(422, 'invalid_type', 'Tipo de mensagem inválido.');
    }
    if (type == 'text' && text.isEmpty) {
      throw ApiError(422, 'empty_body', 'Escreve uma mensagem.');
    }
    final conversation = db.select('SELECT * FROM conversations WHERE id = ?', [conversationId]);
    if (conversation.isEmpty) {
      throw ApiError(404, 'conversation_not_found', 'Conversa não encontrada.');
    }
    final row = conversation.first;
    if (row['customer_id'] != user.id &&
        row['partner_id'] != user.id &&
        row['courier_id'] != user.id) {
      throw ApiError(403, 'forbidden', 'Não és participante desta conversa.');
    }
    final id = newId();
    final now = nowIso();
    db.execute(
      '''
      INSERT INTO messages (id, conversation_id, sender_id, body, type, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [id, conversationId, user.id, text, type, now],
    );
    db.execute(
      'UPDATE conversations SET last_message_at = ? WHERE id = ?',
      [now, conversationId],
    );
    // Notificação persistente para o(s) outro(s) participante(s).
    final others = <String>[];
    final cId = row['customer_id'] as String?;
    final pId = row['partner_id'] as String?;
    final dId = row['courier_id'] as String?;
    for (final id in [cId, pId, dId]) {
      if (id != null && id != user.id) others.add(id);
    }
    final senderName = user.name;
    for (final otherId in others) {
      _notify(
        otherId,
        'chat_message',
        'Nova mensagem de $senderName',
        text.isNotEmpty ? text : '[anexo]',
        data: {'conversation_id': conversationId, 'sender_id': user.id},
      );
    }
    audit(user.id, 'message.send', 'message', id, {
      'conversation_id': conversationId,
      'type': type,
    });
    final msg = db.select('SELECT * FROM messages WHERE id = ?', [id]).first;
    return jsonResponse({'message': messageJson(msg)}, status: 201);
  }

  /// Marca mensagens de uma conversa como lidas pelo utilizador autenticado.
  Future<Response> _markMessagesRead(Request request) async {
    final user = requireUser(request);
    final conversationId = request.params['id'] ?? '';
    final conversation = db.select('SELECT * FROM conversations WHERE id = ?', [conversationId]);
    if (conversation.isEmpty) {
      throw ApiError(404, 'conversation_not_found', 'Conversa não encontrada.');
    }
    final row = conversation.first;
    if (row['customer_id'] != user.id &&
        row['partner_id'] != user.id &&
        row['courier_id'] != user.id) {
      throw ApiError(403, 'forbidden', 'Não és participante desta conversa.');
    }
    final now = nowIso();
    db.execute(
      'UPDATE messages SET read_at = ? WHERE conversation_id = ? AND sender_id != ? AND read_at IS NULL',
      [now, conversationId, user.id],
    );
    return jsonResponse({'ok': true});
  }

  /// Lista o histórico de chamadas do utilizador autenticado.
  Future<Response> _listCallLogs(Request request) async {
    final user = requireUser(request);
    final limit = intValue(request.url.queryParameters['limit'], min: 1, max: 100, fallback: 50);
    final rows = db.select(
      '''
      SELECT cl.*, u.name AS caller_name, u2.name AS callee_name
      FROM call_logs cl
      JOIN users u ON u.id = cl.caller_id
      JOIN users u2 ON u2.id = cl.callee_id
      WHERE cl.caller_id = ? OR cl.callee_id = ?
      ORDER BY cl.started_at DESC LIMIT ?
      ''',
      [user.id, user.id, limit],
    );
    return jsonResponse({
      'call_logs': [
        for (final r in rows) {
          {
            'id': r['id'],
            'conversation_id': r['conversation_id'],
            'caller_id': r['caller_id'],
            'caller_name': r['caller_name'],
            'callee_id': r['callee_id'],
            'callee_name': r['callee_name'],
            'type': r['type'],
            'status': r['status'],
            'started_at': r['started_at'],
            'answered_at': r['answered_at'],
            'ended_at': r['ended_at'],
            'duration_seconds': r['duration_seconds'],
          }
        },
      ],
    });
  }

  /// Regista uma chamada (iniciada, atendida, recusada, perdida, terminada).
  Future<Response> _logCall(Request request) async {
    final user = requireUser(request);
    final body = await _optionalBody(request);
    final calleeId = (body['callee_id'] ?? '').toString().trim();
    final conversationId = (body['conversation_id'] ?? '').toString().trim();
    final type = (body['type'] ?? 'voice').toString();
    final status = (body['status'] ?? 'initiated').toString();
    if (calleeId.isEmpty) {
      throw ApiError(422, 'missing_callee', 'Informe o destinatário.');
    }
    if (calleeId == user.id) {
      throw ApiError(422, 'self_call', 'Não podes ligar para ti mesmo.');
    }
    if (!{'voice', 'video'}.contains(type)) {
      throw ApiError(422, 'invalid_type', 'Tipo de chamada inválido.');
    }
    if (!{'initiated', 'answered', 'missed', 'declined', 'ended'}.contains(status)) {
      throw ApiError(422, 'invalid_status', 'Estado de chamada inválido.');
    }
    final callee = db.select('SELECT id FROM users WHERE id = ? AND is_active = 1', [calleeId]);
    if (callee.isEmpty) {
      throw ApiError(404, 'user_not_found', 'Destinatário não encontrado.');
    }
    if (conversationId.isNotEmpty) {
      final conversation = db.select('SELECT * FROM conversations WHERE id = ?', [conversationId]);
      if (conversation.isEmpty) {
        throw ApiError(404, 'conversation_not_found', 'Conversa não encontrada.');
      }
      final row = conversation.first;
      if (row['customer_id'] != user.id &&
          row['partner_id'] != user.id &&
          row['courier_id'] != user.id) {
        throw ApiError(403, 'forbidden', 'Não és participante desta conversa.');
      }
    }
    final id = newId();
    final now = nowIso();
    db.execute(
      '''
      INSERT INTO call_logs (id, conversation_id, caller_id, callee_id, type,
        status, started_at, answered_at, ended_at, duration_seconds)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [id, conversationId.isEmpty ? null : conversationId, user.id, calleeId,
        type, status, now, null, null, 0],
    );
    audit(user.id, 'call.log', 'call_log', id, {
      'callee_id': calleeId,
      'type': type,
      'status': status,
    });
    return jsonResponse({'call_log': {
      'id': id,
      'caller_id': user.id,
      'callee_id': calleeId,
      'type': type,
      'status': status,
      'started_at': now,
    }}, status: 201);
  }

  /// Dados resumidos de uma conversa para o ecrã de lista.
  Map<String, dynamic> conversationJson(Row row, {required String currentUserId}) {
    final customerId = row['customer_id'] as String?;
    final partnerId = row['partner_id'] as String?;
    final courierId = row['courier_id'] as String?;
    final participants = <String>[];
    if (customerId != null) participants.add(customerId);
    if (partnerId != null && partnerId != customerId) participants.add(partnerId);
    if (courierId != null && courierId != customerId && courierId != partnerId) {
      participants.add(courierId);
    }
    final otherId = participants.where((id) => id != currentUserId).firstOrNull;
    String? otherName;
    if (otherId != null) {
      final u = db.select('SELECT name FROM users WHERE id = ?', [otherId]);
      if (u.isNotEmpty) otherName = u.first['name'] as String?;
    }
    return {
      'id': row['id'],
      'order_id': row['order_id'],
      'customer_id': customerId,
      'partner_id': partnerId,
      'courier_id': courierId,
      'status': row['status'],
      'last_message_at': row['last_message_at'],
      'created_at': row['created_at'],
      'last_body': row['last_body'],
      'last_sender_id': row['last_sender_id'],
      'unread_count': row['unread_count'],
      'other_user_id': otherId,
      'other_user_name': otherName,
    };
  }

  /// Dados de uma mensagem para o cliente.
  Map<String, dynamic> messageJson(Row row) => {
    'id': row['id'],
    'conversation_id': row['conversation_id'],
    'sender_id': row['sender_id'],
    'body': row['body'],
    'type': row['type'],
    'read_at': row['read_at'],
    'created_at': row['created_at'],
  };
}



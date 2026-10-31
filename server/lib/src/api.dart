import 'dart:convert';

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

class Api {
  Api({required this.db, required this.jwt});

  final Database db;
  final JwtService jwt;

  Handler get handler => const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(_errors())
      .addHandler(_router.call);

  late final Router _router = Router()
    ..get('/health', (Request _) => jsonResponse({'status': 'ok'}))
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
    ..post('/api/auth/change-password', _changePassword)
    ..post('/api/auth/logout', _logout)
    ..get('/api/addresses', _listAddresses)
    ..post('/api/addresses', _createAddress)
    ..patch('/api/addresses/<id>', _updateAddress)
    ..delete('/api/addresses/<id>', _deleteAddress)
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
    ..post('/api/admin/partners/<id>/approve', _adminApprovePartner)
    ..post('/api/admin/partners/<id>/reject', _adminRejectPartner)
    ..get('/api/admin/users', _adminUsers)
    ..patch('/api/admin/users/<id>', _adminUpdateUser)
    ..get('/api/admin/orders', _adminOrders)
    ..get('/api/admin/audit', _adminAudit)
    ..post('/api/admin/categories', _adminCreateCategory)
    ..patch('/api/admin/categories/<id>', _adminUpdateCategory)
    ..delete('/api/admin/categories/<id>', _adminDeleteCategory);

  // ---------------------------------------------------------------- middleware

  Middleware _cors() => (inner) => (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };

  static const _corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,PATCH,DELETE,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization',
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

  Map<String, dynamic> _body(Map<String, dynamic> body) => body;

  Future<Map<String, dynamic>> readBody(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ApiError(400, 'invalid_body', 'Corpo do pedido inválido.');
    }
    return _body(decoded);
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
        'is_active': row['is_active'] == 1,
        'created_at': row['created_at'],
      };

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
      'image_url': row['image_url'],
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
      'SELECT status, note, created_at FROM order_events WHERE order_id = ? '
      'ORDER BY created_at',
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
      'SELECT name, phone FROM users WHERE id = ?',
      [order['customer_id']],
    ).first;

    return {
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
        'id': establishment['id'],
        'name': establishment['name'],
        'slug': establishment['slug'],
        'address': establishment['address'],
        'phone': establishment['phone'],
        'category_id': establishment['category_id'],
        'delivery_fee_cents': establishment['delivery_fee_cents'],
      },
      'customer': {
        'name': customer['name'],
        'phone': includeCustomer ? customer['phone'] : null,
      },
      'items': [
        for (final item in items)
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
        for (final event in events)
          {
            'status': event['status'],
            'note': event['note'],
            'created_at': event['created_at'],
          },
      ],
      'delivery': assignments.isEmpty
          ? null
          : {
              'id': assignments.first['id'],
              'status': assignments.first['status'],
              'courier_name': assignments.first['courier_name'],
              'courier_phone':
                  includeCourier ? assignments.first['courier_phone'] : null,
              'accepted_at': assignments.first['accepted_at'],
              'departed_at': assignments.first['departed_at'],
              'completed_at': assignments.first['completed_at'],
              if (includeTracking &&
                  order['status'] == 'on_the_way' &&
                  assignments.first['latitude'] != null &&
                  assignments.first['longitude'] != null) ...{
                'latitude': assignments.first['latitude'],
                'longitude': assignments.first['longitude'],
                'location_updated_at': assignments.first['location_updated_at'],
              },
            },
    };
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

    final digest = hashPassword(password);
    final id = newId();
    db.execute(
      '''
      INSERT INTO users (id, role, name, email, phone, password_hash,
        password_salt, token_version, is_active, created_at)
      VALUES (?, 'customer', ?, ?, ?, ?, ?, 0, 1, ?)
      ''',
      [id, name, email, phone, digest.hash, digest.salt, nowIso()],
    );
    final user = db.select('SELECT * FROM users WHERE id = ?', [id]).first;
    return jsonResponse(authResponse(user), status: 201);
  }

  Future<Response> _login(Request request) async {
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
    if (rows.isEmpty ||
        !verifyPassword(
          password,
          rows.first['password_hash'] as String,
          rows.first['password_salt'] as String,
        )) {
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
    db.execute('UPDATE users SET name = ?, phone = ? WHERE id = ?', [
      name,
      phone,
      user.id,
    ]);
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
    if (!verifyPassword(
      current,
      row['password_hash'] as String,
      row['password_salt'] as String,
    )) {
      throw ApiError(
          422, 'wrong_password', 'A palavra-passe atual não confere.');
    }
    final digest = hashPassword(next);
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
    final rows = db.select(
      '$_establishmentSelect WHERE ${where.join(' AND ')} ORDER BY $sort',
      args,
    );
    return jsonResponse({
      'establishments': [for (final row in rows) establishmentJson(row)],
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
    if (!['mpesa', 'emola', 'cash'].contains(payment)) {
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
        'ORDER BY created_at DESC LIMIT 100';
    final rows = db.select(sql, args);
    return jsonResponse({
      'orders': [
        for (final row in rows)
          orderJson(
            Map<String, dynamic>.from(row),
            includeCustomer: !user.isCustomer,
            includeCourier: user.isCustomer || user.isAdmin,
          ),
      ],
    });
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
    final user = requireRole(request, ['partner']);
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
      'recent_orders': [
        for (final row in recent)
          orderJson(Map<String, dynamic>.from(row), includeCustomer: true),
      ],
    });
  }

  Future<Response> _partnerOrders(Request request) async {
    final user = requireRole(request, ['partner']);
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
    final rows = db.select(
      'SELECT * FROM orders WHERE ${where.join(' AND ')} '
      'ORDER BY created_at DESC LIMIT 100',
      args,
    );
    return jsonResponse({
      'orders': [
        for (final row in rows)
          orderJson(Map<String, dynamic>.from(row), includeCustomer: true),
      ],
    });
  }

  Future<Response> _partnerTransition(
    Request request,
    String id,
    String action,
  ) async {
    final user = requireRole(request, ['partner']);
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
    final user = requireRole(request, ['partner']);
    final establishment = requirePartnerEstablishment(user);
    final rows = db.select(
      'SELECT * FROM products WHERE establishment_id = ? ORDER BY category, name',
      [establishment['id']],
    );
    return jsonResponse({
      'products': [for (final row in rows) productJson(row)],
    });
  }

  Future<Response> _partnerCreateProduct(Request request) async {
    final user = requireRole(request, ['partner']);
    final establishment = requirePartnerEstablishment(user);
    final body = await readBody(request);
    final name = requiredString(body, 'name', min: 2, max: 120, label: 'nome');
    final description = (body['description'] as String?)?.trim() ?? '';
    final price = intValue(body['price_cents'], min: 1, max: 100000000);
    final category = (body['category'] as String?)?.trim() ?? 'Geral';
    final available = body['is_available'] != false;
    final stock =
        body['stock'] == null ? null : intValue(body['stock'], min: 0);
    final id = newId();
    final timestamp = nowIso();
    db.execute(
      '''
      INSERT INTO products (id, establishment_id, name, description,
        price_cents, category, stock, is_available, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        establishment['id'],
        name,
        description,
        price,
        category,
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
    final user = requireRole(request, ['partner']);
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
    db.execute(
      'UPDATE products SET name = ?, description = ?, price_cents = ?, '
      'category = ?, stock = ?, is_available = ?, updated_at = ? WHERE id = ?',
      [
        name,
        description,
        price,
        category,
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

  Future<Response> _partnerDeleteProduct(Request request, String id) async {
    final user = requireRole(request, ['partner']);
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
    final user = requireRole(request, ['partner']);
    final establishment = requirePartnerEstablishment(user);
    final row = db.select(
      '$_establishmentSelect WHERE e.id = ?',
      [establishment['id']],
    ).first;
    return jsonResponse({'establishment': establishmentJson(row)});
  }

  Future<Response> _partnerUpdateEstablishment(Request request) async {
    final user = requireRole(request, ['partner']);
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
    db.execute(
      'UPDATE establishments SET description = ?, phone = ?, address = ?, '
      'is_open = ?, opens_at = ?, closes_at = ? WHERE id = ?',
      [
        description,
        phone,
        address,
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
    final user = requireRole(request, ['delivery']);
    final rows = db.select(
      '''
      SELECT d.*, o.number, o.status AS order_status, o.total_cents,
        o.address_line, o.address_label, o.phone AS customer_phone,
        o.address_latitude, o.address_longitude, o.note,
        e.name AS establishment_name, e.address AS establishment_address,
        e.phone AS establishment_phone
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
            'created_at': row['created_at'],
          },
      ],
    });
  }

  Future<Response> _deliveryHistory(Request request) async {
    final user = requireRole(request, ['delivery']);
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
    final user = requireRole(request, ['delivery']);
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
    final user = requireRole(request, ['delivery']);
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
    final user = requireRole(request, ['delivery']);
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
    final user = requireRole(request, ['delivery']);
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
    final user = requireRole(request, ['delivery']);
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
      'recent_orders': [
        for (final row in recent)
          orderJson(Map<String, dynamic>.from(row), includeCustomer: true),
      ],
      'pending_partners': [
        for (final row in pending) establishmentJson(row),
      ],
    });
  }

  Future<Response> _adminPartners(Request request) async {
    requireRole(request, ['admin']);
    final rows = db.select(
      '$_establishmentSelect ORDER BY e.is_approved, e.name',
    );
    return jsonResponse({
      'partners': [for (final row in rows) establishmentJson(row)],
    });
  }

  /// Registo de um parceiro real pela administração: cria a conta de acesso
  /// (papel `partner`) e o estabelecimento aprovado numa única transação.
  Future<Response> _adminCreatePartner(Request request) async {
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
          description, phone, address, delivery_fee_cents, prep_minutes,
          opens_at, closes_at, is_open, is_approved, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, ?)
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
          fee,
          prep,
          opensAt,
          closesAt,
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
    final user = requireRole(request, ['admin']);
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
    final user = requireRole(request, ['admin']);
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
    requireRole(request, ['admin']);
    final role = request.url.queryParameters['role'];
    final rows = role == null || role.isEmpty
        ? db.select('SELECT * FROM users ORDER BY created_at DESC')
        : db.select(
            'SELECT * FROM users WHERE role = ? ORDER BY created_at DESC',
            [role],
          );
    return jsonResponse({
      'users': [for (final row in rows) userJson(row)],
    });
  }

  Future<Response> _adminUpdateUser(Request request, String id) async {
    final actor = requireRole(request, ['admin']);
    final rows = db.select('SELECT * FROM users WHERE id = ?', [id]);
    if (rows.isEmpty) {
      throw ApiError(404, 'not_found', 'Utilizador não encontrado.');
    }
    final body = await readBody(request);
    if (body.containsKey('role')) {
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
    requireRole(request, ['admin']);
    final status = request.url.queryParameters['status'];
    final rows = status == null || status.isEmpty || status == 'all'
        ? db.select('SELECT * FROM orders ORDER BY created_at DESC LIMIT 200')
        : db.select(
            'SELECT * FROM orders WHERE status = ? ORDER BY created_at DESC '
            'LIMIT 200',
            [status],
          );
    return jsonResponse({
      'orders': [
        for (final row in rows)
          orderJson(Map<String, dynamic>.from(row), includeCustomer: true),
      ],
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
    final user = requireRole(request, ['admin']);
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
    db.execute(
      'INSERT INTO categories (id, name, slug, icon, sort_order) '
      'VALUES (?, ?, ?, ?, ?)',
      [id, name, slug, icon, 99],
    );
    audit(user.id, 'category.created', 'category', id, {'name': name});
    return jsonResponse(
      {
        'category': {'id': id, 'name': name, 'slug': slug, 'icon': icon}
      },
      status: 201,
    );
  }

  Future<Response> _adminUpdateCategory(Request request, String id) async {
    final user = requireRole(request, ['admin']);
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
    db.execute(
      'UPDATE categories SET name = ?, icon = ? WHERE id = ?',
      [name, icon, id],
    );
    audit(user.id, 'category.updated', 'category', id);
    return jsonResponse({'ok': true});
  }

  Future<Response> _adminDeleteCategory(Request request, String id) async {
    final user = requireRole(request, ['admin']);
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
}

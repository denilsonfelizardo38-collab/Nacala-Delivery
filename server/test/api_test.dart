import 'dart:convert';
import 'dart:io';

import 'package:nacala_server/nacala_server.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

late Database db;
late Api api;
late Directory imageDirectory;

Future<(int, Map<String, dynamic>)> call(
  String method,
  String path, {
  Object? body,
  String? token,
}) async {
  final request = Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {
      if (body != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    },
    body: body == null ? null : jsonEncode(body),
  );
  final response = await api.handler(request);
  final text = await response.readAsString();
  final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
  return (response.statusCode, decoded as Map<String, dynamic>);
}

Future<String> login(String identifier, String password) async {
  final (status, json) = await call(
    'POST',
    '/api/auth/login',
    body: {'identifier': identifier, 'password': password},
  );
  expect(status, 200, reason: '$json');
  return json['token'] as String;
}

void main() {
  setUpAll(() async {
    db = openDatabase(':memory:', demoSeed: true);
    imageDirectory = await Directory.systemTemp.createTemp('nacala-images-');
    api = Api(
      db: db,
      jwt: JwtService('test-secret'),
      imageDirectory: imageDirectory,
    );
  });

  tearDownAll(() async {
    db.dispose();
    await imageDirectory.delete(recursive: true);
  });

  test('catálogo público devolve categorias e estabelecimentos', () async {
    final (status, json) = await call('GET', '/api/categories');
    expect(status, 200);
    expect((json['categories'] as List).length, 8);

    final (listStatus, list) = await call(
      'GET',
      '/api/establishments?category=restaurantes&q=baia',
    );
    expect(listStatus, 200);
    final establishments = list['establishments'] as List;
    expect(establishments.length, 1);
    expect(establishments.first['name'], 'Cantinho da Baía');
    expect(establishments.first['delivery_fee_cents'], 8000);
  });

  test('pesquisa encontra produtos e estabelecimentos', () async {
    final (status, json) = await call('GET', '/api/search?q=frango');
    expect(status, 200);
    expect((json['products'] as List).isNotEmpty, isTrue);
    expect(
      (json['products'] as List).first['establishment_name'],
      'Cantinho da Baía',
    );
  });

  test('registo valida telefone e impede duplicados', () async {
    final (badStatus, bad) = await call(
      'POST',
      '/api/auth/register',
      body: {
        'name': 'Teste',
        'email': 'teste@nacala.co.mz',
        'phone': '123',
        'password': 'Segura123',
      },
    );
    expect(badStatus, 422);
    expect(bad['error']['code'], 'invalid_phone');

    final payload = {
      'name': 'Ana Teste',
      'email': 'ana@nacala.co.mz',
      'phone': '845555555',
      'password': 'Segura123',
    };
    final (status, json) = await call(
      'POST',
      '/api/auth/register',
      body: payload,
    );
    expect(status, 201);
    expect(json['user']['role'], 'customer');
    expect(json['token'], isNotEmpty);

    final (duplicateStatus, duplicate) = await call(
      'POST',
      '/api/auth/register',
      body: payload,
    );
    expect(duplicateStatus, 409);
    expect(duplicate['error']['code'], 'already_registered');
  });

  test('login rejeita palavra-passe errada', () async {
    final (status, json) = await call(
      'POST',
      '/api/auth/login',
      body: {'identifier': 'cliente@nacala.co.mz', 'password': 'errada123'},
    );
    expect(status, 401);
    expect(json['error']['code'], 'invalid_credentials');
  });

  test('cliente não acede a rotas de administração', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, json) =
        await call('GET', '/api/admin/summary', token: token);
    expect(status, 403);
    expect(json['error']['code'], 'forbidden');

    final (partnerStatus, _) = await call(
      'GET',
      '/api/partner/products',
      token: token,
    );
    expect(partnerStatus, 403);
  });

  test('moradas guardam coordenadas e rejeitam pontos inválidos', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, json) = await call(
      'POST',
      '/api/addresses',
      token: token,
      body: {
        'label': 'Casa',
        'line': 'Bairro Central, Rua 12',
        'latitude': -14.5428,
        'longitude': 40.6729,
      },
    );
    expect(status, 201, reason: '$json');
    expect(json['address']['latitude'], -14.5428);
    expect(json['address']['longitude'], 40.6729);

    final (invalidStatus, invalid) = await call(
      'PATCH',
      '/api/addresses/${json['address']['id']}',
      token: token,
      body: {'latitude': 200, 'longitude': 40.6729},
    );
    expect(invalidStatus, 422);
    expect(invalid['error']['code'], 'invalid_coordinates');
  });

  test('pedido calcula totais no servidor e guarda snapshot', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, json) = await call(
      'POST',
      '/api/orders',
      token: token,
      body: {
        'establishment_id': 'est_cantinho',
        'address_line': 'Bairro Central, Rua 12, casa 34',
        'address_label': 'Casa',
        'phone': '841111111',
        'payment_method': 'mpesa',
        // Preço adulterado pelo cliente: deve ser ignorado.
        'items': [
          {'product_id': 'prd_cb_frango', 'quantity': 2, 'price_cents': 1},
        ],
      },
    );
    expect(status, 201, reason: '$json');
    final order = json['order'] as Map<String, dynamic>;
    expect(order['subtotal_cents'], 90000);
    expect(order['delivery_fee_cents'], 8000);
    expect(order['total_cents'], 98000);
    expect(order['payment_status'], 'pending_integration');
    expect(order['items'][0]['name'], 'Frango grelhado');
    expect(order['items'][0]['unit_price_cents'], 45000);

    final (listStatus, list) = await call(
      'GET',
      '/api/orders',
      token: token,
    );
    expect(listStatus, 200);
    expect(
      (list['orders'] as List).any((o) => o['id'] == order['id']),
      isTrue,
    );
  });

  test('cupão aplica desconto validado', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, json) = await call(
      'POST',
      '/api/orders',
      token: token,
      body: {
        'establishment_id': 'est_cantinho',
        'address_line': 'Bairro Central, Rua 12, casa 34',
        'phone': '841111111',
        'payment_method': 'cash',
        'coupon_code': 'BEMVINDO10',
        'items': [
          {'product_id': 'prd_cb_caril', 'quantity': 1},
        ],
      },
    );
    expect(status, 201, reason: '$json');
    final order = json['order'] as Map<String, dynamic>;
    expect(order['discount_cents'], 6200);
    expect(order['total_cents'], 62000 + 8000 - 6200);
    expect(order['payment_status'], 'cash_on_delivery');
  });

  test('produto indisponível impede o pedido', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, json) = await call(
      'POST',
      '/api/orders',
      token: token,
      body: {
        'establishment_id': 'est_cantinho',
        'address_line': 'Bairro Central, Rua 12, casa 34',
        'phone': '841111111',
        'payment_method': 'cash',
        'items': [
          {'product_id': 'prd_cb_sobremesa', 'quantity': 1},
        ],
      },
    );
    expect(status, 409);
    expect(json['error']['code'], 'product_unavailable');
  });

  test('fluxo parceiro e estafeta altera o estado do pedido', () async {
    final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final partner = await login('cantinho@nacala.co.mz', 'Parceiro@1234');
    final courier = await login('estafeta@nacala.co.mz', 'Estafeta@1234');

    final (_, created) = await call(
      'POST',
      '/api/orders',
      token: customer,
      body: {
        'establishment_id': 'est_cantinho',
        'address_line': 'Bairro Central, Rua 12, casa 34',
        'address_latitude': -14.5428,
        'address_longitude': 40.6729,
        'phone': '841111111',
        'payment_method': 'cash',
        'items': [
          {'product_id': 'prd_cb_sumo', 'quantity': 1},
        ],
      },
    );
    final orderId = created['order']['id'] as String;

    final (acceptStatus, accepted) = await call(
      'POST',
      '/api/partner/orders/$orderId/accept',
      token: partner,
    );
    expect(acceptStatus, 200, reason: '$accepted');
    expect(accepted['order']['status'], 'confirmed');

    final (prepStatus, prepared) = await call(
      'POST',
      '/api/partner/orders/$orderId/preparing',
      token: partner,
    );
    expect(prepStatus, 200, reason: '$prepared');
    expect(prepared['order']['status'], 'preparing');

    final (readyStatus, ready) = await call(
      'POST',
      '/api/partner/orders/$orderId/ready',
      token: partner,
    );
    expect(readyStatus, 200, reason: '$ready');
    expect(ready['order']['status'], 'ready');

    final (assignStatus, assignments) = await call(
      'GET',
      '/api/delivery/assignments',
      token: courier,
    );
    expect(assignStatus, 200);
    final assignment = (assignments['assignments'] as List).firstWhere(
      (a) => a['order_id'] == orderId,
    );

    final (courierStatus, courierJson) = await call(
      'POST',
      '/api/delivery/assignments/${assignment['id']}/accept',
      token: courier,
    );
    expect(courierStatus, 200, reason: '$courierJson');
    expect(courierJson['order']['status'], 'ready');

    final (startStatus, started) = await call(
      'POST',
      '/api/delivery/assignments/${assignment['id']}/start',
      token: courier,
    );
    expect(startStatus, 200, reason: '$started');
    expect(started['order']['status'], 'on_the_way');
    expect(started['order']['delivery']['departed_at'], isNotNull);

    final (invalidLocationStatus, invalidLocation) = await call(
      'POST',
      '/api/delivery/assignments/${assignment['id']}/location',
      token: courier,
      body: {'latitude': 91, 'longitude': 40.67},
    );
    expect(invalidLocationStatus, 422);
    expect(invalidLocation['error']['code'], 'invalid_coordinates');

    final (locationStatus, location) = await call(
      'POST',
      '/api/delivery/assignments/${assignment['id']}/location',
      token: courier,
      body: {'latitude': -14.54, 'longitude': 40.67},
    );
    expect(locationStatus, 200, reason: '$location');
    final (trackingStatus, tracking) = await call(
      'GET',
      '/api/orders/$orderId',
      token: customer,
    );
    expect(trackingStatus, 200);
    expect(tracking['order']['address_latitude'], -14.5428);
    expect(tracking['order']['delivery']['latitude'], -14.54);
    expect(tracking['order']['delivery']['longitude'], 40.67);

    final (doneStatus, _) = await call(
      'POST',
      '/api/delivery/assignments/${assignment['id']}/complete',
      token: courier,
    );
    expect(doneStatus, 200);

    final (orderStatus, orderJson) = await call(
      'GET',
      '/api/orders/$orderId',
      token: customer,
    );
    expect(orderStatus, 200);
    expect(orderJson['order']['status'], 'delivered');
    expect(orderJson['order'].containsKey('address_latitude'), isFalse);
    expect(orderJson['order']['delivery'].containsKey('latitude'), isFalse);

    // Cliente pode avaliar; segunda avaliação é rejeitada.
    final (reviewStatus, _) = await call(
      'POST',
      '/api/orders/$orderId/review',
      token: customer,
      body: {'rating': 5, 'comment': 'Excelente'},
    );
    expect(reviewStatus, 201);
    final (againStatus, _) = await call(
      'POST',
      '/api/orders/$orderId/review',
      token: customer,
      body: {'rating': 4},
    );
    expect(againStatus, 409);
  });

  test('parceiro não gere produtos de outro estabelecimento', () async {
    final partner = await login('mercado@nacala.co.mz', 'Parceiro@1234');
    final (status, json) = await call(
      'PATCH',
      '/api/partner/products/prd_cb_frango',
      token: partner,
      body: {'price_cents': 100},
    );
    expect(status, 404);
    expect(json['error']['code'], 'not_found');
  });

  test('parceiro cria e atualiza produto com validação', () async {
    final partner = await login('mercado@nacala.co.mz', 'Parceiro@1234');
    final (badStatus, _) = await call(
      'POST',
      '/api/partner/products',
      token: partner,
      body: {'name': 'X', 'price_cents': 0},
    );
    expect(badStatus, 422);

    final (status, json) = await call(
      'POST',
      '/api/partner/products',
      token: partner,
      body: {
        'name': 'Feijão 1 kg',
        'description': 'Feijão manteiga',
        'price_cents': 21000,
        'category': 'Mercearia',
        'image_url': 'https://images.example.test/feijao.jpg',
        'stock': 12,
      },
    );
    expect(status, 201, reason: '$json');
    final productId = json['product']['id'] as String;
    expect(
      json['product']['image_url'],
      'https://images.example.test/feijao.jpg',
    );

    final (patchStatus, patched) = await call(
      'PATCH',
      '/api/partner/products/$productId',
      token: partner,
      body: {
        'price_cents': 22500,
        'is_available': false,
        'image_url': 'https://images.example.test/feijao-updated.jpg',
      },
    );
    expect(patchStatus, 200);
    expect(patched['product']['price_cents'], 22500);
    expect(patched['product']['is_available'], isFalse);
    expect(
      patched['product']['image_url'],
      'https://images.example.test/feijao-updated.jpg',
    );

    final (invalidImageStatus, invalidImage) = await call(
      'PATCH',
      '/api/partner/products/$productId',
      token: partner,
      body: {'image_url': 'http://images.example.test/insecure.jpg'},
    );
    expect(invalidImageStatus, 422);
    expect(invalidImage['error']['code'], 'invalid_image_url');
  });

  test('parceiro carrega imagem de produto com validação de formato', () async {
    final partner = await login('mercado@nacala.co.mz', 'Parceiro@1234');
    final imageBytes = [0xff, 0xd8, 0xff, 0xd9];
    final (status, json) = await call(
      'POST',
      '/api/partner/product-images',
      token: partner,
      body: {
        'mime_type': 'image/jpeg',
        'data_base64': base64Encode(imageBytes),
      },
    );
    expect(status, 201, reason: '$json');
    final imagePath = Uri.parse(json['image_url'] as String).path;
    expect(imagePath, matches(RegExp(r'^/uploads/[a-f0-9]{32}\.jpg$')));

    final response = await api.handler(
      Request('GET', Uri.parse('http://localhost$imagePath')),
    );
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'image/jpeg');
    expect(await response.read().expand((chunk) => chunk).toList(), imageBytes);

    final (productStatus, productJson) = await call(
      'POST',
      '/api/partner/products',
      token: partner,
      body: {
        'name': 'Produto com fotografia',
        'price_cents': 1000,
        'image_url': 'http://localhost$imagePath',
      },
    );
    expect(productStatus, 201, reason: '$productJson');
    expect(productJson['product']['image_url'], 'http://localhost$imagePath');

    final (invalidStatus, invalid) = await call(
      'POST',
      '/api/partner/product-images',
      token: partner,
      body: {
        'mime_type': 'image/jpeg',
        'data_base64': base64Encode([1, 2, 3]),
      },
    );
    expect(invalidStatus, 422);
    expect(invalid['error']['code'], 'invalid_image');
  });

  test('cliente não vê pedidos de outra conta', () async {
    final ana = await login('ana@nacala.co.mz', 'Segura123');
    final (status, _) = await call('GET', '/api/orders/ord_hist_1', token: ana);
    expect(status, 403);
  });

  test('administração registra um parceiro real', () async {
    final admin = await login('admin@nacala.co.mz', 'Admin@1234');
    final (status, json) = await call(
      'POST',
      '/api/admin/partners',
      token: admin,
      body: {
        'name': 'Gestor Teste',
        'email': 'novo.parceiro@nacala.co.mz',
        'phone': '846666666',
        'password': 'Parceiro123',
        'establishment_name': 'Loja Nova',
        'category_id': 'cat_lojas',
        'description': 'Artigos para casa',
        'address': 'Bairro Central, Nacala-Porto',
        'delivery_fee_cents': 7500,
        'prep_minutes': 25,
        'opens_at': '08:00',
        'closes_at': '20:00',
      },
    );
    expect(status, 201, reason: '$json');
    expect(json['establishment']['name'], 'Loja Nova');
    expect(json['establishment']['is_approved'], isTrue);
    expect(json['user']['role'], 'partner');

    // A conta criada consegue entrar e gerir o próprio estabelecimento.
    final partner = await login(
      'novo.parceiro@nacala.co.mz',
      'Parceiro123',
    );
    final (summaryStatus, summary) = await call(
      'GET',
      '/api/partner/summary',
      token: partner,
    );
    expect(summaryStatus, 200, reason: '$summary');

    final (listStatus, list) = await call(
      'GET',
      '/api/establishments?category=lojas',
    );
    expect(listStatus, 200);
    expect(
      (list['establishments'] as List).any((e) => e['name'] == 'Loja Nova'),
      isTrue,
    );
  });

  test('apenas administração registra parceiros', () async {
    final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, _) = await call(
      'POST',
      '/api/admin/partners',
      token: customer,
      body: {'name': 'X'},
    );
    expect(status, 403);
  });

  test('administração obtém métricas reais e audita alterações', () async {
    final admin = await login('admin@nacala.co.mz', 'Admin@1234');
    final (status, json) =
        await call('GET', '/api/admin/summary', token: admin);
    expect(status, 200);
    final summary = json['summary'] as Map<String, dynamic>;
    expect(summary['customers'], greaterThanOrEqualTo(2));
    expect(summary['total_orders'], greaterThanOrEqualTo(4));

    final (usersStatus, users) = await call(
      'GET',
      '/api/admin/users?role=customer',
      token: admin,
    );
    expect(usersStatus, 200);
    expect((users['users'] as List).length, greaterThanOrEqualTo(2));

    final (auditStatus, audit) = await call(
      'GET',
      '/api/admin/audit',
      token: admin,
    );
    expect(auditStatus, 200);
    expect((audit['logs'] as List).isNotEmpty, isTrue);
  });

  test('favoritos alternam (add/remove) e exigem sessão', () async {
    final (anonStatus, _) = await call('GET', '/api/favorites');
    expect(anonStatus, 401);

    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');

    final (addStatus, _) =
        await call('POST', '/api/favorites/est_cantinho', token: token);
    expect(addStatus, 201);
    final (add2Status, _) =
        await call('POST', '/api/favorites/est_cantinho', token: token);
    expect(add2Status, 201);

    final (listStatus, list) =
        await call('GET', '/api/favorites', token: token);
    expect(listStatus, 200);
    expect((list['establishments'] as List).length, 1);
    expect(
      (list['establishments'] as List).first['id'],
      'est_cantinho',
    );

    final (missingStatus, _) =
        await call('POST', '/api/favorites/est_inexistente', token: token);
    expect(missingStatus, 404);

    final (delStatus, _) =
        await call('DELETE', '/api/favorites/est_cantinho', token: token);
    expect(delStatus, 200);
    final (emptyStatus, empty) =
        await call('GET', '/api/favorites', token: token);
    expect(emptyStatus, 200);
    expect((empty['establishments'] as List).isEmpty, isTrue);
  });

  test('perfil atualiza email e rejeita duplicados', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');

    final (status, json) = await call(
      'PATCH',
      '/api/auth/profile',
      token: token,
      body: {
        'name': 'Cliente Demonstração',
        'phone': '841111111',
        'email': 'cliente@nacala.co.mz',
      },
    );
    expect(status, 200, reason: '$json');

    final (dupStatus, dup) = await call(
      'PATCH',
      '/api/auth/profile',
      token: token,
      body: {
        'name': 'Cliente Demonstração',
        'phone': '841111111',
        'email': 'admin@nacala.co.mz',
      },
    );
    expect(dupStatus, 409);
    expect(dup['error']['code'], 'email_taken');
  });

  test('avatar autenticado é aceite e devolvido no /api/auth/me', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    // PNG mínimo válido (apenas assinatura + alguns bytes).
    final png = base64Encode([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    ]);

    final (status, json) = await call(
      'POST',
      '/api/auth/avatar',
      token: token,
      body: {'mime_type': 'image/png', 'data_base64': png},
    );
    expect(status, 201, reason: '$json');
    final imageUrl = json['image_url'] as String;
    expect(imageUrl, startsWith('/uploads/'));

    final (meStatus, me) = await call('GET', '/api/auth/me', token: token);
    expect(meStatus, 200);
    expect(me['user']['avatar_url'], imageUrl);
  });

  test('logout invalida o token anterior', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, _) = await call('POST', '/api/auth/logout', token: token);
    expect(status, 200);
    final (meStatus, _) = await call('GET', '/api/auth/me', token: token);
    expect(meStatus, 401);
  });
}

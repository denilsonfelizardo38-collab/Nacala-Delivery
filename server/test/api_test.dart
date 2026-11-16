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

/// PNG de 1×1 (assinatura válida) usado como fotografia de teste.
const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQ'
    'GAhKmMIQAAAABJRU5ErkJggg==';

/// Carrega uma imagem pelo endpoint público de candidaturas e devolve o
/// caminho `/uploads/…` guardado.
Future<String> uploadApplicationImage() async {
  final (status, json) = await call(
    'POST',
    '/api/applications/images',
    body: {'mime_type': 'image/png', 'data_base64': _tinyPng},
  );
  expect(status, 201, reason: '$json');
  return json['image_url'] as String;
}

/// Documentos obrigatórios de um candidato a entregador: selfie, B.I
/// (frente e verso) e carta de condução.
Future<Map<String, String>> courierDocuments() async => {
      'selfie': await uploadApplicationImage(),
      'bi_front': await uploadApplicationImage(),
      'bi_back': await uploadApplicationImage(),
      'license': await uploadApplicationImage(),
    };

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

  test('mKesh é aceite como método de pagamento e não devolve 500', () async {
    final token = await login('cliente@nacala.co.mz', 'Cliente@1234');
    final (status, json) = await call(
      'POST',
      '/api/orders',
      token: token,
      body: {
        'establishment_id': 'est_cantinho',
        'address_line': 'Bairro Central, Rua 12, casa 34',
        'phone': '841111111',
        'payment_method': 'mkesh',
        'items': [
          {'product_id': 'prd_cb_frango', 'quantity': 1},
        ],
      },
    );
    expect(status, 201, reason: '$json');
    final order = json['order'] as Map<String, dynamic>;
    expect(order['payment_method'], 'mkesh');
    expect(order['payment_status'], 'pending_integration');
  });

  test('JSON malformado devolve 400 e não 500', () async {
    final request = Request(
      'POST',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {'content-type': 'application/json'},
      body: '{"identifier": "cliente@nacala.co.mz", "password": "quebrado',
    );
    final response = await api.handler(request);
    expect(response.statusCode, 400);
    final json = jsonDecode(await response.readAsString());
    expect(json['error']['code'], 'invalid_body');
  });

  test('corpo de JSON excessivo devolve 413', () async {
    final request = Request(
      'POST',
      Uri.parse('http://localhost/api/auth/login'),
      headers: {'content-type': 'application/json'},
      body: '{"pad": "${'x' * (1024 * 1024 + 1024)}"}',
    );
    final response = await api.handler(request);
    expect(response.statusCode, 413);
    final json = jsonDecode(await response.readAsString());
    expect(json['error']['code'], 'body_too_large');
  });

  test('login trava força-bruta: 10 falhas de login devolvem 429', () async {
    // Instância dedicada: os buckets de limitação pertencem ao objeto Api.
    final limitedApi = Api(
      db: db,
      jwt: JwtService('test-secret'),
      imageDirectory: imageDirectory,
    );
    Future<(int, Map<String, dynamic>)> attempt() async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(
          {'identifier': 'cliente@nacala.co.mz', 'password': 'Errada123'},
        ),
      );
      final response = await limitedApi.handler(request);
      return (
        response.statusCode,
        jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      );
    }

    for (var i = 0; i < 10; i++) {
      final (status, _) = await attempt();
      expect(status, 401, reason: 'tentativa $i deveria falhar com 401');
    }
    final (blocked, json) = await attempt();
    expect(blocked, 429, reason: '$json');
    expect(json['error']['code'], 'rate_limited');
  });

  test('saúde /health responde ok com a base de dados viva', () async {
    final (status, json) = await call('GET', '/health');
    expect(status, 200);
    expect(json['status'], 'ok');
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
        'nuit': '400077889',
        'image_url': await uploadApplicationImage(),
      },
    );
    expect(status, 201, reason: '$json');
    expect(json['establishment']['name'], 'Loja Nova');
    expect(json['establishment']['is_approved'], isTrue);
    expect(json['establishment']['nuit'], '400077889');
    expect(
      json['establishment']['image_url'],
      startsWith('/uploads/'),
      reason: 'a foto vem do upload, não de um link externo',
    );
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
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
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

  test('administrador elimina estabelecimento e conteúdo associado', () async {
    final admin = await login('admin@nacala.co.mz', 'Admin@1234');

    final (_, list) = await call('GET', '/api/establishments');
    final establishments = list['establishments'] as List;
    expect(establishments, isNotEmpty);
    final targetId = establishments.first['id'] as String;
    final categorySlug = establishments.first['category_slug'] as String;

    final (_, products) =
        await call('GET', '/api/establishments/$targetId/products');
    expect(products['products'], isNotEmpty);

    final (status, json) = await call(
        'DELETE', '/api/admin/establishments/$targetId',
        token: admin);
    expect(status, 200, reason: '$json');
    expect(json['ok'], true);
    expect(json['removed_orders'], isA<int>());

    final (goneStatus, _) = await call('GET', '/api/establishments/$targetId');
    expect(goneStatus, 404);

    final (_, after) =
        await call('GET', '/api/establishments?category=$categorySlug');
    expect(
      (after['establishments'] as List).any((e) => e['id'] == targetId),
      isFalse,
    );
  });

  test('eliminação de utilizador protege o próprio admin', () async {
    final admin = await login('admin@nacala.co.mz', 'Admin@1234');
    final (_, me) = await call('GET', '/api/auth/me', token: admin);
    final adminId = me['user']['id'] as String;

    final (selfStatus, self) =
        await call('DELETE', '/api/admin/users/$adminId', token: admin);
    expect(selfStatus, 409);
    expect(self['error']['code'], 'self_delete');
  });

  test('administrador pode eliminar conta de parceiro sem encomendas',
      () async {
    final admin = await login('admin@nacala.co.mz', 'Admin@1234');
    final (_, users) = await call('GET', '/api/admin/users', token: admin);
    final partner = (users['users'] as List)
        .singleWhere((u) => u['email'] == 'cantinho@nacala.co.mz');

    final (status, json) =
        await call('DELETE', '/api/admin/users/${partner['id']}', token: admin);
    expect(status, 200, reason: '$json');
    expect(json['ok'], true);

    final (_, after) = await call('GET', '/api/admin/users', token: admin);
    expect(
      (after['users'] as List)
          .any((u) => u['email'] == 'cantinho@nacala.co.mz'),
      isFalse,
    );
  });

  // ------------------------------------------------- FASE 4: recuperação
  group('registo de cliente e recuperação de palavra-passe', () {
    // O bucket de registo é 5 pedidos / 10 min por IP e conta tentativas
    // falhadas — cada teste recria a `Api` para zerar os contadores sem
    // interferir nos testes anteriores.
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    test('registo sem email usa endereço interno e devolve o código', () async {
      final (status, json) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'Cliente Sem Email',
          'phone': '846000001',
          'whatsapp': '847000001',
          'password': 'Segura123',
        },
      );
      expect(status, 201, reason: '$json');
      expect(
        json['user']['email'],
        '846000001@clientes.nacala.delivery',
        reason: 'sem email o servidor deriva um endereço estável ao telefone',
      );
      expect(json['user']['whatsapp'], '847000001');
      expect(
        json['recovery_code'],
        matches(RegExp(r'^[A-Z0-9]{5}-[A-Z0-9]{5}$')),
        reason: 'código devolvido uma única vez no registo',
      );

      // O whatsapp é exposto em /api/auth/me (userJson).
      final token = json['token'] as String;
      final (meStatus, me) = await call('GET', '/api/auth/me', token: token);
      expect(meStatus, 200);
      expect(me['user']['whatsapp'], '847000001');

      // Login com o telemóvel funciona mesmo sem email real.
      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '846000001', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
    });

    test('registo valida email e whatsapp opcionais', () async {
      final (badEmailStatus, badEmail) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'Email Errado',
          'email': 'nao-e-email',
          'phone': '843333333',
          'password': 'Segura123',
        },
      );
      expect(badEmailStatus, 422);
      expect(badEmail['error']['code'], 'invalid_email');

      final (badWaStatus, badWa) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'WhatsApp Errado',
          'phone': '843333334',
          'whatsapp': '999',
          'password': 'Segura123',
        },
      );
      expect(badWaStatus, 422);
      expect(badWa['error']['code'], 'invalid_whatsapp');

      // Email vazio é aceite (opcional) — igual a omitido.
      final (emptyStatus, empty) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'Email Vazio',
          'email': '',
          'phone': '843333335',
          'password': 'Segura123',
        },
      );
      expect(emptyStatus, 201, reason: '$empty');
      expect(empty['user']['email'], '843333335@clientes.nacala.delivery');
    });

    test('recuperação troca a palavra-passe e rota o código', () async {
      final (regStatus, reg) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'Recupera Cliente',
          'phone': '842000002',
          'password': 'Antiga123',
        },
      );
      expect(regStatus, 201, reason: '$reg');
      final code = reg['recovery_code'] as String;

      // Código errado → erro único, sem revelar se a conta existe.
      final (badStatus, bad) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '842000002',
          'code': 'AAAAA-AAAAA',
          'password': 'Nova1234',
        },
      );
      expect(badStatus, 422);
      expect(bad['error']['code'], 'invalid_recovery');

      // Identificador inexistente → mesma mensagem.
      final (missingStatus, missing) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '849999999',
          'code': code,
          'password': 'Nova1234',
        },
      );
      expect(missingStatus, 422);
      expect(missing['error']['code'], 'invalid_recovery');
      expect(missing['error']['message'], bad['error']['message']);

      // Código certo (aceita em minúsculas e sem traço) → nova sessão.
      final (okStatus, ok) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '842000002',
          'code': code.toLowerCase().replaceAll('-', ''),
          'password': 'Nova1234',
        },
      );
      expect(okStatus, 200, reason: '$ok');
      expect(ok['token'], isNotEmpty);
      expect(ok['recovery_code'], isNot(code), reason: 'código rotacionado');
      final rotated = ok['recovery_code'] as String;

      // A palavra-passe antiga deixa de servir; a nova entra.
      final (oldStatus, _) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '842000002', 'password': 'Antiga123'},
      );
      expect(oldStatus, 401);
      final (newStatus, newLogin) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '842000002', 'password': 'Nova1234'},
      );
      expect(newStatus, 200, reason: '$newLogin');

      // O código antigo já não vale; o rotacionado vale.
      final (replayStatus, _) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '842000002',
          'code': code,
          'password': 'Outra999',
        },
      );
      expect(replayStatus, 422);
      final (rotateStatus, rotate) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '842000002',
          'code': rotated,
          'password': 'Outra999',
        },
      );
      expect(rotateStatus, 200, reason: '$rotate');
      expect(rotate['recovery_code'], isNot(rotated));
    });

    test('conta autenticada regenera o código e invalida o anterior', () async {
      final (regStatus, reg) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'Regenera Cliente',
          'phone': '841231234',
          'password': 'Segura123',
        },
      );
      expect(regStatus, 201, reason: '$reg');
      final original = reg['recovery_code'] as String;
      final token = reg['token'] as String;

      final (genStatus, gen) = await call(
        'POST',
        '/api/auth/recovery-code',
        token: token,
      );
      expect(genStatus, 200, reason: '$gen');
      final regenerated = gen['recovery_code'] as String;
      expect(regenerated, isNot(original));

      // Exige sessão.
      final (anonStatus, _) = await call('POST', '/api/auth/recovery-code');
      expect(anonStatus, 401);

      // O original passou a valer; o novo vale.
      final (oldStatus, _) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '841231234',
          'code': original,
          'password': 'Nova1234',
        },
      );
      expect(oldStatus, 422);
      final (newStatus, newJson) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '841231234',
          'code': regenerated,
          'password': 'Nova1234',
        },
      );
      expect(newStatus, 200, reason: '$newJson');
    });

    test('recuperação limita tentativas erradas a 5 em 10 minutos', () async {
      final (regStatus, reg) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'Força Bruta',
          'phone': '849876543',
          'password': 'Segura123',
        },
      );
      expect(regStatus, 201, reason: '$reg');

      for (var attempt = 0; attempt < 5; attempt++) {
        final (status, _) = await call(
          'POST',
          '/api/auth/recover',
          body: {
            'identifier': '849876543',
            'code': 'BBBBB-BBBBB',
            'password': 'Nova1234',
          },
        );
        expect(status, 422, reason: 'tentativa ${attempt + 1} deve falhar');
      }
      final (blockedStatus, blocked) = await call(
        'POST',
        '/api/auth/recover',
        body: {
          'identifier': '849876543',
          'code': 'BBBBB-BBBBB',
          'password': 'Nova1234',
        },
      );
      expect(blockedStatus, 429);
      expect(blocked['error']['code'], 'rate_limited');
    });

    test('perfil atualiza e limpa o whatsapp com validação', () async {
      final (regStatus, reg) = await call(
        'POST',
        '/api/auth/register',
        body: {
          'name': 'WhatsApp Cliente',
          'phone': '845010203',
          'whatsapp': '845010204',
          'password': 'Segura123',
        },
      );
      expect(regStatus, 201, reason: '$reg');
      final token = reg['token'] as String;

      final (updStatus, upd) = await call(
        'PATCH',
        '/api/auth/profile',
        token: token,
        body: {
          'name': 'WhatsApp Cliente',
          'phone': '845010203',
          'whatsapp': '845010205',
        },
      );
      expect(updStatus, 200, reason: '$upd');
      expect(upd['user']['whatsapp'], '845010205');

      final (badStatus, bad) = await call(
        'PATCH',
        '/api/auth/profile',
        token: token,
        body: {
          'name': 'WhatsApp Cliente',
          'phone': '845010203',
          'whatsapp': 'abc',
        },
      );
      expect(badStatus, 422);
      expect(bad['error']['code'], 'invalid_whatsapp');

      // Chave omitida → mantém o valor.
      final (keepStatus, keep) = await call(
        'PATCH',
        '/api/auth/profile',
        token: token,
        body: {'name': 'WhatsApp Cliente', 'phone': '845010203'},
      );
      expect(keepStatus, 200, reason: '$keep');
      expect(keep['user']['whatsapp'], '845010205');

      // String vazia → limpa.
      final (clearStatus, clear) = await call(
        'PATCH',
        '/api/auth/profile',
        token: token,
        body: {
          'name': 'WhatsApp Cliente',
          'phone': '845010203',
          'whatsapp': '',
        },
      );
      expect(clearStatus, 200, reason: '$clear');
      expect(clear['user']['whatsapp'], isNull);
    });
  });
  // -------------------------------- FASE 5/7: candidaturas e aprovação
  group('candidaturas, aprovação e painéis bloqueados', () {
    // O bucket de candidaturas é 5 / 10 min por IP: cada teste recria a
    // `Api` para zerar os contadores (mesmo padrão do grupo anterior).
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    Future<(int, Map<String, dynamic>)> applyEstablishment({
      String phone = '845100001',
      String name = 'Nova Cantina',
      String email = '',
    }) async {
      final body = <String, dynamic>{
        'kind': 'establishment',
        'name': 'Dono da Cantina',
        'phone': phone,
        'password': 'Segura123',
        if (email.isNotEmpty) 'email': email,
        'payload': {
          'establishment_name': name,
          'category_id': 'cat_restaurantes',
          'address': 'Bairro Central, Nacala-Porto',
          'description': 'Comida caseira',
          'delivery_fee_cents': 15000,
          'prep_minutes': 25,
          'opens_at': '07:30',
          'closes_at': '22:00',
          'nuit': '400011223',
        },
      };
      return call('POST', '/api/applications', body: body);
    }

    test('candidatura cria conta pendente e bloqueia o painel', () async {
      final (status, json) = await applyEstablishment();
      expect(status, 201, reason: '$json');
      final application = json['application'] as Map<String, dynamic>;
      expect(application['status'], 'pending');
      expect(application['kind'], 'establishment');

      // A conta criada consegue entrar, mas o painel fica bloqueado.
      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100001', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      expect(loginJson['user']['role'], 'partner');
      expect(loginJson['user']['approval_status'], 'pending');
      final token = loginJson['token'] as String;

      // O candidato consulta o próprio estado.
      final (meStatus, me) = await call(
        'GET',
        '/api/applications/me',
        token: token,
      );
      expect(meStatus, 200, reason: '$me');
      expect(me['application']['status'], 'pending');

      // O painel do parceiro recusa enquanto pendente.
      final (blockedStatus, blocked) = await call(
        'GET',
        '/api/partner/summary',
        token: token,
      );
      expect(blockedStatus, 403);
      expect(blocked['error']['code'], 'pending_approval');

      // Administrador vê a candidatura com contagem.
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (listStatus, list) = await call(
        'GET',
        '/api/admin/applications?status=pending',
        token: admin,
      );
      expect(listStatus, 200, reason: '$list');
      expect(
        (list['applications'] as List)
            .any((a) => a['id'] == application['id']),
        isTrue,
      );
      expect(list['counts']['pending'], greaterThanOrEqualTo(1));

      // Novas candidaturas notificam os administradores (persistente).
      final (notifStatus, notifs) = await call(
        'GET',
        '/api/notifications',
        token: admin,
      );
      expect(notifStatus, 200, reason: '$notifs');
      expect(
        (notifs['notifications'] as List)
            .any((n) => n['kind'] == 'application_new'),
        isTrue,
      );
      expect(notifs['unread_count'], greaterThanOrEqualTo(1));

      // Aprovação: cria o estabelecimento, aprova a conta e destrava o painel.
      final (approveStatus, approve) = await call(
        'POST',
        '/api/admin/applications/${application['id']}/approve',
        token: admin,
        body: {'note': 'Dados validados.'},
      );
      expect(approveStatus, 200, reason: '$approve');
      expect(approve['application']['status'], 'approved');
      expect(approve['establishment_id'], isNotEmpty);

      final (afterLoginStatus, afterLogin) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100001', 'password': 'Segura123'},
      );
      expect(afterLoginStatus, 200, reason: '$afterLogin');
      expect(afterLogin['user']['approval_status'], 'approved');
      final afterToken = afterLogin['token'] as String;

      final (panelStatus, panel) = await call(
        'GET',
        '/api/partner/summary',
        token: afterToken,
      );
      expect(panelStatus, 200, reason: '$panel');

      // O estabelecimento aprovado aparece no catálogo público.
      final (_, establishments) = await call('GET', '/api/establishments');
      expect(
        (establishments['establishments'] as List)
            .any((e) => e['id'] == approve['establishment_id']),
        isTrue,
      );

      // A candidatura aprovada não pode ser reenviada.
      final (reapplyStatus, reapply) = await applyEstablishment();
      expect(reapplyStatus, 409);
      expect(reapply['error']['code'], 'already_registered');
    });

    test('recusa mantém a conta bloqueada e não deixa reenviar', () async {
      final (status, json) = await applyEstablishment(
        phone: '845100002',
        name: 'Cantina Recusada',
      );
      expect(status, 201, reason: '$json');
      final id = (json['application'] as Map<String, dynamic>)['id'] as String;
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      final (rejectStatus, reject) = await call(
        'POST',
        '/api/admin/applications/$id/reject',
        token: admin,
        body: {'note': 'Não atende aos requisitos.'},
      );
      expect(rejectStatus, 200, reason: '$reject');
      expect(reject['application']['status'], 'rejected');

      // A conta continua a entrar para ver o motivo, mas sem painel.
      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100002', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      expect(loginJson['user']['approval_status'], 'rejected');
      final (blockedStatus, _) = await call(
        'GET',
        '/api/partner/summary',
        token: loginJson['token'] as String,
      );
      expect(blockedStatus, 403);

      // Recusada: não se pode reenviar.
      final (reapplyStatus, reapply) = await applyEstablishment(
        phone: '845100002',
        name: 'Cantina Recusada',
      );
      expect(reapplyStatus, 409);
      expect(reapply['error']['code'], 'application_rejected');
    });

    test('correções exigem nota e reenvio autenticado do dono', () async {
      final (status, json) = await applyEstablishment(
        phone: '845100003',
        name: 'Cantina Corrigida',
      );
      expect(status, 201, reason: '$json');
      final id = (json['application'] as Map<String, dynamic>)['id'] as String;
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      // Sem nota não se pode pedir correções.
      final (noNoteStatus, noNote) = await call(
        'POST',
        '/api/admin/applications/$id/changes',
        token: admin,
        body: {},
      );
      expect(noNoteStatus, 422);
      expect(noNote['error']['code'], 'missing_note');

      final (changesStatus, changes) = await call(
        'POST',
        '/api/admin/applications/$id/changes',
        token: admin,
        body: {'note': 'Falta a coordenada no mapa.'},
      );
      expect(changesStatus, 200, reason: '$changes');
      expect(changes['application']['status'], 'changes_requested');

      // Reenvio anónimo é recusado (evita sequestro da candidatura).
      final (anonStatus, anon) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'establishment',
          'name': 'Dono da Cantina',
          'phone': '845100003',
          'password': 'Segura123',
          'payload': {
            'establishment_name': 'Cantina Corrigida',
            'category_id': 'cat_restaurantes',
            'nuit': '400011223',
          },
        },
      );
      expect(anonStatus, 403);
      expect(anon['error']['code'], 'login_required');

      // O dono, com sessão, reenvia e volta a `pending`.
      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100003', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      final ownerToken = loginJson['token'] as String;
      final (resubmitStatus, resubmit) = await call(
        'POST',
        '/api/applications',
        token: ownerToken,
        body: {
          'kind': 'establishment',
          'name': 'Dono da Cantina',
          'phone': '845100003',
          'password': 'Segura123',
          'payload': {
            'establishment_name': 'Cantina Corrigida',
            'category_id': 'cat_restaurantes',
            'latitude': -14.54,
            'longitude': 40.67,
            'nuit': '400011223',
          },
        },
      );
      expect(resubmitStatus, 200, reason: '$resubmit');
      expect(resubmit['application']['status'], 'pending');

      // O estado devolve `pending` com a nota visível para o dono.
      final (meStatus, me) = await call(
        'GET',
        '/api/applications/me',
        token: ownerToken,
      );
      expect(meStatus, 200, reason: '$me');
      expect(me['application']['status'], 'pending');

      // E a conta continua bloqueada no painel.
      final (blockedStatus, _) = await call(
        'GET',
        '/api/partner/summary',
        token: ownerToken,
      );
      expect(blockedStatus, 403);
    });

    test('candidatura de entregador segue o mesmo fluxo', () async {
      final (status, json) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Estafeta Novo',
          'phone': '845100004',
          'whatsapp': '845100005',
          'password': 'Segura123',
          'payload': {
            'vehicle_type': 'Mota',
            'address': 'Mucipal, Nacala-Porto',
            'notes': 'Disponível de manhã.',
            'nuit': '400055667',
            'documents': await courierDocuments(),
          },
        },
      );
      expect(status, 201, reason: '$json');
      final application = json['application'] as Map<String, dynamic>;
      expect(application['kind'], 'delivery');
      expect(application['payload']['vehicle_type'], 'Mota');

      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100004', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      expect(loginJson['user']['role'], 'delivery');
      expect(loginJson['user']['approval_status'], 'pending');

      // Painel do estafeta bloqueado até à aprovação.
      final (blockedStatus, _) = await call(
        'GET',
        '/api/delivery/assignments',
        token: loginJson['token'] as String,
      );
      expect(blockedStatus, 403);

      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (approveStatus, approve) = await call(
        'POST',
        '/api/admin/applications/${application['id']}/approve',
        token: admin,
      );
      expect(approveStatus, 200, reason: '$approve');
      expect(approve['application']['status'], 'approved');
      // Entregadores não criam estabelecimento.
      expect(approve['establishment_id'], isNull);

      final (afterStatus, after) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100004', 'password': 'Segura123'},
      );
      expect(afterStatus, 200, reason: '$after');
      expect(after['user']['approval_status'], 'approved');
    });

    test('localização do estabelecimento chega ao catálogo (FASE 11)',
        () async {
      // Candidatura marcada no mapa (pesquisa/arrastar marcador no app).
      final (status, json) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'establishment',
          'name': 'Dona do Mapa',
          'phone': '845100011',
          'password': 'Segura123',
          'payload': {
            'establishment_name': 'Cantina no Mapa',
            'category_id': 'cat_restaurantes',
            'address': 'Av. Marginal, Nacala-Porto',
            'description': 'Cozinha junto ao mercado.',
            'latitude': -14.5428,
            'longitude': 40.6729,
            'nuit': '400099887',
          },
        },
      );
      expect(status, 201, reason: '$json');
      final application = json['application'] as Map<String, dynamic>;

      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (approveStatus, approve) = await call(
        'POST',
        '/api/admin/applications/${application['id']}/approve',
        token: admin,
      );
      expect(approveStatus, 200, reason: '$approve');
      final establishmentId = approve['establishment_id'] as String;

      // Lista pública: a coordenada escolhida pelo parceiro viaja no JSON.
      final (_, list) = await call('GET', '/api/establishments');
      final created = (list['establishments'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == establishmentId);
      expect(created['latitude'], -14.5428);
      expect(created['longitude'], 40.6729);

      // Detalhe público idem (é o que o ecrã da loja usa).
      final (detailStatus, detail) = await call(
        'GET',
        '/api/establishments/$establishmentId',
      );
      expect(detailStatus, 200, reason: '$detail');
      expect(detail['establishment']['latitude'], -14.5428);
      expect(detail['establishment']['longitude'], 40.6729);

      // Estabelecimento sem ponto marcado devolve os campos a null (e não
      // omite as chaves) para o cliente degradar sem mapa em vez de quebrar.
      final seed = (list['establishments'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == 'est_mercado');
      expect(seed.containsKey('latitude'), isTrue);
      expect(seed['latitude'], isNull);
      expect(seed['longitude'], isNull);
    });

    test('área pública só cria candidaturas válidas', () async {
      // Tipo inválido (nunca admin/funcionário pela área pública).
      final (kindStatus, kind) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'admin',
          'name': 'Espião',
          'phone': '845100006',
          'password': 'Segura123',
          'payload': const {},
        },
      );
      expect(kindStatus, 422);
      expect(kind['error']['code'], 'invalid_kind');

      // Categoria inexistente.
      final (catStatus, cat) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'establishment',
          'name': 'Sem Categoria',
          'phone': '845100007',
          'password': 'Segura123',
          'payload': {
            'establishment_name': 'Sem Categoria',
            'category_id': 'cat_inexistente',
          },
        },
      );
      expect(catStatus, 422);
      expect(cat['error']['code'], 'invalid_category');

      // Palavra-passe fraca.
      final (pwStatus, pw) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Passe Fraco',
          'phone': '845100008',
          'password': 'soletras',
          'payload': const {},
        },
      );
      expect(pwStatus, 422);
      expect(pw['error']['code'], 'weak_password');
    });
  });

  // --------------------------------------- FASE 10: funcionários
  group('funcionários e permissões', () {
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    test('administrador cria, altera e elimina funcionários', () async {
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      final (createStatus, create) = await call(
        'POST',
        '/api/admin/employees',
        token: admin,
        body: {
          'name': 'Atendedor Loja',
          'email': 'atendedor@nacala.co.mz',
          'phone': '845200001',
          'password': 'Segura123',
          'level': 'staff',
          'permissions': ['orders', 'products'],
        },
      );
      expect(createStatus, 201, reason: '$create');
      final employee = create['employee'] as Map<String, dynamic>;
      expect(employee['level'], 'staff');
      expect(
        (employee['permissions'] as List),
        containsAll(['orders', 'products']),
      );
      expect(employee['is_active'], isTrue);

      // O funcionário entra com role `employee`.
      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845200001', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      expect(loginJson['user']['role'], 'employee');
      final employeeToken = loginJson['token'] as String;

      // Papel `employee` não é admin: nenhuma rota administrativa passa.
      final (usersStatus, _) = await call(
        'GET',
        '/api/admin/users',
        token: employeeToken,
      );
      expect(usersStatus, 403);
      final (appsStatus, _) = await call(
        'GET',
        '/api/admin/applications',
        token: employeeToken,
      );
      expect(appsStatus, 403);

      // Alteração de nível e permissões.
      final employeeId = employee['id'] as String;
      final (updateStatus, update) = await call(
        'PATCH',
        '/api/admin/employees/$employeeId',
        token: admin,
        body: {
          'level': 'admin',
          'permissions': ['orders', 'products', 'customers'],
        },
      );
      expect(updateStatus, 200, reason: '$update');
      expect(update['employee']['level'], 'admin');
      expect((update['employee']['permissions'] as List).length, 3);

      // Desactivar corta a sessão aberta (token_version + 1) e o login.
      final (disableStatus, disable) = await call(
        'PATCH',
        '/api/admin/employees/$employeeId',
        token: admin,
        body: {'is_active': false},
      );
      expect(disableStatus, 200, reason: '$disable');
      expect(disable['employee']['is_active'], isFalse);

      final (staleStatus, _) = await call(
        'GET',
        '/api/admin/users',
        token: employeeToken,
      );
      expect(staleStatus, 401, reason: 'sessão invalidada ao desactivar');
      final (blockedLoginStatus, blockedLogin) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845200001', 'password': 'Segura123'},
      );
      expect(blockedLoginStatus, 403, reason: '$blockedLogin');
      expect(blockedLogin['error']['code'], 'inactive');

      // Reactivar volta a permitir login.
      final (enableStatus, enable) = await call(
        'PATCH',
        '/api/admin/employees/$employeeId',
        token: admin,
        body: {'is_active': true},
      );
      expect(enableStatus, 200, reason: '$enable');
      final (reloginStatus, _) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845200001', 'password': 'Segura123'},
      );
      expect(reloginStatus, 200);

      // Remoção: apaga a conta e a linha de funcionários.
      final (deleteStatus, delete) = await call(
        'DELETE',
        '/api/admin/employees/$employeeId',
        token: admin,
      );
      expect(deleteStatus, 200, reason: '$delete');
      final (listStatus, list) = await call(
        'GET',
        '/api/admin/employees',
        token: admin,
      );
      expect(listStatus, 200, reason: '$list');
      expect(
        (list['employees'] as List).any((e) => e['id'] == employeeId),
        isFalse,
      );
    });

    test('funcionário com permissão `orders` acede só às rotas dele',
        () async {
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      final (createStatus, create) = await call(
        'POST',
        '/api/admin/employees',
        token: admin,
        body: {
          'name': 'Operador Encomendas',
          'email': 'operador@nacala.co.mz',
          'phone': '845200005',
          'password': 'Segura123',
          'level': 'staff',
          'permissions': ['orders'],
        },
      );
      expect(createStatus, 201, reason: '$create');

      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845200005', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      final token = loginJson['token'] as String;

      // O login devolve as permissões para o app montar os separadores.
      expect(
        (loginJson['user']['permissions'] as List),
        ['orders'],
      );
      final (meStatus, me) = await call('GET', '/api/auth/me', token: token);
      expect(meStatus, 200, reason: '$me');
      expect((me['user']['permissions'] as List), ['orders']);

      // Rota coberta pela permissão → 200.
      final (ordersStatus, orders) = await call(
        'GET',
        '/api/admin/orders',
        token: token,
      );
      expect(ordersStatus, 200, reason: '$orders');

      // Rota sem permissão → 403 `missing_permission` (não 404, nem 200).
      final (usersStatus, users) = await call(
        'GET',
        '/api/admin/users',
        token: token,
      );
      expect(usersStatus, 403, reason: '$users');
      expect(users['error']['code'], 'missing_permission');

      // Rotas admin-only continuam vedadas mesmo com permissões.
      final (summaryStatus, _) = await call(
        'GET',
        '/api/admin/summary',
        token: token,
      );
      expect(summaryStatus, 403);
      final (employeesStatus, _) = await call(
        'GET',
        '/api/admin/employees',
        token: token,
      );
      expect(employeesStatus, 403);

      // Limpeza: remover a conta criada.
      final employeeId = create['employee']['id'] as String;
      final (deleteStatus, _) = await call(
        'DELETE',
        '/api/admin/employees/$employeeId',
        token: admin,
      );
      expect(deleteStatus, 200);
    });

    test('valida nível, permissões e duplicados', () async {
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      final (levelStatus, level) = await call(
        'POST',
        '/api/admin/employees',
        token: admin,
        body: {
          'name': 'Nível Errado',
          'email': 'nivel@nacala.co.mz',
          'phone': '845200002',
          'password': 'Segura123',
          'level': 'super_admin',
          'permissions': const [],
        },
      );
      expect(levelStatus, 422);
      expect(level['error']['code'], 'invalid_level');

      final (permStatus, perm) = await call(
        'POST',
        '/api/admin/employees',
        token: admin,
        body: {
          'name': 'Permissão Errada',
          'email': 'perm@nacala.co.mz',
          'phone': '845200003',
          'password': 'Segura123',
          'level': 'staff',
          'permissions': ['outra_coisa'],
        },
      );
      expect(permStatus, 422);
      expect(perm['error']['code'], 'invalid_permissions');

      // Duplicado (email já usado pelo administrador).
      final (dupStatus, dup) = await call(
        'POST',
        '/api/admin/employees',
        token: admin,
        body: {
          'name': 'Duplicado',
          'email': 'admin@nacala.co.mz',
          'phone': '845200004',
          'password': 'Segura123',
          'level': 'staff',
          'permissions': const [],
        },
      );
      expect(dupStatus, 409);
      expect(dup['error']['code'], 'already_registered');
    });

    test('administrador não tem linha de funcionários', () async {
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (_, me) = await call('GET', '/api/auth/me', token: admin);
      final adminId = me['user']['id'] as String;

      // Não existe linha de funcionários para o admin → 404.
      final (status, json) = await call(
        'PATCH',
        '/api/admin/employees/$adminId',
        token: admin,
        body: {'level': 'staff'},
      );
      expect(status, 404);
      expect(json['error']['code'], 'not_found');
    });
  });

  // --------------------------------------- FASE 12: notificações
  group('notificações persistentes', () {
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    test('cliente recebe, lista e marca como lidas as suas notificações',
        () async {
      final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');
      // `cantinho@`/`est_cantinho` são eliminados por testes anteriores
      // desta mesma suite — usa o parceiro que sobrevive.
      final partner = await login('mercado@nacala.co.mz', 'Parceiro@1234');

      // Encomenda nova + aceitação do parceiro → notificação ao cliente.
      final (_, created) = await call(
        'POST',
        '/api/orders',
        token: customer,
        body: {
          'establishment_id': 'est_mercado',
          'address_line': 'Bairro Central, Rua 12, casa 34',
          'address_latitude': -14.5428,
          'address_longitude': 40.6729,
          'phone': '841111111',
          'payment_method': 'cash',
          'items': [
            {'product_id': 'prd_mc_fruta', 'quantity': 1},
          ],
        },
      );
      final orderId = created['order']['id'] as String;

      // Ao criar o pedido, o dono do estabelecimento recebe `new_order`.
      final (partnerNotifStatus, partnerNotifs) = await call(
        'GET',
        '/api/notifications',
        token: partner,
      );
      expect(partnerNotifStatus, 200, reason: '$partnerNotifs');
      final partnerNotifications = partnerNotifs['notifications'] as List;
      expect(
        partnerNotifications.any((n) => n['kind'] == 'new_order'),
        isTrue,
        reason: 'parceiro notificado do novo pedido',
      );

      final (acceptStatus, accepted) = await call(
        'POST',
        '/api/partner/orders/$orderId/accept',
        token: partner,
      );
      expect(acceptStatus, 200, reason: '$accepted');

      final (listStatus, list) = await call(
        'GET',
        '/api/notifications',
        token: customer,
      );
      expect(listStatus, 200, reason: '$list');
      final notifications = list['notifications'] as List;
      expect(
        notifications.any((n) => n['kind'] == 'order_confirmed'),
        isTrue,
        reason: 'cliente notificado na aceitação do pedido',
      );
      final unread = list['unread_count'] as int;
      expect(unread, greaterThan(0));

      // Marca todas como lidas.
      final (readStatus, read) = await call(
        'POST',
        '/api/notifications/read',
        token: customer,
        body: {},
      );
      expect(readStatus, 200, reason: '$read');
      expect(read['updated'], unread);

      final (afterStatus, after) = await call(
        'GET',
        '/api/notifications',
        token: customer,
      );
      expect(afterStatus, 200, reason: '$after');
      expect(after['unread_count'], 0);

      // Segunda vez não conta nada.
      final (againStatus, again) = await call(
        'POST',
        '/api/notifications/read',
        token: customer,
        body: {},
      );
      expect(againStatus, 200, reason: '$again');
      expect(again['updated'], 0);
    });

    test('candidato recebe a decisão na sua conta (FASE 12)', () async {
      // Candidatura de entregador → decisão do admin → notificação ao dono.
      final (applyStatus, apply) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Estafeta Notificado',
          'phone': '845100021',
          'password': 'Segura123',
          'payload': {
            'vehicle_type': 'Mota',
            'address': 'Mucipal, Nacala-Porto',
            'nuit': '400033445',
            'documents': await courierDocuments(),
          },
        },
      );
      expect(applyStatus, 201, reason: '$apply');
      final application = apply['application'] as Map<String, dynamic>;

      // O admin é avisado da nova candidatura (notificação persistente).
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (_, adminBefore) = await call(
        'GET',
        '/api/notifications',
        token: admin,
      );
      expect(
        (adminBefore['notifications'] as List)
            .any((n) => n['kind'] == 'application_new'),
        isTrue,
        reason: 'admin avisado da nova candidatura',
      );

      final (rejectStatus, reject) = await call(
        'POST',
        '/api/admin/applications/${application['id']}/reject',
        token: admin,
        body: {'note': 'Documentação incompleta.'},
      );
      expect(rejectStatus, 200, reason: '$reject');

      // O candidato vê a decisão na própria conta, sem precisar de falar
      // com ninguém — persistente, não é só um toast no ecrã.
      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845100021', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      final token = loginJson['token'] as String;

      final (notifStatus, notifs) = await call(
        'GET',
        '/api/notifications',
        token: token,
      );
      expect(notifStatus, 200, reason: '$notifs');
      final items = notifs['notifications'] as List;
      final decision = items.firstWhere(
        (n) => n['kind'] == 'application_rejected',
        orElse: () => null,
      );
      expect(decision, isNotNull, reason: 'candidato recebeu a decisão');
      expect(decision['body'], contains('Documentação incompleta.'));
      expect(notifs['unread_count'], greaterThan(0));
    });

    test('marcação por ids e isolamento entre contas', () async {
      final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      final (_, adminNotifs) = await call(
        'GET',
        '/api/notifications',
        token: admin,
      );
      final adminIds = [
        for (final n in (adminNotifs['notifications'] as List))
          if (n['is_read'] == false) n['id'] as String,
      ];

      // O cliente não consegue marcar notificações alheias.
      final (foreignStatus, foreign) = await call(
        'POST',
        '/api/notifications/read',
        token: customer,
        body: {'ids': adminIds},
      );
      expect(foreignStatus, 200, reason: '$foreign');
      expect(foreign['updated'], 0, reason: 'notificações alheias ignoradas');

      // A lista administrativa junta o utilizador dono.
      final (adminListStatus, adminList) = await call(
        'GET',
        '/api/admin/notifications',
        token: admin,
      );
      expect(adminListStatus, 200, reason: '$adminList');
      final adminNotifications = adminList['notifications'] as List;
      expect(adminNotifications, isNotEmpty);
      expect(
        adminNotifications.every(
          (n) => n['user_name'] != null && n['user_email'] != null,
        ),
        isTrue,
      );

      // Só administradores acedem à lista global.
      final (forbiddenStatus, _) = await call(
        'GET',
        '/api/admin/notifications',
        token: customer,
      );
      expect(forbiddenStatus, 403);
    });
  });
  // ------------------------------------- FASE 9: desistência de entrega
  group('estafeta desiste de uma entrega aceite', () {
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    test('desistir devolve a entrega ao pool e repõe o pedido', () async {
      final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');
      final partner = await login('mercado@nacala.co.mz', 'Parceiro@1234');
      final courier = await login('estafeta@nacala.co.mz', 'Estafeta@1234');

      // Encomenda com ponto no mapa → parceiro leva até "pronto".
      final (_, created) = await call(
        'POST',
        '/api/orders',
        token: customer,
        body: {
          'establishment_id': 'est_mercado',
          'address_line': 'Bairro Central, Rua 12, casa 34',
          'address_latitude': -14.5428,
          'address_longitude': 40.6729,
          'phone': '841111111',
          'payment_method': 'cash',
          'items': [
            {'product_id': 'prd_mc_fruta', 'quantity': 1},
          ],
        },
      );
      final orderId = created['order']['id'] as String;
      for (final step in ['accept', 'preparing', 'ready']) {
        final (stepStatus, stepJson) = await call(
          'POST',
          '/api/partner/orders/$orderId/$step',
          token: partner,
        );
        expect(stepStatus, 200, reason: '$step: $stepJson');
      }

      final (_, assignments) = await call(
        'GET',
        '/api/delivery/assignments',
        token: courier,
      );
      final assignment = (assignments['assignments'] as List).firstWhere(
        (a) => a['order_id'] == orderId,
      );
      final assignmentId = assignment['id'] as String;

      // Outro estafeta (aprovado pelo administrador) não pode desistir
      // de uma entrega que não é dele → 404 (courier_id = eu).
      final (applyStatus, apply) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Segundo Estafeta',
          'phone': '845100009',
          'password': 'Segura123',
          'payload': {
            'vehicle_type': 'Mota',
            'nuit': '400066778',
            'documents': await courierDocuments(),
          },
        },
      );
      expect(applyStatus, 201, reason: '$apply');
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (approveStatus, _) = await call(
        'POST',
        '/api/admin/applications/${apply['application']['id']}/approve',
        token: admin,
      );
      expect(approveStatus, 200);
      final otherCourier = await login('845100009', 'Segura123');

      final (acceptStatus, accepted) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/accept',
        token: courier,
      );
      expect(acceptStatus, 200, reason: '$accepted');

      final (foreignStatus, foreign) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/decline',
        token: otherCourier,
      );
      expect(foreignStatus, 404, reason: '$foreign');
      expect(foreign['error']['code'], 'not_found');

      // Dono desiste: a volta a estar disponível e o pedido continua
      // "pronto" (ainda não tinha saído para entrega).
      final (declineStatus, declined) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/decline',
        token: courier,
      );
      expect(declineStatus, 200, reason: '$declined');
      final (_, afterFirst) = await call(
        'GET',
        '/api/delivery/assignments',
        token: courier,
      );
      final released = (afterFirst['assignments'] as List).firstWhere(
        (a) => a['id'] == assignmentId,
      );
      expect(released['status'], 'available');
      expect(released['courier_id'], isNull);

      // Aceita de novo, inicia a entrega e desiste a caminho: o pedido
      // volta de `on_the_way` para `ready`.
      final (reacceptStatus, _) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/accept',
        token: courier,
      );
      expect(reacceptStatus, 200);
      final (startStatus, started) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/start',
        token: courier,
      );
      expect(startStatus, 200, reason: '$started');
      expect(started['order']['status'], 'on_the_way');

      final (midStatus, mid) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/decline',
        token: courier,
      );
      expect(midStatus, 200, reason: '$mid');
      final (_, order) = await call('GET', '/api/orders/$orderId', token: customer);
      expect(order['order']['status'], 'ready');

      // Já não é dona → segundo desistir dá 404.
      final (againStatus, again) = await call(
        'POST',
        '/api/delivery/assignments/$assignmentId/decline',
        token: courier,
      );
      expect(againStatus, 404, reason: '$again');
    });
  });

  // ------------------- FASE 13: NUIT, documentos e respostas 404 em JSON
  group('NUIT, documentos do entregador e 404 em JSON', () {
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    test('rota desconhecida devolve 404 em JSON, não texto puro', () async {
      final (status, json) = await call('GET', '/api/rota-que-nao-existe');
      expect(status, 404, reason: '$json');
      expect(json['error']['code'], 'route_not_found');
      expect(json['error']['message'], isNotEmpty);
    });

    test('candidatura exige NUIT de 9 dígitos', () async {
      final (missingStatus, missing) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'establishment',
          'name': 'Candidato Sem NUIT',
          'phone': '845100031',
          'password': 'Segura123',
          'payload': {
            'establishment_name': 'Cantina Sem NUIT',
            'category_id': 'cat_restaurantes',
          },
        },
      );
      expect(missingStatus, 422, reason: '$missing');
      expect(missing['error']['code'], 'invalid_nuit');

      final (shortStatus, short) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'establishment',
          'name': 'Candidato NUIT Curto',
          'phone': '845100032',
          'password': 'Segura123',
          'payload': {
            'establishment_name': 'Cantina NUIT Curto',
            'category_id': 'cat_restaurantes',
            'nuit': '12345',
          },
        },
      );
      expect(shortStatus, 422, reason: '$short');
      expect(short['error']['code'], 'invalid_nuit');
    });

    test('entregador envia selfie, B.I (frente/verso) e carta de condução',
        () async {
      // Sem documentos → candidatura recusada.
      final (noDocsStatus, noDocs) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Estafeta Sem Documentos',
          'phone': '845100033',
          'password': 'Segura123',
          'payload': {'vehicle_type': 'Mota', 'nuit': '400012345'},
        },
      );
      expect(noDocsStatus, 422, reason: '$noDocs');
      expect(noDocs['error']['code'], 'missing_documents');

      // Referência a imagem que nunca foi carregada também é recusada.
      const absent = '/uploads/00000000000000000000000000000000.png';
      final (fakeStatus, fake) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Estafeta Documento Falso',
          'phone': '845100033',
          'password': 'Segura123',
          'payload': {
            'vehicle_type': 'Mota',
            'nuit': '400012345',
            'documents': {
              'selfie': absent,
              'bi_front': absent,
              'bi_back': absent,
              'license': absent,
            },
          },
        },
      );
      expect(fakeStatus, 422, reason: '$fake');
      expect(fake['error']['code'], 'missing_document');

      // Documentos reais, carregados pelo endpoint público.
      final documents = await courierDocuments();
      final (status, json) = await call(
        'POST',
        '/api/applications',
        body: {
          'kind': 'delivery',
          'name': 'Estafeta Documentado',
          'phone': '845100034',
          'password': 'Segura123',
          'payload': {
            'vehicle_type': 'Mota',
            'address': 'Mucipal, Nacala-Porto',
            'nuit': '400012345',
            'documents': documents,
          },
        },
      );
      expect(status, 201, reason: '$json');
      final payload =
          json['application']['payload'] as Map<String, dynamic>;
      expect(payload['nuit'], '400012345');
      expect(payload['documents'], documents);

      // O administrador vê os documentos na candidatura.
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (listStatus, list) = await call(
        'GET',
        '/api/admin/applications?status=pending',
        token: admin,
      );
      expect(listStatus, 200, reason: '$list');
      final reviewed = (list['applications'] as List).firstWhere(
        (item) => item['id'] == json['application']['id'],
      ) as Map<String, dynamic>;
      expect(reviewed['payload']['nuit'], '400012345');
      expect(
        (reviewed['payload']['documents'] as Map).keys,
        containsAll(['selfie', 'bi_front', 'bi_back', 'license']),
      );
    });

    test('upload de imagem de candidatura valida formato e ficheiro', () async {
      final (badStatus, bad) = await call(
        'POST',
        '/api/applications/images',
        body: {'mime_type': 'image/gif', 'data_base64': 'R0lGODlhAQAB'},
      );
      expect(badStatus, 422, reason: '$bad');
      expect(bad['error']['code'], 'invalid_image');

      final path = await uploadApplicationImage();
      expect(path, matches(RegExp(r'^/uploads/[a-f0-9]{32}\.png$')));
      final image = await api.handler(
        Request('GET', Uri.parse('http://localhost$path')),
      );
      expect(image.statusCode, 200);
      expect(image.headers['content-type'], contains('image/png'));
      await image.read().drain<void>();
    });

    test('administração carrega a foto do parceiro como ficheiro', () async {
      final (anonStatus, anon) = await call(
        'POST',
        '/api/admin/partner-images',
        body: {'mime_type': 'image/png', 'data_base64': _tinyPng},
      );
      expect(anonStatus, 401, reason: '$anon');

      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (uploadStatus, upload) = await call(
        'POST',
        '/api/admin/partner-images',
        token: admin,
        body: {'mime_type': 'image/png', 'data_base64': _tinyPng},
      );
      expect(uploadStatus, 201, reason: '$upload');
      expect(upload['image_url'], startsWith('/uploads/'));

      // Um funcionário sem a permissão de estabelecimentos não carrega.
      final (forbiddenStatus, _) = await call(
        'POST',
        '/api/admin/partner-images',
        token: await login('cliente@nacala.co.mz', 'Cliente@1234'),
        body: {'mime_type': 'image/png', 'data_base64': _tinyPng},
      );
      expect(forbiddenStatus, 403);
    });

    test('registar parceiro no admin exige NUIT', () async {
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');
      final (status, json) = await call(
        'POST',
        '/api/admin/partners',
        token: admin,
        body: {
          'name': 'Gestor Sem NUIT',
          'email': 'sem.nuit@nacala.co.mz',
          'phone': '846666667',
          'password': 'Parceiro123',
          'establishment_name': 'Loja Sem NUIT',
          'category_id': 'cat_lojas',
          'address': 'Bairro Central',
        },
      );
      expect(status, 422, reason: '$json');
      expect(json['error']['code'], 'invalid_nuit');
    });
  });

  // ------------------------------------- FASE 13: segurança e correções
  group('segurança: chat, papéis e proteção de contas', () {
    setUp(() {
      api = Api(
        db: db,
        jwt: JwtService('test-secret'),
        imageDirectory: imageDirectory,
      );
    });

    test('chat: só participantes leem e escrevem na conversa', () async {
      final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');
      final partner = await login('mercado@nacala.co.mz', 'Parceiro@1234');
      final courier = await login('estafeta@nacala.co.mz', 'Estafeta@1234');

      // O cliente cria a conversa com o parceiro (pares permitidos).
      final (_, establishments) = await call('GET', '/api/establishments');
      final partnerUserId = (establishments['establishments'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == 'est_mercado')['owner_user_id']
          as String;
      final (createStatus, created) = await call(
        'POST',
        '/api/conversations',
        token: customer,
        body: {'other_user_id': partnerUserId},
      );
      expect(createStatus, 201, reason: '$created');
      final conversationId =
          created['conversation']['id'] as String;

      // Participantes trocam mensagens.
      final (sendStatus, sent) = await call(
        'POST',
        '/api/conversations/$conversationId/messages',
        token: customer,
        body: {'body': 'O pedido já saiu?'},
      );
      expect(sendStatus, 201, reason: '$sent');

      // Um terceiro (estafeta, outro papel ativo) não é participante:
      // leitura e escrita vedadas — mesmo com token válido.
      final (readStatus, read) = await call(
        'GET',
        '/api/conversations/$conversationId/messages',
        token: courier,
      );
      expect(readStatus, 403, reason: '$read');
      expect(read['error']['code'], 'forbidden');

      final (writeStatus, write) = await call(
        'POST',
        '/api/conversations/$conversationId/messages',
        token: courier,
        body: {'body': 'Intruso'},
      );
      expect(writeStatus, 403, reason: '$write');

      // O parceiro (participante) lê normalmente.
      final (partnerReadStatus, partnerRead) = await call(
        'GET',
        '/api/conversations/$conversationId/messages',
        token: partner,
      );
      expect(partnerReadStatus, 200, reason: '$partnerRead');
      expect(
        (partnerRead['messages'] as List).any((m) => m['body'] == 'O pedido já saiu?'),
        isTrue,
      );

      // Pares proibidos: cliente não cria conversa consigo mesmo nem
      // com outro cliente.
      final (selfStatus, self) = await call(
        'POST',
        '/api/conversations',
        token: customer,
        body: {'other_user_id': 'u_qualquer'},
      );
      expect(selfStatus, anyOf(403, 404, 422), reason: '$self');
    });

    test('cliente não acede a painéis, rotas de estafeta nem de parceiro',
        () async {
      final customer = await login('cliente@nacala.co.mz', 'Cliente@1234');

      // Painel administrativo (rotas concretas, não só o resumo).
      for (final path in [
        '/api/admin/users',
        '/api/admin/orders',
        '/api/admin/applications',
        '/api/admin/employees',
        '/api/admin/audit',
        '/api/admin/notifications',
      ]) {
        final (status, json) = await call('GET', path, token: customer);
        expect(status, 403, reason: '$path → $json');
        expect(json['error']['code'], anyOf('forbidden', 'missing_permission'),
            reason: path);
      }

      // Painel comercial do parceiro.
      for (final path in ['/api/partner/summary', '/api/partner/orders']) {
        final (status, _) = await call('GET', path, token: customer);
        expect(status, 403, reason: path);
      }

      // Rotas do estafeta.
      for (final path in ['/api/delivery/assignments', '/api/delivery/history']) {
        final (status, _) = await call('GET', path, token: customer);
        expect(status, 403, reason: path);
      }
    });

    test('conta administrativa não é eliminável nem rebaixável por '
        'funcionário', () async {
      final admin = await login('admin@nacala.co.mz', 'Admin@1234');

      // Funcionário com permissão `customers` (pode gerir utilizadores).
      final (createStatus, create) = await call(
        'POST',
        '/api/admin/employees',
        token: admin,
        body: {
          'name': 'Gestor de Contas',
          'email': 'gestor@nacala.co.mz',
          'phone': '845200031',
          'password': 'Segura123',
          'level': 'admin',
          'permissions': ['customers'],
        },
      );
      expect(createStatus, 201, reason: '$create');
      final employeeId = create['employee']['id'] as String;

      final (loginStatus, loginJson) = await call(
        'POST',
        '/api/auth/login',
        body: {'identifier': '845200031', 'password': 'Segura123'},
      );
      expect(loginStatus, 200, reason: '$loginJson');
      final token = loginJson['token'] as String;
      final adminUserId = loginJson['user']['id'] as String;
      final (_, adminRow) = await call('GET', '/api/auth/me', token: admin);
      final realAdminId = adminRow['user']['id'] as String;

      // Não pode mudar o papel do administrador.
      final (roleStatus, role) = await call(
        'PATCH',
        '/api/admin/users/$realAdminId',
        token: token,
        body: {'role': 'customer'},
      );
      expect(roleStatus, 403, reason: '$role');
      expect(role['error']['code'], 'forbidden');

      // Não pode desativar o administrador.
      final (activeStatus, active) = await call(
        'PATCH',
        '/api/admin/users/$realAdminId',
        token: token,
        body: {'is_active': false},
      );
      expect(activeStatus, 403, reason: '$active');

      // Não pode eliminar o administrador.
      final (delStatus, del) = await call(
        'DELETE',
        '/api/admin/users/$realAdminId',
        token: token,
      );
      expect(delStatus, 403, reason: '$del');

      // O próprio administrador também não se elimina (409 self_delete).
      final (selfDel, selfJson) = await call(
        'DELETE',
        '/api/admin/users/$realAdminId',
        token: admin,
      );
      expect(selfDel, 409, reason: '$selfJson');
      expect(selfJson['error']['code'], 'self_delete');

      // Limpeza.
      final (cleanup, _) = await call(
        'DELETE',
        '/api/admin/employees/$employeeId',
        token: admin,
      );
      expect(cleanup, 200);
      expect(adminUserId, isNotEmpty);
    });
  });
}

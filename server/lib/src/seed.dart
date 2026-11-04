import 'package:sqlite3/sqlite3.dart';

import 'auth.dart';
import 'db.dart';

/// Cria a estrutura mínima da plataforma: conta de administração e as
/// categorias do catálogo.
///
/// Não cria parceiros, produtos, pedidos nem avaliações fictícios — os
/// parceiros reais são registados pela administração. `demo: true` acrescenta
/// dados de demonstração e destina-se apenas aos testes e a `SEED_DEMO=1`.
void seedDatabase(Database db, {bool demo = false}) {
  final count = db.select('SELECT COUNT(*) AS c FROM users').first['c'] as int;
  if (count > 0) return;

  final now = nowIso();

  void user(
    String id,
    String role,
    String name,
    String email,
    String phone,
    String password,
  ) {
    final digest = hashPassword(password);
    db.execute(
      '''
      INSERT INTO users (id, role, name, email, phone, password_hash,
        password_salt, token_version, is_active, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 0, 1, ?)
      ''',
      [id, role, name, email, phone, digest.hash, digest.salt, now],
    );
  }

  const adminId = 'usr_admin';
  user(adminId, 'admin', 'Administração Nacala', 'admin@nacala.co.mz',
      '840000001', 'Admin@1234');

  const categories = [
    ('cat_restaurantes', 'Restaurantes', 'restaurantes', 'restaurant', 1),
    ('cat_mercados', 'Supermercados', 'mercados', 'basket', 2),
    ('cat_farmacias', 'Farmácias', 'farmacias', 'pharmacy', 3),
    ('cat_lojas', 'Lojas', 'lojas', 'store', 4),
    ('cat_padarias', 'Padarias', 'padarias', 'bakery', 5),
    ('cat_bebidas', 'Bebidas', 'bebidas', 'drinks', 6),
    ('cat_talhos', 'Talhos', 'talhos', 'butchery', 7),
    ('cat_peixarias', 'Peixarias', 'peixarias', 'fish', 8),
  ];
  for (final category in categories) {
    db.execute(
      'INSERT INTO categories (id, name, slug, icon, sort_order) VALUES (?, ?, ?, ?, ?)',
      [category.$1, category.$2, category.$3, category.$4, category.$5],
    );
  }

  // Sem `demo`, a base fica apenas com o administrador e as categorias.
  if (!demo) return;

  const customerId = 'usr_customer';
  const courierId = 'usr_courier';
  const partnerCantinhoId = 'usr_partner_cantinho';
  const partnerMercadoId = 'usr_partner_mercado';
  const partnerFarmaciaId = 'usr_partner_farmacia';
  const partnerLojaId = 'usr_partner_loja';

  user(customerId, 'customer', 'Cliente Demonstração', 'cliente@nacala.co.mz',
      '841111111', 'Cliente@1234');
  user(courierId, 'delivery', 'Estafeta Nacala', 'estafeta@nacala.co.mz',
      '842222222', 'Estafeta@1234');
  user(partnerCantinhoId, 'partner', 'Cantinho da Baía',
      'cantinho@nacala.co.mz', '843333331', 'Parceiro@1234');
  user(partnerMercadoId, 'partner', 'Mercado Central', 'mercado@nacala.co.mz',
      '843333332', 'Parceiro@1234');
  user(partnerFarmaciaId, 'partner', 'Farmácia Nacala', 'farmacia@nacala.co.mz',
      '843333333', 'Parceiro@1234');
  user(partnerLojaId, 'partner', 'Loja do Bairro', 'loja@nacala.co.mz',
      '843333334', 'Parceiro@1234');

  void establishment({
    required String id,
    required String ownerId,
    required String categoryId,
    required String name,
    required String slug,
    required String description,
    required String phone,
    required String address,
    required int fee,
    required int prep,
  }) {
    db.execute(
      '''
      INSERT INTO establishments (id, owner_user_id, category_id, name, slug,
        description, phone, address, delivery_fee_cents, prep_minutes,
        opens_at, closes_at, is_open, is_approved, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '08:00', '21:30', 1, 1, ?)
      ''',
      [
        id,
        ownerId,
        categoryId,
        name,
        slug,
        description,
        phone,
        address,
        fee,
        prep,
        now
      ],
    );
  }

  establishment(
    id: 'est_cantinho',
    ownerId: partnerCantinhoId,
    categoryId: 'cat_restaurantes',
    name: 'Cantinho da Baía',
    slug: 'cantinho-da-baia',
    description: 'Frango grelhado · Mariscos · Cozinha moçambicana',
    phone: '843333331',
    address: 'Av. Marginal, Nacala-Porto',
    fee: 8000,
    prep: 30,
  );
  establishment(
    id: 'est_mercado',
    ownerId: partnerMercadoId,
    categoryId: 'cat_mercados',
    name: 'Mercado Central',
    slug: 'mercado-central',
    description: 'Frescos · Mercearia · Bebidas',
    phone: '843333332',
    address: 'Bairro Central, Nacala-Porto',
    fee: 6000,
    prep: 20,
  );
  establishment(
    id: 'est_farmacia',
    ownerId: partnerFarmaciaId,
    categoryId: 'cat_farmacias',
    name: 'Farmácia Nacala',
    slug: 'farmacia-nacala',
    description: 'Cuidados de saúde e bem-estar',
    phone: '843333333',
    address: 'Rua da Saúde, Nacala-Porto',
    fee: 7000,
    prep: 20,
  );
  establishment(
    id: 'est_loja',
    ownerId: partnerLojaId,
    categoryId: 'cat_lojas',
    name: 'Loja do Bairro',
    slug: 'loja-do-bairro',
    description: 'Casa · Acessórios · Utilidades',
    phone: '843333334',
    address: 'Bairro Triângulo, Nacala-Porto',
    fee: 9000,
    prep: 35,
  );

  void product(
    String id,
    String establishmentId,
    String name,
    String description,
    int priceCents,
    String category, {
    bool available = true,
    int? stock,
  }) {
    db.execute(
      '''
      INSERT INTO products (id, establishment_id, name, description,
        price_cents, category, stock, is_available, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        establishmentId,
        name,
        description,
        priceCents,
        category,
        stock,
        available ? 1 : 0,
        now,
        now
      ],
    );
  }

  product('prd_cb_frango', 'est_cantinho', 'Frango grelhado',
      'Frango inteiro com batata e salada', 45000, 'Pratos principais');
  product('prd_cb_caril', 'est_cantinho', 'Caril de camarão',
      'Camarão fresco com arroz de coco', 62000, 'Pratos principais');
  product('prd_cb_matapa', 'est_cantinho', 'Matapa com arroz',
      'Receita tradicional com folha de mandioca', 38000, 'Pratos principais');
  product(
      'prd_cb_familia',
      'est_cantinho',
      'Menu família',
      'Frango, matapa, arroz e salada para 4 pessoas',
      120000,
      'Pratos principais');
  product('prd_cb_sumo', 'est_cantinho', 'Sumo de manga', 'Natural, 500 ml',
      12000, 'Bebidas');
  product('prd_cb_agua', 'est_cantinho', 'Água mineral', 'Garrafa 1,5 L', 8000,
      'Bebidas');
  product('prd_cb_sobremesa', 'est_cantinho', 'Mousse de maracujá',
      'Sobremesa caseira', 15000, 'Sobremesas',
      available: false);

  product('prd_mc_fruta', 'est_mercado', 'Cesta de fruta',
      'Banana, manga e papaia', 35000, 'Frescos');
  product('prd_mc_legumes', 'est_mercado', 'Legumes frescos',
      'Tomate, cebola e couve', 18000, 'Frescos');
  product('prd_mc_arroz', 'est_mercado', 'Arroz 5 kg', 'Grão longo', 42000,
      'Mercearia');
  product('prd_mc_oleo', 'est_mercado', 'Óleo alimentar 2 L', 'Para cozinhar',
      26000, 'Mercearia');
  product('prd_mc_acucar', 'est_mercado', 'Açúcar 1 kg', 'Açúcar branco', 9500,
      'Mercearia');
  product('prd_mc_agua', 'est_mercado', 'Pack de água', '6 garrafas de 1,5 L',
      32000, 'Bebidas');

  product('prd_fn_paracetamol', 'est_farmacia', 'Paracetamol',
      'Caixa de 20 comprimidos', 12000, 'Medicamentos');
  product('prd_fn_soro', 'est_farmacia', 'Soro de reidratação', '3 saquetas',
      9000, 'Medicamentos');
  product('prd_fn_mascaras', 'est_farmacia', 'Máscaras faciais', 'Pacote de 10',
      15000, 'Proteção');
  product('prd_fn_protector', 'est_farmacia', 'Protetor solar',
      'FPS 30, 100 ml', 48000, 'Cuidados');

  product('prd_lb_pilhas', 'est_loja', 'Pilhas AA', 'Pacote de 4', 18000,
      'Utilidades');
  product('prd_lb_lampada', 'est_loja', 'Lâmpada LED', '9 W, luz branca', 22000,
      'Casa');
  product('prd_lb_cabo', 'est_loja', 'Cabo USB-C', '1,5 m, carregamento rápido',
      35000, 'Acessórios');
  product('prd_lb_caderno', 'est_loja', 'Caderno A5', '80 folhas pautadas',
      12000, 'Papelaria');

  db.execute(
    '''
    INSERT INTO addresses (id, user_id, label, line, reference, city,
      is_default, created_at)
    VALUES
      ('adr_casa', ?, 'Casa', 'Bairro Central, Rua 12, casa 34',
       'Perto da escola primária', 'Nacala-Porto', 1, ?),
      ('adr_trabalho', ?, 'Trabalho', 'Bairro Triângulo, Av. 25 de Setembro',
       'Edifício azul, 2.º andar', 'Nacala-Porto', 0, ?)
    ''',
    [customerId, now, customerId, now],
  );

  db.execute(
    '''
    INSERT INTO coupons (id, code, kind, value, min_subtotal_cents, max_uses,
      used_count, expires_at, is_active)
    VALUES
      ('cpn_bemvindo', 'BEMVINDO10', 'percent', 10, 50000, 500, 0, NULL, 1),
      ('cpn_entrega', 'ENTREGA50', 'fixed', 5000, 20000, 200, 0, NULL, 1)
    ''',
  );

  db.execute(
    "INSERT INTO counters (name, value) VALUES ('order', 1048)",
  );

  // Pedidos históricos entregues (para histórico e avaliações reais).
  void historicalOrder({
    required String id,
    required String number,
    required String establishmentId,
    required List<(String, int)> items,
    required String status,
    required int rating,
    required String comment,
    required String createdAt,
  }) {
    var subtotal = 0;
    for (final item in items) {
      final price = db.select('SELECT price_cents FROM products WHERE id = ?',
          [item.$1]).first['price_cents'] as int;
      subtotal += price * item.$2;
    }
    final fee = db.select(
      'SELECT delivery_fee_cents FROM establishments WHERE id = ?',
      [establishmentId],
    ).first['delivery_fee_cents'] as int;
    db.execute(
      '''
      INSERT INTO orders (id, number, customer_id, establishment_id,
        address_label, address_line, phone, payment_method, payment_status,
        status, subtotal_cents, delivery_fee_cents, discount_cents, total_cents,
        currency, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'Casa', 'Bairro Central, Rua 12, casa 34',
        '841111111', 'cash', 'cash_on_delivery', ?, ?, ?, 0, ?, 'MZN', ?, ?)
      ''',
      [
        id,
        number,
        customerId,
        establishmentId,
        status,
        subtotal,
        fee,
        subtotal + fee,
        createdAt,
        createdAt
      ],
    );
    for (final item in items) {
      final product = db.select(
        'SELECT name, price_cents FROM products WHERE id = ?',
        [item.$1],
      ).first;
      db.execute(
        '''
        INSERT INTO order_items (id, order_id, product_id, name_snapshot,
          unit_price_cents, quantity, line_total_cents)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          newId(),
          id,
          item.$1,
          product['name'] as String,
          product['price_cents'] as int,
          item.$2,
          (product['price_cents'] as int) * item.$2
        ],
      );
    }
    db.execute(
      '''
      INSERT INTO order_events (id, order_id, status, actor_id, created_at)
      VALUES (?, ?, 'delivered', ?, ?)
      ''',
      [newId(), id, courierId, createdAt],
    );
    db.execute(
      '''
      INSERT INTO reviews (id, order_id, customer_id, establishment_id, rating,
        comment, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [newId(), id, customerId, establishmentId, rating, comment, createdAt],
    );
  }

  historicalOrder(
    id: 'ord_hist_1',
    number: 'NC-1046',
    establishmentId: 'est_cantinho',
    items: [('prd_cb_frango', 1), ('prd_cb_sumo', 2)],
    status: 'delivered',
    rating: 5,
    comment: 'Chegou quente e a tempo. Recomendo.',
    createdAt: '2026-10-24T18:20:00.000Z',
  );
  historicalOrder(
    id: 'ord_hist_2',
    number: 'NC-1047',
    establishmentId: 'est_mercado',
    items: [('prd_mc_fruta', 1), ('prd_mc_arroz', 1)],
    status: 'delivered',
    rating: 4,
    comment: 'Boa qualidade, entrega rápida.',
    createdAt: '2026-10-27T10:05:00.000Z',
  );
}

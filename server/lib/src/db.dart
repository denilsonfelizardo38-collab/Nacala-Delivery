import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'seed.dart';

/// Abre (ou cria) a base de dados SQLite e aplica as migrações pendentes.
Database openDatabase(String path, {bool seed = true, bool demoSeed = false}) {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
  final db = path == ':memory:'
      ? sqlite3.openInMemory()
      : (Directory(path).existsSync()
          ? sqlite3.open('$path/nacala.db')
          : sqlite3.open(path));
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('PRAGMA journal_mode = WAL');
  db.createFunction(
    functionName: 'normalize',
    function: (args) => normalizeText(args.first?.toString() ?? ''),
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
  );
  _migrate(db);
  if (seed) seedDatabase(db, demo: demoSeed);
  return db;
}

void _migrate(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS migrations (
      version INTEGER PRIMARY KEY,
      applied_at TEXT NOT NULL
    )
  ''');
  final applied = {
    for (final row in db.select('SELECT version FROM migrations'))
      row['version'] as int,
  };

  for (final migration in migrations) {
    if (applied.contains(migration.version)) continue;
    db.execute('BEGIN');
    try {
      for (final statement in migration.statements) {
        db.execute(statement);
      }
      db.execute(
        'INSERT INTO migrations (version, applied_at) VALUES (?, ?)',
        [migration.version, DateTime.now().toUtc().toIso8601String()],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

class Migration {
  const Migration(this.version, this.statements);
  final int version;
  final List<String> statements;
}

const migrations = <Migration>[
  Migration(1, [
    '''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL CHECK (role IN ('customer','partner','delivery','admin')),
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      phone TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      token_version INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      slug TEXT NOT NULL UNIQUE,
      icon TEXT NOT NULL DEFAULT 'store',
      sort_order INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE establishments (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      category_id TEXT NOT NULL REFERENCES categories(id),
      name TEXT NOT NULL,
      slug TEXT NOT NULL UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      image_url TEXT,
      delivery_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_cents >= 0),
      prep_minutes INTEGER NOT NULL DEFAULT 30 CHECK (prep_minutes > 0),
      opens_at TEXT NOT NULL DEFAULT '08:00',
      closes_at TEXT NOT NULL DEFAULT '21:00',
      is_open INTEGER NOT NULL DEFAULT 1,
      is_approved INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE addresses (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      line TEXT NOT NULL,
      reference TEXT,
      city TEXT NOT NULL DEFAULT 'Nacala-Porto',
      is_default INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE products (
      id TEXT PRIMARY KEY,
      establishment_id TEXT NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
      category TEXT NOT NULL DEFAULT 'Geral',
      image_url TEXT,
      stock INTEGER,
      is_available INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE coupons (
      id TEXT PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      kind TEXT NOT NULL CHECK (kind IN ('fixed','percent')),
      value INTEGER NOT NULL CHECK (value > 0),
      min_subtotal_cents INTEGER NOT NULL DEFAULT 0,
      max_uses INTEGER,
      used_count INTEGER NOT NULL DEFAULT 0,
      expires_at TEXT,
      is_active INTEGER NOT NULL DEFAULT 1
    )
    ''',
    '''
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      number TEXT NOT NULL UNIQUE,
      customer_id TEXT NOT NULL REFERENCES users(id),
      establishment_id TEXT NOT NULL REFERENCES establishments(id),
      address_label TEXT NOT NULL DEFAULT 'Entrega',
      address_line TEXT NOT NULL,
      phone TEXT NOT NULL,
      note TEXT,
      payment_method TEXT NOT NULL CHECK (payment_method IN ('mpesa','emola','cash')),
      payment_status TEXT NOT NULL CHECK (payment_status IN ('pending_integration','cash_on_delivery')),
      status TEXT NOT NULL CHECK (status IN ('pending','confirmed','preparing','ready','on_the_way','delivered','cancelled','rejected')),
      subtotal_cents INTEGER NOT NULL CHECK (subtotal_cents >= 0),
      delivery_fee_cents INTEGER NOT NULL CHECK (delivery_fee_cents >= 0),
      discount_cents INTEGER NOT NULL DEFAULT 0 CHECK (discount_cents >= 0),
      total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
      currency TEXT NOT NULL DEFAULT 'MZN',
      coupon_code TEXT,
      rejection_reason TEXT,
      cancellation_reason TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE order_items (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      product_id TEXT REFERENCES products(id) ON DELETE SET NULL,
      name_snapshot TEXT NOT NULL,
      unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      line_total_cents INTEGER NOT NULL CHECK (line_total_cents >= 0),
      note TEXT
    )
    ''',
    '''
    CREATE TABLE order_events (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      status TEXT NOT NULL,
      note TEXT,
      actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE delivery_assignments (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
      courier_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      status TEXT NOT NULL CHECK (status IN ('available','accepted','declined','completed')),
      accepted_at TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE reviews (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
      customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      establishment_id TEXT NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
      rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
      comment TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE audit_logs (
      id TEXT PRIMARY KEY,
      actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      entity TEXT NOT NULL,
      entity_id TEXT,
      metadata TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE counters (
      name TEXT PRIMARY KEY,
      value INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_products_establishment ON products(establishment_id)',
    'CREATE INDEX idx_products_name ON products(name)',
    'CREATE INDEX idx_orders_customer ON orders(customer_id)',
    'CREATE INDEX idx_orders_establishment ON orders(establishment_id)',
    'CREATE INDEX idx_orders_status ON orders(status)',
    'CREATE INDEX idx_addresses_user ON addresses(user_id)',
    'CREATE INDEX idx_assignments_courier ON delivery_assignments(courier_id)',
  ]),
  Migration(2, [
    'ALTER TABLE addresses ADD COLUMN latitude REAL',
    'ALTER TABLE addresses ADD COLUMN longitude REAL',
    'ALTER TABLE orders ADD COLUMN address_latitude REAL',
    'ALTER TABLE orders ADD COLUMN address_longitude REAL',
    'ALTER TABLE delivery_assignments ADD COLUMN latitude REAL',
    'ALTER TABLE delivery_assignments ADD COLUMN longitude REAL',
    'ALTER TABLE delivery_assignments ADD COLUMN location_updated_at TEXT',
    'ALTER TABLE delivery_assignments ADD COLUMN departed_at TEXT',
  ]),
  Migration(3, [
    'ALTER TABLE categories ADD COLUMN image_url TEXT',
  ]),
  Migration(4, [
    '''
    CREATE TABLE IF NOT EXISTS favorites (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      establishment_id TEXT NOT NULL
        REFERENCES establishments(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, establishment_id)
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id)',
  ]),
  Migration(5, [
    'ALTER TABLE users ADD COLUMN avatar_url TEXT',
  ]),
];

/// Gera identificadores opacos para as linhas.
final _random = Random.secure();

String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String nowIso() => DateTime.now().toUtc().toIso8601String();

/// Remove acentos e normaliza para minúsculas, permitindo pesquisas como
/// "baia" encontrarem "Baía". Usado como função SQL `normalize(x)`.
String normalizeText(String value) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

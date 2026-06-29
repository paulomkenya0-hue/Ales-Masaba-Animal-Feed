import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// DatabaseHelper - Msimamizi wa Hifadhidata ya SQLite (100% Offline)
/// Jedwali zote 13 zinazohitajika kwa mfumo zimo hapa.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _database;
  static const String dbName = 'ales_masaba_feed.db';
  static const int dbVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Users
    batch.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        full_name TEXT,
        role TEXT NOT NULL DEFAULT 'Admin',
        pin_hash TEXT,
        email TEXT,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 2. Categories
    batch.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Products
    batch.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER,
        buying_price REAL NOT NULL DEFAULT 0,
        retail_price REAL NOT NULL DEFAULT 0,
        wholesale_price REAL NOT NULL DEFAULT 0,
        quantity REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'Kg',
        low_stock_limit REAL NOT NULL DEFAULT 10,
        barcode TEXT,
        image_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // 4. Customers
    batch.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        village TEXT,
        customer_type TEXT NOT NULL DEFAULT 'Mkulima',
        created_at TEXT NOT NULL
      )
    ''');

    // 5. Sales (sale header)
    batch.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        total_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'Fedha Taslimu',
        sale_date TEXT NOT NULL,
        user_id INTEGER,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // 6. Sale Items
    batch.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 7. Credit Sales
    batch.execute('''
      CREATE TABLE credit_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        amount_owed REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'Inadaiwa',
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // 8. Payments
    batch.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        credit_sale_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (credit_sale_id) REFERENCES credit_sales (id)
      )
    ''');

    // 9. Expenses
    batch.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        expense_date TEXT NOT NULL,
        user_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // 10. Settings
    batch.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT NOT NULL DEFAULT 'Ales Masaba Animal Feed',
        phone TEXT,
        address TEXT,
        currency TEXT NOT NULL DEFAULT 'TZS',
        logo_path TEXT,
        tax_percentage REAL NOT NULL DEFAULT 0,
        backup_location TEXT,
        theme_mode TEXT NOT NULL DEFAULT 'light'
      )
    ''');

    // 11. Backup Logs
    batch.execute('''
      CREATE TABLE backup_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        backup_type TEXT NOT NULL DEFAULT 'Manual',
        created_at TEXT NOT NULL
      )
    ''');

    // 12. Notifications
    batch.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 13. Activity Logs
    batch.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await batch.commit(noResult: true);
    await _seedDefaultData(db);
  }

  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Akaunti chaguomsingi ya msimamizi: admin / admin123
    final defaultPasswordHash = _hashPassword('admin123');
    await db.insert('users', {
      'username': 'admin',
      'password_hash': defaultPasswordHash,
      'full_name': 'Msimamizi',
      'role': 'Admin',
      'created_at': now,
      'is_active': 1,
    });

    await db.insert('settings', {
      'business_name': 'Ales Masaba Animal Feed',
      'currency': 'TZS',
      'theme_mode': 'light',
    });

    final defaultCategories = ['Chakula cha Kuku', 'Chakula cha Ng\'ombe', 'Chakula cha Nguruwe', 'Madawa', 'Vifaa vya Mifugo'];
    for (final cat in defaultCategories) {
      await db.insert('categories', {'name': cat, 'created_at': now});
    }
  }

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

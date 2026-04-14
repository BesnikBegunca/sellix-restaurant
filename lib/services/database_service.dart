import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Central SQLite service — single source of truth for all persistent data.
///
/// All methods are async and return raw [Map] rows. Business-logic models are
/// built in [ManagerData] so this layer stays a pure data-access layer.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  // ──────────────────────────────── init ────────────────────────────────────

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_system.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tables (physical restaurant tables)
    await db.execute('''
      CREATE TABLE tables (
        id            INTEGER PRIMARY KEY,
        occupied      INTEGER NOT NULL DEFAULT 0,
        currentTotal  REAL
      )
    ''');

    // Menu categories
    await db.execute('''
      CREATE TABLE categories (
        id            TEXT    PRIMARY KEY,
        name          TEXT    NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        sortOrder     INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Menu products
    await db.execute('''
      CREATE TABLE products (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        price      REAL NOT NULL,
        emoji      TEXT NOT NULL DEFAULT '☕',
        imagePath  TEXT,
        categoryId TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // Waiters
    await db.execute('''
      CREATE TABLE waiters (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT    NOT NULL,
        pin  TEXT    NOT NULL UNIQUE
      )
    ''');

    // Sales — one row per completed payment
    await db.execute('''
      CREATE TABLE sales (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        waiterName TEXT    NOT NULL,
        tableId    INTEGER NOT NULL,
        total      REAL    NOT NULL,
        timestamp  TEXT    NOT NULL
      )
    ''');

    // Expenses / salaries
    await db.execute('''
      CREATE TABLE expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        type        TEXT NOT NULL,
        description TEXT NOT NULL,
        amount      REAL NOT NULL,
        timestamp   TEXT NOT NULL
      )
    ''');

    // Shift — single row (id = 1)
    await db.execute('''
      CREATE TABLE shift (
        id       INTEGER PRIMARY KEY,
        openedAt TEXT,
        closedAt TEXT,
        status   TEXT NOT NULL DEFAULT 'closed'
      )
    ''');

    // Company branding — single row (id = 1)
    await db.execute('''
      CREATE TABLE company (
        id          INTEGER PRIMARY KEY,
        companyName TEXT,
        companyLogo BLOB
      )
    ''');

    // Seed required singleton rows
    await db.insert('shift',   {'id': 1, 'status': 'closed'});
    await db.insert('company', {'id': 1});

    // Seed default 15 restaurant tables
    for (var i = 1; i <= 15; i++) {
      await db.insert('tables', {'id': i, 'occupied': 0, 'currentTotal': null});
    }

    // Seed default menu
    await _seedDefaultMenu(db);
  }

  Future<void> _seedDefaultMenu(Database db) async {
    final cats = [
      {
        'id': 'coffee',
        'name': 'Coffee',
        'iconCodePoint': Icons.local_cafe_outlined.codePoint,
        'sortOrder': 0,
      },
      {
        'id': 'spirits',
        'name': 'Spirits',
        'iconCodePoint': Icons.liquor_outlined.codePoint,
        'sortOrder': 1,
      },
      {
        'id': 'cocktails',
        'name': 'Cocktails',
        'iconCodePoint': Icons.local_bar_outlined.codePoint,
        'sortOrder': 2,
      },
      {
        'id': 'snack',
        'name': 'Snack',
        'iconCodePoint': Icons.cookie_outlined.codePoint,
        'sortOrder': 3,
      },
    ];
    for (final c in cats) {
      await db.insert('categories', c);
    }

    final products = [
      // Coffee
      {'id': 'c1', 'name': 'Espresso',   'price': 2.50, 'emoji': '☕', 'imagePath': 'assets/images/espreso.webp', 'categoryId': 'coffee'},
      {'id': 'c2', 'name': 'Macchiato',  'price': 4.00, 'emoji': '☕', 'imagePath': 'assets/images/makiato.png',  'categoryId': 'coffee'},
      {'id': 'c3', 'name': 'Cappuccino', 'price': 4.25, 'emoji': '☕', 'imagePath': 'assets/images/kapuqino.png', 'categoryId': 'coffee'},
      // Spirits
      {'id': 'sp9',  'name': 'Coca Cola', 'price': 2.50, 'emoji': '🥤', 'imagePath': 'assets/images/cocacola.png', 'categoryId': 'spirits'},
      {'id': 'sp10', 'name': 'Fanta',     'price': 2.50, 'emoji': '🥤', 'imagePath': 'assets/images/fanta.webp',   'categoryId': 'spirits'},
      {'id': 'sp11', 'name': 'Sprite',    'price': 2.50, 'emoji': '🥤', 'imagePath': 'assets/images/sprite.png',   'categoryId': 'spirits'},
      {'id': 'sp12', 'name': 'Heineken',  'price': 3.50, 'emoji': '🍺', 'imagePath': 'assets/images/heineken.png', 'categoryId': 'spirits'},
      {'id': 'sp13', 'name': 'Peja',      'price': 3.00, 'emoji': '🍺', 'imagePath': 'assets/images/peja.png',     'categoryId': 'spirits'},
      {'id': 'sp14', 'name': 'Shkupi',    'price': 3.00, 'emoji': '🍺', 'imagePath': 'assets/images/shkupi.png',   'categoryId': 'spirits'},
      {'id': 'sp15', 'name': 'Tuborg',    'price': 3.50, 'emoji': '🍺', 'imagePath': 'assets/images/tuborg.png',   'categoryId': 'spirits'},
      // Cocktails
      {'id': 'ck1', 'name': 'Mojito',        'price': 9.00,  'emoji': '🍹', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck2', 'name': 'Margarita',     'price': 9.50,  'emoji': '🍸', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck3', 'name': 'Martini',       'price': 10.00, 'emoji': '🍸', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck4', 'name': 'Cosmopolitan',  'price': 9.75,  'emoji': '🍸', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck5', 'name': 'Old Fashioned', 'price': 10.50, 'emoji': '🥃', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck6', 'name': 'Negroni',       'price': 10.00, 'emoji': '🍹', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck7', 'name': 'Aperol Spritz', 'price': 9.25,  'emoji': '🧡', 'imagePath': null, 'categoryId': 'cocktails'},
      {'id': 'ck8', 'name': 'Moscow Mule',   'price': 9.00,  'emoji': '🫚', 'imagePath': null, 'categoryId': 'cocktails'},
      // Snack
      {'id': 's1', 'name': 'Croissant', 'price': 3.50, 'emoji': '🥐', 'imagePath': null, 'categoryId': 'snack'},
      {'id': 's2', 'name': 'Muffin',    'price': 3.00, 'emoji': '🧁', 'imagePath': null, 'categoryId': 'snack'},
      {'id': 's3', 'name': 'Bagel',     'price': 2.75, 'emoji': '🥯', 'imagePath': null, 'categoryId': 'snack'},
      {'id': 's4', 'name': 'Brownie',   'price': 3.25, 'emoji': '🍫', 'imagePath': null, 'categoryId': 'snack'},
    ];
    for (final p in products) {
      await db.insert('products', p);
    }
  }

  // ──────────────────────────── TABLES ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchTables() async {
    final db = await database;
    return db.query('tables', orderBy: 'id ASC');
  }

  Future<void> insertTable(int id) async {
    final db = await database;
    await db.insert(
      'tables',
      {'id': id, 'occupied': 0, 'currentTotal': null},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateTable(
    int id, {
    required bool occupied,
    double? currentTotal,
  }) async {
    final db = await database;
    await db.update(
      'tables',
      {'occupied': occupied ? 1 : 0, 'currentTotal': currentTotal},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTable(int id) async {
    final db = await database;
    await db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────── CATEGORIES ───────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'sortOrder ASC, rowid ASC');
  }

  Future<void> insertCategory({
    required String id,
    required String name,
    required int iconCodePoint,
    required int sortOrder,
  }) async {
    final db = await database;
    await db.insert('categories', {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'sortOrder': sortOrder,
    });
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    // Products with this categoryId are deleted by the ON DELETE CASCADE FK.
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────── PRODUCTS ────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final db = await database;
    return db.query('products', orderBy: 'categoryId ASC, rowid ASC');
  }

  Future<void> insertProduct({
    required String id,
    required String name,
    required double price,
    required String emoji,
    String? imagePath,
    required String categoryId,
  }) async {
    final db = await database;
    await db.insert('products', {
      'id': id,
      'name': name,
      'price': price,
      'emoji': emoji,
      'imagePath': imagePath,
      'categoryId': categoryId,
    });
  }

  Future<void> updateProduct(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final db = await database;
    await db.update('products', fields, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveProductCategory(
    String productId,
    String newCategoryId,
  ) async {
    final db = await database;
    await db.update(
      'products',
      {'categoryId': newCategoryId},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ──────────────────────────── WAITERS ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWaiters() async {
    final db = await database;
    return db.query('waiters', orderBy: 'id ASC');
  }

  Future<int> insertWaiter(String name, String pin) async {
    final db = await database;
    return db.insert('waiters', {'name': name, 'pin': pin});
  }

  Future<void> deleteWaiterById(int id) async {
    final db = await database;
    await db.delete('waiters', where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────────── SALES ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSales() async {
    final db = await database;
    return db.query('sales', orderBy: 'timestamp DESC');
  }

  Future<void> insertSale({
    required String waiterName,
    required int tableId,
    required double total,
  }) async {
    final db = await database;
    await db.insert('sales', {
      'waiterName': waiterName,
      'tableId': tableId,
      'total': total,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearSales() async {
    final db = await database;
    await db.delete('sales');
  }

  // ─────────────────────────── EXPENSES ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final db = await database;
    return db.query('expenses', orderBy: 'timestamp DESC');
  }

  Future<int> insertExpense({
    required String type,
    required String description,
    required double amount,
    required DateTime date,
  }) async {
    final db = await database;
    return db.insert('expenses', {
      'type': type,
      'description': description,
      'amount': amount,
      'timestamp': date.toIso8601String(),
    });
  }

  Future<void> deleteExpenseById(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────── SHIFT ────────────────────────────────────

  Future<Map<String, dynamic>?> fetchShift() async {
    final db = await database;
    final rows = await db.query('shift', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateShift({
    String? openedAt,
    String? closedAt,
    required String status,
  }) async {
    final db = await database;
    await db.update(
      'shift',
      {'openedAt': openedAt, 'closedAt': closedAt, 'status': status},
      where: 'id = 1',
    );
  }

  // ─────────────────────────── COMPANY ──────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCompany() async {
    final db = await database;
    final rows = await db.query('company', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateCompanyName(String name) async {
    final db = await database;
    await db.update(
      'company',
      {'companyName': name},
      where: 'id = 1',
    );
  }

  Future<void> updateCompanyLogo(Uint8List? bytes) async {
    final db = await database;
    await db.update(
      'company',
      {'companyLogo': bytes},
      where: 'id = 1',
    );
  }
}

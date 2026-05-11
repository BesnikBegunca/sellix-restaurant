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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Ensures every table exists. Safe to call on any existing database because
  /// every statement uses CREATE TABLE IF NOT EXISTS.
  Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tables (
        id            INTEGER PRIMARY KEY,
        occupied      INTEGER NOT NULL DEFAULT 0,
        currentTotal  REAL,
        assignedWaiterName TEXT,
        currentOrderNumber INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id            TEXT    PRIMARY KEY,
        name          TEXT    NOT NULL,
        iconCodePoint INTEGER NOT NULL,
        sortOrder     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        price      REAL NOT NULL,
        emoji      TEXT NOT NULL DEFAULT '☕',
        imagePath  TEXT,
        categoryId TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waiters (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT    NOT NULL,
        pin  TEXT    NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        waiterName TEXT    NOT NULL,
        tableId    INTEGER NOT NULL,
        total      REAL    NOT NULL,
        timestamp  TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        type        TEXT NOT NULL,
        description TEXT NOT NULL,
        amount      REAL NOT NULL,
        timestamp   TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift (
        id       INTEGER PRIMARY KEY,
        openedAt TEXT,
        closedAt TEXT,
        status   TEXT NOT NULL DEFAULT 'closed'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company (
        id          INTEGER PRIMARY KEY,
        companyName TEXT,
        companyLogo BLOB,
        loginMode   TEXT NOT NULL DEFAULT 'PINMODE'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waiter_salaries (
        waiterName TEXT PRIMARY KEY,
        dailyRate  REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS advances (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        waiterName TEXT NOT NULL,
        amount     REAL NOT NULL,
        note       TEXT NOT NULL DEFAULT '',
        timestamp  TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waiter_worked_days (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        waiterName TEXT NOT NULL,
        workDate   TEXT NOT NULL,
        UNIQUE(waiterName, workDate)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_orders (
        tableId      INTEGER PRIMARY KEY,
        waiterName   TEXT NOT NULL,
        orderNumber  INTEGER NOT NULL,
        updatedAt    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_order_lines (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        tableId       INTEGER NOT NULL,
        productId     TEXT NOT NULL,
        productName   TEXT NOT NULL,
        productPrice  REAL NOT NULL,
        productEmoji  TEXT NOT NULL DEFAULT '☕',
        imagePath     TEXT,
        qty           INTEGER NOT NULL
      )
    ''');
  }

  /// Called when upgrading from any older version. Creates missing tables and
  /// inserts singleton rows that may not exist yet.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureTables(db);
    // Backward compatible columns for older `tables` schemas.
    try {
      await db.execute("ALTER TABLE tables ADD COLUMN assignedWaiterName TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE tables ADD COLUMN currentOrderNumber INTEGER");
    } catch (_) {}
    // Insert singleton rows only if they are missing.
    final shiftRows = await db.query('shift', where: 'id = 1');
    if (shiftRows.isEmpty) {
      await db.insert('shift', {'id': 1, 'status': 'closed'});
    }
    final companyRows = await db.query('company', where: 'id = 1');
    if (companyRows.isEmpty) {
      await db.insert('company', {'id': 1});
    }
    // Seed default tables if none exist.
    final tableCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tables'),
    );
    if (tableCount == 0) {
      for (var i = 1; i <= 15; i++) {
        await db.insert('tables', {
          'id': i,
          'occupied': 0,
          'currentTotal': null,
        });
      }
    }
    // Seed default menu if no categories exist.
    final catCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if (catCount == 0) {
      await _seedDefaultMenu(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _ensureTables(db);

    // Seed required singleton rows
    await db.insert('shift', {'id': 1, 'status': 'closed'});
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
      {
        'id': 'c1',
        'name': 'Espresso',
        'price': 2.50,
        'emoji': '☕',
        'imagePath': 'assets/images/espreso.webp',
        'categoryId': 'coffee',
      },
      {
        'id': 'c2',
        'name': 'Macchiato',
        'price': 4.00,
        'emoji': '☕',
        'imagePath': 'assets/images/makiato.png',
        'categoryId': 'coffee',
      },
      {
        'id': 'c3',
        'name': 'Cappuccino',
        'price': 4.25,
        'emoji': '☕',
        'imagePath': 'assets/images/kapuqino.png',
        'categoryId': 'coffee',
      },
      // Spirits
      {
        'id': 'sp9',
        'name': 'Coca Cola',
        'price': 2.50,
        'emoji': '🥤',
        'imagePath': 'assets/images/cocacola.png',
        'categoryId': 'spirits',
      },
      {
        'id': 'sp10',
        'name': 'Fanta',
        'price': 2.50,
        'emoji': '🥤',
        'imagePath': 'assets/images/fanta.webp',
        'categoryId': 'spirits',
      },
      {
        'id': 'sp11',
        'name': 'Sprite',
        'price': 2.50,
        'emoji': '🥤',
        'imagePath': 'assets/images/sprite.png',
        'categoryId': 'spirits',
      },
      {
        'id': 'sp12',
        'name': 'Heineken',
        'price': 3.50,
        'emoji': '🍺',
        'imagePath': 'assets/images/heineken.png',
        'categoryId': 'spirits',
      },
      {
        'id': 'sp13',
        'name': 'Peja',
        'price': 3.00,
        'emoji': '🍺',
        'imagePath': 'assets/images/peja.png',
        'categoryId': 'spirits',
      },
      {
        'id': 'sp14',
        'name': 'Shkupi',
        'price': 3.00,
        'emoji': '🍺',
        'imagePath': 'assets/images/shkupi.png',
        'categoryId': 'spirits',
      },
      {
        'id': 'sp15',
        'name': 'Tuborg',
        'price': 3.50,
        'emoji': '🍺',
        'imagePath': 'assets/images/tuborg.png',
        'categoryId': 'spirits',
      },
      // Cocktails
      {
        'id': 'ck1',
        'name': 'Mojito',
        'price': 9.00,
        'emoji': '🍹',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck2',
        'name': 'Margarita',
        'price': 9.50,
        'emoji': '🍸',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck3',
        'name': 'Martini',
        'price': 10.00,
        'emoji': '🍸',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck4',
        'name': 'Cosmopolitan',
        'price': 9.75,
        'emoji': '🍸',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck5',
        'name': 'Old Fashioned',
        'price': 10.50,
        'emoji': '🥃',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck6',
        'name': 'Negroni',
        'price': 10.00,
        'emoji': '🍹',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck7',
        'name': 'Aperol Spritz',
        'price': 9.25,
        'emoji': '🧡',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      {
        'id': 'ck8',
        'name': 'Moscow Mule',
        'price': 9.00,
        'emoji': '🫚',
        'imagePath': null,
        'categoryId': 'cocktails',
      },
      // Snack
      {
        'id': 's1',
        'name': 'Croissant',
        'price': 3.50,
        'emoji': '🥐',
        'imagePath': null,
        'categoryId': 'snack',
      },
      {
        'id': 's2',
        'name': 'Muffin',
        'price': 3.00,
        'emoji': '🧁',
        'imagePath': null,
        'categoryId': 'snack',
      },
      {
        'id': 's3',
        'name': 'Bagel',
        'price': 2.75,
        'emoji': '🥯',
        'imagePath': null,
        'categoryId': 'snack',
      },
      {
        'id': 's4',
        'name': 'Brownie',
        'price': 3.25,
        'emoji': '🍫',
        'imagePath': null,
        'categoryId': 'snack',
      },
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
    await db.insert('tables', {
      'id': id,
      'occupied': 0,
      'currentTotal': null,
      'assignedWaiterName': null,
      'currentOrderNumber': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateTable(
    int id, {
    required bool occupied,
    double? currentTotal,
    String? assignedWaiterName,
    int? currentOrderNumber,
  }) async {
    final db = await database;
    await db.update(
      'tables',
      {
        'occupied': occupied ? 1 : 0,
        'currentTotal': currentTotal,
        'assignedWaiterName': assignedWaiterName,
        'currentOrderNumber': currentOrderNumber,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTable(int id) async {
    final db = await database;
    await db.delete('current_orders', where: 'tableId = ?', whereArgs: [id]);
    await db.delete(
      'current_order_lines',
      where: 'tableId = ?',
      whereArgs: [id],
    );
    await db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertCurrentOrderMeta({
    required int tableId,
    required String waiterName,
    required int orderNumber,
  }) async {
    final db = await database;
    await db.insert('current_orders', {
      'tableId': tableId,
      'waiterName': waiterName,
      'orderNumber': orderNumber,
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> fetchCurrentOrderMeta(int tableId) async {
    final db = await database;
    final rows = await db.query(
      'current_orders',
      where: 'tableId = ?',
      whereArgs: [tableId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> replaceCurrentOrderLines(
    int tableId,
    List<Map<String, dynamic>> lines,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'current_order_lines',
        where: 'tableId = ?',
        whereArgs: [tableId],
      );
      for (final line in lines) {
        await txn.insert('current_order_lines', {
          'tableId': tableId,
          'productId': line['productId'],
          'productName': line['productName'],
          'productPrice': line['productPrice'],
          'productEmoji': line['productEmoji'],
          'imagePath': line['imagePath'],
          'qty': line['qty'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchCurrentOrderLines(int tableId) async {
    final db = await database;
    return db.query(
      'current_order_lines',
      where: 'tableId = ?',
      whereArgs: [tableId],
      orderBy: 'id ASC',
    );
  }

  Future<void> clearCurrentOrder(int tableId) async {
    final db = await database;
    await db.delete('current_orders', where: 'tableId = ?', whereArgs: [tableId]);
    await db.delete(
      'current_order_lines',
      where: 'tableId = ?',
      whereArgs: [tableId],
    );
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

  Future<void> updateProduct(String id, Map<String, dynamic> fields) async {
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
    await db.update('shift', {
      'openedAt': openedAt,
      'closedAt': closedAt,
      'status': status,
    }, where: 'id = 1');
  }

  // ─────────────────────────── COMPANY ──────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCompany() async {
    final db = await database;
    final rows = await db.query('company', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateCompanyName(String name) async {
    final db = await database;
    await db.update('company', {'companyName': name}, where: 'id = 1');
  }

  Future<void> updateCompanyLogo(Uint8List? bytes) async {
    final db = await database;
    await db.update('company', {'companyLogo': bytes}, where: 'id = 1');
  }

  Future<void> updateCompanyPrinterName(String printerName) async {
    final db = await database;

    // Backward compatible: oudere DB may not have the column.
    try {
      await db.update('company', {'printerName': printerName}, where: 'id = 1');
    } catch (_) {
      await db.execute("ALTER TABLE company ADD COLUMN printerName TEXT");
      await db.update('company', {'printerName': printerName}, where: 'id = 1');
    }
  }

  Future<String> fetchLoginMode() async {
    final db = await database;
    final rows = await db.query('company', where: 'id = 1');
    if (rows.isEmpty) return 'PINMODE';
    return (rows.first['loginMode'] as String?) ?? 'PINMODE';
  }

  Future<void> updateLoginMode(String mode) async {
    final db = await database;

    // Backward compatible: older DBs may not have `company.loginMode`.
    // If missing, recreate the column via ALTER TABLE.
    try {
      await db.update('company', {'loginMode': mode}, where: 'id = 1');
    } catch (e) {
      // Best-effort schema repair.
      await db.execute(
        "ALTER TABLE company ADD COLUMN loginMode TEXT NOT NULL DEFAULT 'PINMODE'",
      );
      await db.update('company', {'loginMode': mode}, where: 'id = 1');
    }
  }

  // ─────────────────────── WAITER SALARIES ──────────────────────────────────

  Future<Map<String, double>> fetchAllSalaries() async {
    final db = await database;
    final rows = await db.query('waiter_salaries');
    return {
      for (final r in rows)
        r['waiterName'] as String: (r['dailyRate'] as num).toDouble(),
    };
  }

  Future<void> upsertWaiterSalary(String waiterName, double dailyRate) async {
    final db = await database;
    await db.insert('waiter_salaries', {
      'waiterName': waiterName,
      'dailyRate': dailyRate,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ───────────────────────── ADVANCES ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAdvances() async {
    final db = await database;
    return db.query('advances', orderBy: 'timestamp DESC');
  }

  Future<int> insertAdvance({
    required String waiterName,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final db = await database;
    return db.insert('advances', {
      'waiterName': waiterName,
      'amount': amount,
      'note': note,
      'timestamp': date.toIso8601String(),
    });
  }

  Future<void> deleteAdvanceById(int id) async {
    final db = await database;
    await db.delete('advances', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────── WORKED DAYS ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWorkedDays() async {
    final db = await database;
    return db.query('waiter_worked_days');
  }

  Future<void> setWorkedDay(String waiterName, String date, bool worked) async {
    final db = await database;
    if (worked) {
      await db.insert('waiter_worked_days', {
        'waiterName': waiterName,
        'workDate': date,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'waiter_worked_days',
        where: 'waiterName = ? AND workDate = ?',
        whereArgs: [waiterName, date],
      );
    }
  }
}

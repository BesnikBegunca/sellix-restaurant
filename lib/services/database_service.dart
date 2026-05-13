import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

  /// Closes the database connection and clears the cached instance so that the
  /// next access to [database] triggers a fresh [_initDB] call.
  ///
  /// Called by [RestoreService] before replacing the database file.
  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// Re-opens the database after [closeDatabase] was called.
  ///
  /// If the file was upgraded (restore of an older backup), sqflite's
  /// [onUpgrade] callback fires automatically and brings the schema up to date.
  Future<void> reopenDatabase() async {
    _db ??= await _initDB();
  }

  /// Creates a consistent copy of the database using SQLite's VACUUM INTO
  /// (available since SQLite 3.27.0, February 2019).
  ///
  /// VACUUM INTO is safer than a raw file copy because it:
  /// - Produces a defragmented, single-file snapshot even in WAL mode
  /// - Reads only committed data (no dirty pages)
  /// - Never modifies the source database
  ///
  /// Returns [true] on success.  Returns [false] if the SQLite version is too
  /// old to support VACUUM INTO — the caller should fall back to a file copy.
  Future<bool> vacuumInto(String destPath) async {
    final db = await database;
    try {
      // Single-quote escape for the path literal (standard SQLite escaping).
      final safe = destPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$safe'");
      return true;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────── init ────────────────────────────────────

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_system.db');
    return openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await _ensureShiftsSnapshotColumn(db);
      },
    );
  }

  /// Kolona [snapshotJson] në [shifts] u shtua më vonë; bazat në v12 pa këtë
  /// kolonë dështojnë në UPDATE. Sigurohemi në çdo hapje lidhjeje (pa u varur
  /// nga ri-migrimi i versionit).
  Future<void> _ensureShiftsSnapshotColumn(Database db) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info(shifts)');
      if (cols.isEmpty) return;
      final has = cols.any(
        (r) => (r['name'] as String?) == 'snapshotJson',
      );
      if (!has) {
        await db.execute(
          'ALTER TABLE shifts ADD COLUMN snapshotJson TEXT',
        );
      }
    } catch (_) {}
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
        timestamp  TEXT    NOT NULL,
        shiftId    INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        type        TEXT NOT NULL,
        description TEXT NOT NULL,
        amount      REAL NOT NULL,
        timestamp   TEXT NOT NULL,
        shiftId     INTEGER
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
        id                 INTEGER PRIMARY KEY,
        companyName        TEXT,
        companyLogo        BLOB,
        loginMode          TEXT    NOT NULL DEFAULT 'PINMODE',
        printerName        TEXT,
        useEscPos          INTEGER NOT NULL DEFAULT 1,
        cashDrawerEnabled  INTEGER NOT NULL DEFAULT 0,
        paperWidthMm       INTEGER NOT NULL DEFAULT 80,
        receiptFooter      TEXT    NOT NULL DEFAULT 'Ju Faleminderit!',
        businessAddress    TEXT,
        businessPhone      TEXT
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
        tableId      INTEGER NOT NULL,
        waiterName   TEXT NOT NULL,
        orderNumber  INTEGER NOT NULL,
        currentTotal REAL NOT NULL DEFAULT 0,
        updatedAt    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_order_lines (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        tableId       INTEGER NOT NULL,
        waiterName    TEXT NOT NULL DEFAULT '',
        productId     TEXT NOT NULL,
        productName   TEXT NOT NULL,
        productPrice  REAL NOT NULL,
        productEmoji  TEXT NOT NULL DEFAULT '☕',
        imagePath     TEXT,
        qty           INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_lines (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId           INTEGER NOT NULL,
        productId        TEXT,
        productName      TEXT    NOT NULL,
        productEmoji     TEXT    NOT NULL DEFAULT '☕',
        productImagePath TEXT,
        productPrice     REAL    NOT NULL,
        quantity         INTEGER NOT NULL,
        lineTotal        REAL    NOT NULL,
        categoryName     TEXT,
        tableName        TEXT,
        waiterName       TEXT,
        createdAt        TEXT    NOT NULL,
        FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        openedAt       TEXT    NOT NULL,
        closedAt       TEXT,
        openedBy       TEXT,
        closedBy       TEXT,
        openingCash    REAL    NOT NULL DEFAULT 0,
        closingCash    REAL,
        totalSales     REAL    NOT NULL DEFAULT 0,
        totalExpenses  REAL    NOT NULL DEFAULT 0,
        netProfit      REAL    NOT NULL DEFAULT 0,
        status         TEXT    NOT NULL DEFAULT 'open',
        snapshotJson   TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_adjustments (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId         INTEGER NOT NULL,
        saleLineId     INTEGER,
        adjustmentType TEXT    NOT NULL,
        productName    TEXT,
        quantity       INTEGER,
        amount         REAL    NOT NULL,
        reason         TEXT,
        createdBy      TEXT,
        createdAt      TEXT    NOT NULL,
        FOREIGN KEY (saleId) REFERENCES sales(id)
      )
    ''');
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_current_orders_waiter_table ON current_orders(waiterName, tableId)',
      );
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE current_order_lines ADD COLUMN waiterName TEXT NOT NULL DEFAULT ''",
      );
    } catch (_) {}

    // ── Audit log table (append-only, tamper-resistant) ──────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        actionType    TEXT    NOT NULL,
        entityType    TEXT,
        entityId      TEXT,
        performedBy   TEXT,
        performedRole TEXT,
        shiftId       INTEGER,
        saleId        INTEGER,
        tableId       INTEGER,
        detailsJson   TEXT,
        createdAt     TEXT    NOT NULL,
        prevHash      TEXT,
        rowHash       TEXT,
        deviceId      TEXT,
        sessionId     TEXT,
        terminalName  TEXT,
        appVersion    TEXT,
        platform      TEXT
      )
    ''');

    // ── Immutability triggers — block UPDATE/DELETE at DB level ───────────────
    try {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_audit_no_update
        BEFORE UPDATE ON audit_logs
        BEGIN
          SELECT RAISE(FAIL, 'audit_logs is immutable: UPDATE not permitted');
        END
      ''');
    } catch (_) {}
    try {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_audit_no_delete
        BEFORE DELETE ON audit_logs
        BEGIN
          SELECT RAISE(FAIL, 'audit_logs is immutable: DELETE not permitted');
        END
      ''');
    } catch (_) {}

    // ── Performance indexes ───────────────────────────────────────────────────
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_created_at   ON audit_logs(createdAt DESC)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_action_type  ON audit_logs(actionType)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_performed_by ON audit_logs(performedBy)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_sale_id      ON audit_logs(saleId)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_shift_id     ON audit_logs(shiftId)',
      );
    } catch (_) {}
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_table_id     ON audit_logs(tableId)',
      );
    } catch (_) {}
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
    try {
      await db.execute("ALTER TABLE current_orders ADD COLUMN currentTotal REAL NOT NULL DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_current_orders_waiter_table ON current_orders(waiterName, tableId)',
      );
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE sales ADD COLUMN shiftId INTEGER");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE expenses ADD COLUMN shiftId INTEGER");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE shifts ADD COLUMN snapshotJson TEXT');
    } catch (_) {}
    // audit_logs new columns (v10 → v11 migration; safe no-op on fresh DBs)
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN prevHash TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN rowHash TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN deviceId TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN sessionId TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN terminalName TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN appVersion TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE audit_logs ADD COLUMN platform TEXT");
    } catch (_) {}
    // v12: new ESC/POS + receipt settings columns on company table
    try {
      await db.execute("ALTER TABLE company ADD COLUMN printerName TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN useEscPos INTEGER NOT NULL DEFAULT 1");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN cashDrawerEnabled INTEGER NOT NULL DEFAULT 0");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN paperWidthMm INTEGER NOT NULL DEFAULT 80");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN receiptFooter TEXT NOT NULL DEFAULT 'Ju Faleminderit!'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN businessAddress TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN businessPhone TEXT");
    } catch (_) {}
    await db.insert('app_meta', {
      'key': 'global_order_number',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
    await db.insert('app_meta', {
      'key': 'global_order_number',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

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
    required double currentTotal,
  }) async {
    final db = await database;
    await db.insert('current_orders', {
      'tableId': tableId,
      'waiterName': waiterName,
      'orderNumber': orderNumber,
      'currentTotal': currentTotal,
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> fetchCurrentOrderMeta(
    int tableId,
    String waiterName,
  ) async {
    final db = await database;
    final rows = await db.query(
      'current_orders',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> fetchCurrentOrderMetasForWaiter(
    String waiterName,
  ) async {
    final db = await database;
    return db.query(
      'current_orders',
      where: 'waiterName = ?',
      whereArgs: [waiterName],
    );
  }

  Future<void> replaceCurrentOrderLines(
    int tableId,
    String waiterName,
    List<Map<String, dynamic>> lines,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'current_order_lines',
        where: 'tableId = ? AND waiterName = ?',
        whereArgs: [tableId, waiterName],
      );
      for (final line in lines) {
        await txn.insert('current_order_lines', {
          'tableId': tableId,
          'waiterName': waiterName,
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

  Future<List<Map<String, dynamic>>> fetchCurrentOrderLines(
    int tableId,
    String waiterName,
  ) async {
    final db = await database;
    return db.query(
      'current_order_lines',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
      orderBy: 'id ASC',
    );
  }

  Future<void> clearCurrentOrder(int tableId, String waiterName) async {
    final db = await database;
    await db.delete(
      'current_orders',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
    );
    await db.delete(
      'current_order_lines',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
    );
  }

  Future<void> clearAllCurrentOrdersAndResetTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('current_orders');
      await txn.delete('current_order_lines');
      await txn.update('tables', {
        'occupied': 0,
        'currentTotal': null,
        'assignedWaiterName': null,
        'currentOrderNumber': 0,
      });
    });
  }

  Future<int> consumeNextGlobalOrderNumber() async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['global_order_number'],
        limit: 1,
      );
      final raw = rows.isEmpty ? '0' : rows.first['value']?.toString() ?? '0';
      final current = int.tryParse(raw) ?? 0;
      final next = current + 1;
      await txn.insert('app_meta', {
        'key': 'global_order_number',
        'value': next.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return next;
    });
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
    int? shiftId,
  }) async {
    final db = await database;
    await db.insert('sales', {
      'waiterName': waiterName,
      'tableId': tableId,
      'total': total,
      'timestamp': DateTime.now().toIso8601String(),
      if (shiftId != null) 'shiftId': shiftId,
    });
  }

  Future<void> clearSales() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_lines');
      await txn.delete('sales');
    });
  }

  // ──────────────────────────── SALE LINES ──────────────────────────────────

  /// Inserts a sale header + its line items atomically.
  /// Returns the new sale row's primary key.
  /// Rolls back automatically if any insert fails.
  Future<int> insertSaleWithLines({
    required String waiterName,
    required int tableId,
    required double total,
    required List<Map<String, dynamic>> lines,
    int? shiftId,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final timestamp = DateTime.now().toIso8601String();
      final saleId = await txn.insert('sales', {
        'waiterName': waiterName,
        'tableId': tableId,
        'total': total,
        'timestamp': timestamp,
        'shiftId': shiftId,
      });
      for (final line in lines) {
        await txn.insert('sale_lines', {
          'saleId': saleId,
          'productId': line['productId'],
          'productName': line['productName'],
          'productEmoji': line['productEmoji'] ?? '☕',
          'productImagePath': line['productImagePath'],
          'productPrice': line['productPrice'],
          'quantity': line['quantity'],
          'lineTotal': line['lineTotal'],
          'categoryName': line['categoryName'],
          'tableName': line['tableName'],
          'waiterName': line['waiterName'],
          'createdAt': timestamp,
        });
      }
      return saleId;
    });
  }

  /// Returns all sale_lines for a single sale, ordered by insertion order.
  Future<List<Map<String, dynamic>>> fetchSaleLines(int saleId) async {
    final db = await database;
    return db.query(
      'sale_lines',
      where: 'saleId = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
  }

  /// Batch-fetches all sale_lines whose saleId is in [saleIds].
  /// Returns an empty list when [saleIds] is empty (avoids malformed SQL).
  Future<List<Map<String, dynamic>>> fetchSaleLinesForSales(
    List<int> saleIds,
  ) async {
    if (saleIds.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(saleIds.length, '?').join(',');
    return db.rawQuery(
      'SELECT * FROM sale_lines WHERE saleId IN ($placeholders) ORDER BY saleId ASC, id ASC',
      saleIds,
    );
  }

  /// Returns sales matching optional date, waiter, table, and ID filters.
  Future<List<Map<String, dynamic>>> fetchFilteredSales({
    DateTime? from,
    DateTime? to,
    String? waiterName,
    int? tableId,
    int? saleId,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.toIso8601String());
    }
    if (waiterName != null && waiterName.isNotEmpty) {
      where.add('waiterName = ?');
      args.add(waiterName);
    }
    if (tableId != null) {
      where.add('tableId = ?');
      args.add(tableId);
    }
    if (saleId != null) {
      where.add('id = ?');
      args.add(saleId);
    }
    return db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
    );
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
    int? shiftId,
  }) async {
    final db = await database;
    return db.insert('expenses', {
      'type': type,
      'description': description,
      'amount': amount,
      'timestamp': date.toIso8601String(),
      'shiftId': shiftId,
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

  /// Update any subset of ESC/POS + receipt settings in the company row.
  Future<void> updateEscPosSettings({
    bool? useEscPos,
    bool? cashDrawerEnabled,
    int? paperWidthMm,
    String? receiptFooter,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final db = await database;
    final map = <String, Object?>{};
    if (useEscPos != null)         map['useEscPos']         = useEscPos ? 1 : 0;
    if (cashDrawerEnabled != null) map['cashDrawerEnabled'] = cashDrawerEnabled ? 1 : 0;
    if (paperWidthMm != null)      map['paperWidthMm']      = paperWidthMm;
    if (receiptFooter != null)     map['receiptFooter']     = receiptFooter;
    if (businessAddress != null)   map['businessAddress']   = businessAddress;
    if (businessPhone != null)     map['businessPhone']     = businessPhone;
    if (map.isEmpty) return;
    await db.update('company', map, where: 'id = 1');
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

  // ─────────────────────────── SHIFTS (permanent archive) ───────────────────

  /// Opens a new shift record and returns its primary key.
  Future<int> insertShiftRecord({
    required DateTime openedAt,
    String? openedBy,
    double openingCash = 0,
  }) async {
    final db = await database;
    return db.insert('shifts', {
      'openedAt': openedAt.toIso8601String(),
      'openedBy': openedBy,
      'openingCash': openingCash,
      'status': 'open',
    });
  }

  /// Archives a shift by writing the closing summary. Does not delete any data.
  Future<void> closeShiftRecord({
    required int shiftId,
    required DateTime closedAt,
    String? closedBy,
    double? closingCash,
    required double totalSales,
    required double totalExpenses,
    required double netProfit,
    String? snapshotJson,
  }) async {
    final db = await database;
    await _ensureShiftsSnapshotColumn(db);
    final row = <String, Object?>{
      'closedAt': closedAt.toIso8601String(),
      'closedBy': closedBy,
      'closingCash': closingCash,
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'status': 'closed',
    };
    if (snapshotJson != null) {
      row['snapshotJson'] = snapshotJson;
    }
    await db.update(
      'shifts',
      row,
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  /// Shuma e [currentTotal] për çdo kamarier (porosi të hapura në tavolina).
  Future<Map<String, double>> fetchCurrentOrderTotalsByWaiter() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT TRIM(waiterName) AS w, SUM(currentTotal) AS t
      FROM current_orders
      GROUP BY TRIM(waiterName)
    ''');
    final out = <String, double>{};
    for (final r in rows) {
      var name = (r['w'] as String?)?.trim() ?? '';
      if (name.isEmpty) name = 'Panjohur';
      out[name] = (r['t'] as num?)?.toDouble() ?? 0;
    }
    return out;
  }

  /// Numri i rreshtave në [current_orders] për çdo kamarier.
  Future<Map<String, int>> fetchCurrentOrderCountsByWaiter() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT TRIM(waiterName) AS w, COUNT(*) AS c
      FROM current_orders
      GROUP BY TRIM(waiterName)
    ''');
    final out = <String, int>{};
    for (final r in rows) {
      var name = (r['w'] as String?)?.trim() ?? '';
      if (name.isEmpty) name = 'Panjohur';
      out[name] = (r['c'] as num?)?.toInt() ?? 0;
    }
    return out;
  }

  /// Returns the most recently opened shift with status='open', or null.
  Future<Map<String, dynamic>?> fetchOpenShift() async {
    final db = await database;
    final rows = await db.query(
      'shifts',
      where: "status = 'open'",
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Returns all shift records ordered newest-first.
  Future<List<Map<String, dynamic>>> fetchAllShifts() async {
    final db = await database;
    return db.query('shifts', orderBy: 'id DESC');
  }

  // ─────────────────────── SALE ADJUSTMENTS ─────────────────────────────────

  /// Records a refund, void, or discount against an existing sale.
  Future<int> insertSaleAdjustment({
    required int saleId,
    int? saleLineId,
    required String adjustmentType,
    String? productName,
    int? quantity,
    required double amount,
    String? reason,
    String? createdBy,
  }) async {
    final db = await database;
    return db.insert('sale_adjustments', {
      'saleId': saleId,
      'saleLineId': saleLineId,
      'adjustmentType': adjustmentType,
      'productName': productName,
      'quantity': quantity,
      'amount': amount,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Batch-fetches all adjustments whose saleId is in [saleIds].
  Future<List<Map<String, dynamic>>> fetchAdjustmentsForSales(
    List<int> saleIds,
  ) async {
    if (saleIds.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(saleIds.length, '?').join(',');
    return db.rawQuery(
      'SELECT * FROM sale_adjustments WHERE saleId IN ($placeholders) ORDER BY saleId ASC, id ASC',
      saleIds,
    );
  }

  // ────────────────────────── APP META ──────────────────────────────────────

  Future<String?> getAppMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setAppMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─────────────────────────── AUDIT LOGS ───────────────────────────────────

  /// Appends one immutable audit log entry.
  ///
  /// Computes a SHA-256 hash chain: each row stores the previous row's hash
  /// ([prevHash]) and its own hash ([rowHash]) so gaps or edits are detectable.
  /// The entire SELECT + INSERT is wrapped in a transaction to guarantee
  /// sequential IDs and a coherent chain even under concurrent writes.
  Future<int> insertAuditLog({
    required String actionType,
    String? entityType,
    String? entityId,
    String? performedBy,
    String? performedRole,
    int? shiftId,
    int? saleId,
    int? tableId,
    String? detailsJson,
    String? deviceId,
    String? sessionId,
    String? terminalName,
    String? appVersion,
    String? platform,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // Fetch previous row hash to form the chain.
      final prevRows = await txn.rawQuery(
        'SELECT rowHash FROM audit_logs ORDER BY id DESC LIMIT 1',
      );
      final prevHash = prevRows.isEmpty
          ? 'genesis'
          : (prevRows.first['rowHash'] as String? ?? 'genesis');

      // Deterministic SHA-256 over the fields that matter for forensics.
      final hashInput = [
        actionType,
        entityType ?? '',
        entityId ?? '',
        performedBy ?? '',
        now,
        detailsJson ?? '',
        prevHash,
      ].join('|');
      final rowHash = sha256.convert(utf8.encode(hashInput)).toString();

      return txn.insert('audit_logs', {
        'actionType':   actionType,
        'entityType':   entityType,
        'entityId':     entityId,
        'performedBy':  performedBy,
        'performedRole': performedRole,
        'shiftId':      shiftId,
        'saleId':       saleId,
        'tableId':      tableId,
        'detailsJson':  detailsJson,
        'createdAt':    now,
        'prevHash':     prevHash,
        'rowHash':      rowHash,
        'deviceId':     deviceId,
        'sessionId':    sessionId,
        'terminalName': terminalName,
        'appVersion':   appVersion,
        'platform':     platform,
      });
    });
  }

  /// Fetches audit logs with optional filters, newest-first.
  Future<List<Map<String, dynamic>>> fetchAuditLogs({
    DateTime? from,
    DateTime? to,
    String? actionType,
    String? performedBy,
    int? shiftId,
    int? saleId,
    int? tableId,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      where.add('createdAt >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('createdAt <= ?');
      args.add(to.toIso8601String());
    }
    if (actionType != null && actionType.isNotEmpty) {
      where.add('actionType = ?');
      args.add(actionType);
    }
    if (performedBy != null && performedBy.isNotEmpty) {
      where.add('performedBy = ?');
      args.add(performedBy);
    }
    if (shiftId != null) {
      where.add('shiftId = ?');
      args.add(shiftId);
    }
    if (saleId != null) {
      where.add('saleId = ?');
      args.add(saleId);
    }
    if (tableId != null) {
      where.add('tableId = ?');
      args.add(tableId);
    }
    return db.query(
      'audit_logs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }
}

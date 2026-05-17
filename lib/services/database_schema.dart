import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Schema creation, migration, and seeding — extracted from [DatabaseService]
/// to keep the service class focused on data-access methods only.
class DatabaseSchema {
  DatabaseSchema._();

  // ── UUID v4 generator ────────────────────────────────────────────────────────

  /// Generates a RFC 4122 version-4 UUID using a cryptographically secure RNG.
  /// No external package required — uses only dart:math.
  static String generateUuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10xx
    String hex(int x) => x.toRadixString(16).padLeft(2, '0');
    return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}'
        '-${hex(b[4])}${hex(b[5])}'
        '-${hex(b[6])}${hex(b[7])}'
        '-${hex(b[8])}${hex(b[9])}'
        '-${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }

  // ── Backfill existing rows with UUIDs ─────────────────────────────────────

  /// Assigns UUID v4 to every row where uuid IS NULL.
  ///
  /// Uses SQLite's implicit rowid so it works for tables with any PK type
  /// (INTEGER AUTOINCREMENT, TEXT, or no explicit PK like current_orders).
  ///
  /// [audit_logs] is deliberately excluded: immutability triggers on that
  /// table block UPDATE statements at the database level.
  static Future<void> _backfillUuids(Database db) async {
    const tables = <String>[
      'sales', 'sale_lines', 'sale_adjustments', 'expenses', 'shifts',
      'products', 'categories', 'waiters', 'waiter_salaries', 'advances',
      'waiter_worked_days', 'current_orders', 'current_order_lines',
      'kitchen_prints', 'kitchen_print_lines',
    ];
    for (final table in tables) {
      try {
        final rows = await db.rawQuery(
          'SELECT rowid FROM "$table" WHERE uuid IS NULL',
        );
        if (rows.isEmpty) continue;
        await db.transaction((txn) async {
          for (final row in rows) {
            await txn.rawUpdate(
              'UPDATE "$table" SET uuid = ? WHERE rowid = ?',
              [generateUuid(), row['rowid']],
            );
          }
        });
      } catch (_) {}
    }
  }

  /// Kolona [snapshotJson] në [shifts] u shtua më vonë; bazat në v12 pa këtë
  /// kolonë dështojnë në UPDATE. Sigurohemi në çdo hapje lidhjeje (pa u varur
  /// nga ri-migrimi i versionit).
  static Future<void> ensureShiftsSnapshotColumn(Database db) async {
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
  static Future<void> ensureTables(Database db) async {
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
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        pin          TEXT    NOT NULL DEFAULT '',
        pinHash      TEXT,
        pinSalt      TEXT,
        pinUpdatedAt TEXT
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
        businessPhone      TEXT,
        adminPinHash       TEXT,
        adminPinSalt       TEXT,
        adminPinCreatedAt  TEXT,
        adminPinUpdatedAt  TEXT
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
      CREATE TABLE IF NOT EXISTS kitchen_prints (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        tableId      INTEGER NOT NULL,
        waiterName   TEXT    NOT NULL,
        orderNumber  INTEGER NOT NULL,
        total        REAL    NOT NULL,
        printedAt    TEXT    NOT NULL,
        shiftId      INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kitchen_print_lines (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        printId      INTEGER NOT NULL,
        productId    TEXT    NOT NULL,
        productName  TEXT    NOT NULL,
        productPrice REAL    NOT NULL,
        productEmoji TEXT    NOT NULL DEFAULT '☕',
        imagePath    TEXT,
        qty          INTEGER NOT NULL,
        lineTotal    REAL    NOT NULL,
        FOREIGN KEY (printId) REFERENCES kitchen_prints(id) ON DELETE CASCADE
      )
    ''');
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_kitchen_prints_waiter ON kitchen_prints(waiterName)',
      );
    } catch (_) {}
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

    // ── v17: uuid columns for cloud sync ──────────────────────────────────────
    const uuidTables = <String>[
      'sales', 'sale_lines', 'sale_adjustments', 'expenses', 'shifts',
      'products', 'categories', 'waiters', 'waiter_salaries', 'advances',
      'waiter_worked_days', 'audit_logs', 'current_orders', 'current_order_lines',
      'kitchen_prints', 'kitchen_print_lines',
    ];
    for (final t in uuidTables) {
      try {
        await db.execute('ALTER TABLE "$t" ADD COLUMN uuid TEXT');
      } catch (_) {}
    }
    for (final t in uuidTables) {
      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS "idx_${t}_uuid" '
          'ON "$t"(uuid) WHERE uuid IS NOT NULL',
        );
      } catch (_) {}
    }
  }

  /// Called when upgrading from any older version. Creates missing tables and
  /// inserts singleton rows that may not exist yet.
  static Future<void> upgrade(Database db, int oldVersion, int newVersion) async {
    await ensureTables(db);
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
    // v14: admin PIN storage (hash + salt)
    try {
      await db.execute("ALTER TABLE company ADD COLUMN adminPinHash TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN adminPinSalt TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN adminPinCreatedAt TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE company ADD COLUMN adminPinUpdatedAt TEXT");
    } catch (_) {}
    // v15: waiter PIN hashing (pinHash + pinSalt + pinUpdatedAt)
    try {
      await db.execute("ALTER TABLE waiters ADD COLUMN pinHash TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE waiters ADD COLUMN pinSalt TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE waiters ADD COLUMN pinUpdatedAt TEXT");
    } catch (_) {}
    // v16: clear plaintext from waiters.pin — replace with pinHash (maintains UNIQUE)
    try {
      await db.rawUpdate(
        "UPDATE waiters SET pin = pinHash WHERE pinHash IS NOT NULL AND pinSalt IS NOT NULL AND pin != pinHash",
      );
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
    // v17: backfill UUIDs for all existing rows (safe no-op on fresh DBs).
    await _backfillUuids(db);

    // Seed default menu if no categories exist.
    final catCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if (catCount == 0) {
      await seedDefaultMenu(db);
    }
  }

  static Future<void> create(Database db, int version) async {
    await ensureTables(db);

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
    await seedDefaultMenu(db);
  }

  static Future<void> seedDefaultMenu(Database db) async {
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
      await db.insert('categories', {...c, 'uuid': generateUuid()});
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
      await db.insert('products', {...p, 'uuid': generateUuid()});
    }
  }
}

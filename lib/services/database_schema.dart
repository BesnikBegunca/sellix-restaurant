import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

/// Schema creation, migration, and seeding — extracted from [DatabaseService]
/// to keep the service class focused on data-access methods only.
class DatabaseSchema {
  DatabaseSchema._();

  /// Placeholder until NestJS sync assigns real tenant IDs.
  static const String kLocalBusinessId = 'local-business';
  static const String kMainBranchId = 'main-branch';
  static const String kDeviceMetaKey = 'audit_device_id';
  static const String kSyncStatusPending = 'pending';
  static const String kOutboxSyncSynced = 'synced';
  static const String kOutboxSyncFailed = 'failed';

  static const List<String> outboxOperations = ['create', 'update', 'delete'];

  static const List<String> stockMovementTypes = [
    'purchase',
    'sale',
    'adjustment',
    'waste',
    'return',
  ];

  static const List<String> syncScopeTables = <String>[
    'sales', 'sale_lines', 'sale_adjustments', 'expenses', 'shifts',
    'products', 'categories', 'waiters', 'waiter_salaries', 'advances',
    'waiter_worked_days', 'audit_logs', 'current_orders', 'current_order_lines',
    'kitchen_prints', 'kitchen_print_lines',
  ];

  // ── Activated tenant IDs (updated by ActivationService at startup) ─────────

  static String _activatedBusinessId = kLocalBusinessId;
  static String _activatedBranchId   = kMainBranchId;

  /// Called by [ActivationService] once real tenant IDs are loaded from
  /// [app_meta]. Updates the in-memory values used by [syncScopeStamp] so
  /// all subsequent outbox inserts carry the correct businessId / branchId.
  static void setActivatedTenant({
    required String businessId,
    required String branchId,
  }) {
    _activatedBusinessId = businessId;
    _activatedBranchId   = branchId;
  }

  /// Stamp for new rows — uses activated tenant IDs when available,
  /// falls back to local placeholders on unactivated devices.
  static Map<String, String> syncScopeStamp(String deviceId) => {
        'businessId': _activatedBusinessId,
        'branchId':   _activatedBranchId,
        'deviceId':   deviceId,
      };

  /// Columns to ADD per table (skips names that already exist on the schema).
  static const Map<String, List<String>> syncTimestampAdds = {
    'sales': ['createdAt', 'updatedAt', 'deletedAt'],
    'sale_lines': ['updatedAt', 'deletedAt'],
    'sale_adjustments': ['updatedAt', 'deletedAt'],
    'expenses': ['createdAt', 'updatedAt', 'deletedAt'],
    'shifts': ['createdAt', 'updatedAt', 'deletedAt'],
    'products': ['createdAt', 'updatedAt', 'deletedAt'],
    'categories': ['createdAt', 'updatedAt', 'deletedAt'],
    'waiters': ['createdAt', 'updatedAt', 'deletedAt'],
    'waiter_salaries': ['createdAt', 'updatedAt', 'deletedAt'],
    'advances': ['createdAt', 'updatedAt', 'deletedAt'],
    'waiter_worked_days': ['createdAt', 'updatedAt', 'deletedAt'],
    'audit_logs': ['updatedAt', 'deletedAt'],
    'current_orders': ['createdAt', 'deletedAt'],
    'current_order_lines': ['createdAt', 'updatedAt', 'deletedAt'],
    'kitchen_prints': ['createdAt', 'updatedAt', 'deletedAt'],
    'kitchen_print_lines': ['createdAt', 'updatedAt', 'deletedAt'],
  };

  /// ISO-8601 createdAt + updatedAt for new sync-critical rows.
  static Map<String, String> syncTimestampStamp({
    bool includeCreatedAt = true,
    DateTime? when,
  }) {
    final iso = (when ?? DateTime.now()).toIso8601String();
    if (includeCreatedAt) {
      return {'createdAt': iso, 'updatedAt': iso};
    }
    return {'updatedAt': iso};
  }

  /// Default sync state for new or unmigrated rows.
  static Map<String, Object?> syncStatusStamp() => {
        'syncStatus': kSyncStatusPending,
        'lastSyncedAt': null,
      };

  /// Signed quantity change applied to [inventory_items.currentQuantity].
  static double stockQuantityDelta(String movementType, double quantity) {
    if (!stockMovementTypes.contains(movementType)) {
      throw ArgumentError.value(
        movementType,
        'movementType',
        'Must be one of: ${stockMovementTypes.join(', ')}',
      );
    }
    switch (movementType) {
      case 'purchase':
      case 'return':
        return quantity.abs();
      case 'sale':
      case 'waste':
        return -quantity.abs();
      case 'adjustment':
        return quantity;
      default:
        return quantity;
    }
  }

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

  /// Reads or creates the stable device UUID in [app_meta].
  static Future<String> resolveDeviceId(Database db) async {
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [kDeviceMetaKey],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = rows.first['value'] as String?;
      if (existing != null && existing.isNotEmpty) return existing;
    }
    final id = generateUuid();
    await db.insert(
      'app_meta',
      {'key': kDeviceMetaKey, 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  /// Backfills businessId / branchId / deviceId on all sync-critical rows.
  static Future<void> _backfillSyncScopeIds(Database db) async {
    final deviceId = await resolveDeviceId(db);
    for (final table in syncScopeTables) {
      if (table == 'audit_logs') continue;
      try {
        await db.rawUpdate(
          'UPDATE "$table" SET '
          'businessId = COALESCE(businessId, ?), '
          'branchId = COALESCE(branchId, ?), '
          'deviceId = COALESCE(deviceId, ?) '
          'WHERE businessId IS NULL OR branchId IS NULL OR deviceId IS NULL',
          [kLocalBusinessId, kMainBranchId, deviceId],
        );
      } catch (_) {}
    }
    await _backfillAuditLogsSyncScope(db, deviceId);
  }

  /// [audit_logs] is immutable — triggers must be dropped for one-time backfill.
  static Future<void> _backfillAuditLogsSyncScope(
    Database db,
    String deviceId,
  ) async {
    await _withAuditLogsUnlocked(db, () async {
      try {
        await db.rawUpdate(
          'UPDATE audit_logs SET '
          'businessId = COALESCE(businessId, ?), '
          'branchId = COALESCE(branchId, ?), '
          'deviceId = COALESCE(deviceId, ?) '
          'WHERE businessId IS NULL OR branchId IS NULL OR deviceId IS NULL',
          [kLocalBusinessId, kMainBranchId, deviceId],
        );
      } catch (_) {}
    });
  }

  static Future<void> _withAuditLogsUnlocked(
    Database db,
    Future<void> Function() action,
  ) async {
    try {
      await db.execute('DROP TRIGGER IF EXISTS trg_audit_no_update');
      await db.execute('DROP TRIGGER IF EXISTS trg_audit_no_delete');
      await action();
    } catch (_) {}
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
  }

  /// Backfills sync createdAt / updatedAt / deletedAt on existing rows.
  static Future<void> _backfillSyncTimestamps(Database db) async {
    final now = DateTime.now().toIso8601String();

    Future<void> run(String sql, [List<Object?>? args]) async {
      try {
        await db.rawUpdate(sql, args);
      } catch (_) {}
    }

    await run('''
      UPDATE sales SET
        createdAt = COALESCE(createdAt, timestamp),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, timestamp)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''');

    await run('''
      UPDATE sale_lines SET
        updatedAt = COALESCE(updatedAt, createdAt),
        deletedAt = NULL
      WHERE updatedAt IS NULL
    ''');

    await run('''
      UPDATE sale_adjustments SET
        updatedAt = COALESCE(updatedAt, createdAt),
        deletedAt = NULL
      WHERE updatedAt IS NULL
    ''');

    await run('''
      UPDATE expenses SET
        createdAt = COALESCE(createdAt, timestamp),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, timestamp)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''');

    await run('''
      UPDATE shifts SET
        createdAt = COALESCE(createdAt, openedAt),
        updatedAt = COALESCE(updatedAt, COALESCE(closedAt, openedAt)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''');

    for (final table in ['products', 'categories', 'waiter_salaries']) {
      await run('''
        UPDATE "$table" SET
          createdAt = COALESCE(createdAt, ?),
          updatedAt = COALESCE(updatedAt, COALESCE(createdAt, ?)),
          deletedAt = NULL
        WHERE createdAt IS NULL OR updatedAt IS NULL
      ''', [now, now]);
    }

    await run('''
      UPDATE waiters SET
        createdAt = COALESCE(createdAt, pinUpdatedAt, ?),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, pinUpdatedAt, ?)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''', [now, now]);

    await run('''
      UPDATE advances SET
        createdAt = COALESCE(createdAt, timestamp),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, timestamp)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''');

    await run('''
      UPDATE waiter_worked_days SET
        createdAt = COALESCE(createdAt, workDate),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, workDate)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''');

    await run('''
      UPDATE current_orders SET
        createdAt = COALESCE(createdAt, updatedAt),
        deletedAt = NULL
      WHERE createdAt IS NULL
    ''');

    await run('''
      UPDATE current_order_lines SET
        createdAt = COALESCE(createdAt, ?),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, ?)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''', [now, now]);

    await run('''
      UPDATE kitchen_prints SET
        createdAt = COALESCE(createdAt, printedAt),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, printedAt)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''');

    await run('''
      UPDATE kitchen_print_lines SET
        createdAt = COALESCE(createdAt, (
          SELECT printedAt FROM kitchen_prints
          WHERE kitchen_prints.id = kitchen_print_lines.printId
        ), ?),
        updatedAt = COALESCE(updatedAt, COALESCE(createdAt, ?)),
        deletedAt = NULL
      WHERE createdAt IS NULL OR updatedAt IS NULL
    ''', [now, now]);

    await _withAuditLogsUnlocked(db, () async {
      await run('''
        UPDATE audit_logs SET
          updatedAt = COALESCE(updatedAt, createdAt),
          deletedAt = NULL
        WHERE updatedAt IS NULL
      ''');
    });
  }

  /// Marks every row as locally pending upload (no sync engine yet).
  static Future<void> _backfillSyncStatus(Database db) async {
    for (final table in syncScopeTables) {
      if (table == 'audit_logs') continue;
      try {
        await db.rawUpdate(
          'UPDATE "$table" SET '
          'syncStatus = COALESCE(syncStatus, ?), '
          'lastSyncedAt = NULL '
          'WHERE syncStatus IS NULL',
          [kSyncStatusPending],
        );
      } catch (_) {}
    }
    await _withAuditLogsUnlocked(db, () async {
      try {
        await db.rawUpdate(
          'UPDATE audit_logs SET '
          'syncStatus = COALESCE(syncStatus, ?), '
          'lastSyncedAt = NULL '
          'WHERE syncStatus IS NULL',
          [kSyncStatusPending],
        );
      } catch (_) {}
    });
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

    // ── v18: businessId / branchId / deviceId for cloud sync ────────────────
    for (final t in syncScopeTables) {
      for (final col in ['businessId', 'branchId', 'deviceId']) {
        try {
          await db.execute('ALTER TABLE "$t" ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }

    // ── v19: createdAt / updatedAt / deletedAt for incremental sync ─────────
    for (final entry in syncTimestampAdds.entries) {
      for (final col in entry.value) {
        try {
          await db.execute(
            'ALTER TABLE "${entry.key}" ADD COLUMN $col TEXT',
          );
        } catch (_) {}
      }
    }

    // ── v20: syncStatus / lastSyncedAt for upload tracking ───────────────────
    for (final t in syncScopeTables) {
      for (final col in ['syncStatus', 'lastSyncedAt']) {
        try {
          await db.execute('ALTER TABLE "$t" ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }

    // ── v21: outbox queue for future sync engine ─────────────────────────────
    await ensureOutboxTable(db);

    // ── v22: inventory + stock movements ─────────────────────────────────────
    await ensureInventoryTables(db);
  }

  /// Creates [inventory_items] and [stock_movements] (idempotent).
  static Future<void> ensureInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid               TEXT    NOT NULL UNIQUE,
        businessId         TEXT    NOT NULL,
        branchId           TEXT    NOT NULL,
        deviceId           TEXT    NOT NULL,
        productUuid        TEXT,
        name               TEXT    NOT NULL,
        unit               TEXT    NOT NULL,
        currentQuantity    REAL    NOT NULL DEFAULT 0,
        lowStockThreshold  REAL    NOT NULL DEFAULT 0,
        costPerUnit        REAL    NOT NULL DEFAULT 0,
        isActive           INTEGER NOT NULL DEFAULT 1,
        createdAt          TEXT    NOT NULL,
        updatedAt          TEXT    NOT NULL,
        deletedAt          TEXT,
        syncStatus         TEXT    NOT NULL DEFAULT 'pending',
        lastSyncedAt       TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid               TEXT    NOT NULL UNIQUE,
        businessId         TEXT    NOT NULL,
        branchId           TEXT    NOT NULL,
        deviceId           TEXT    NOT NULL,
        inventoryItemUuid  TEXT    NOT NULL,
        movementType       TEXT    NOT NULL,
        quantity           REAL    NOT NULL,
        reason             TEXT,
        referenceType      TEXT,
        referenceUuid      TEXT,
        createdAt          TEXT    NOT NULL,
        updatedAt          TEXT    NOT NULL,
        deletedAt          TEXT,
        syncStatus         TEXT    NOT NULL DEFAULT 'pending',
        lastSyncedAt       TEXT
      )
    ''');
    for (final idx in [
      'CREATE INDEX IF NOT EXISTS idx_inventory_items_uuid ON inventory_items(uuid)',
      'CREATE INDEX IF NOT EXISTS idx_inventory_items_product_uuid ON inventory_items(productUuid)',
      'CREATE INDEX IF NOT EXISTS idx_inventory_items_is_active ON inventory_items(isActive)',
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_item_uuid ON stock_movements(inventoryItemUuid)',
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(movementType)',
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at ON stock_movements(createdAt)',
    ]) {
      try {
        await db.execute(idx);
      } catch (_) {}
    }
  }

  /// Creates the [outbox] table and indexes (idempotent).
  static Future<void> ensureOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid          TEXT    NOT NULL UNIQUE,
        businessId    TEXT    NOT NULL,
        branchId      TEXT    NOT NULL,
        deviceId      TEXT    NOT NULL,
        entityType    TEXT    NOT NULL,
        entityUuid    TEXT    NOT NULL,
        operation     TEXT    NOT NULL,
        payloadJson   TEXT    NOT NULL,
        syncStatus    TEXT    NOT NULL DEFAULT 'pending',
        retryCount    INTEGER NOT NULL DEFAULT 0,
        lastError     TEXT,
        createdAt     TEXT    NOT NULL,
        updatedAt     TEXT    NOT NULL,
        lastAttemptAt TEXT,
        lastSyncedAt  TEXT
      )
    ''');
    for (final idx in [
      'CREATE INDEX IF NOT EXISTS idx_outbox_sync_status ON outbox(syncStatus)',
      'CREATE INDEX IF NOT EXISTS idx_outbox_entity_type ON outbox(entityType)',
      'CREATE INDEX IF NOT EXISTS idx_outbox_entity_uuid ON outbox(entityUuid)',
      'CREATE INDEX IF NOT EXISTS idx_outbox_created_at ON outbox(createdAt)',
    ]) {
      try {
        await db.execute(idx);
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
    // v18: backfill tenant scope columns (safe no-op on fresh DBs).
    await _backfillSyncScopeIds(db);
    // v19: backfill sync timestamps (safe no-op on fresh DBs).
    await _backfillSyncTimestamps(db);
    // v20: mark all rows pending (safe no-op on fresh DBs).
    await _backfillSyncStatus(db);

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
    final deviceId = await resolveDeviceId(db);
    final scope = syncScopeStamp(deviceId);
    final timestamps = syncTimestampStamp();
    final status = syncStatusStamp();
    for (final c in cats) {
      await db.insert('categories', {
        ...c,
        'uuid': generateUuid(),
        ...scope,
        ...timestamps,
        ...status,
      });
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
      await db.insert('products', {
        ...p,
        'uuid': generateUuid(),
        ...scope,
        ...timestamps,
        ...status,
      });
    }
  }
}

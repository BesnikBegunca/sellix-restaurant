import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/open_tables_summary.dart';
import '../models/sale_insert_result.dart';
import '../models/unsupported_outbox_cleanup_result.dart';
import 'background_sync_service.dart';
import 'database_schema.dart';
import 'printed_order_sync_payload.dart';
import 'supported_sync_entity_types.dart';

/// Central SQLite service — single source of truth for all persistent data.
///
/// All methods are async and return raw [Map] rows. Business-logic models are
/// built in [ManagerData] so this layer stays a pure data-access layer.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  String? _cachedSyncDeviceId;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  static bool _isTransientDbError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('database is locked') ||
        msg.contains('database locked') ||
        msg.contains('sqlite_busy') ||
        msg.contains('locked') && msg.contains('sqlite');
  }

  /// Riprovo operacionet e DB kur SQLite është i zënë përkohësisht.
  Future<T> withDbRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 10,
    Duration initialDelay = const Duration(milliseconds: 40),
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (!_isTransientDbError(e) || attempt >= maxAttempts - 1) rethrow;
        await Future<void>.delayed(initialDelay * (attempt + 1));
      }
    }
    throw lastError!;
  }

  /// Closes the database connection and clears the cached instance so that the
  /// next access to [database] triggers a fresh [_initDB] call.
  ///
  /// Called by [RestoreService] before replacing the database file.
  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _cachedSyncDeviceId = null;
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
      version: 27,
      onCreate: DatabaseSchema.create,
      onUpgrade: DatabaseSchema.upgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Lejon lexime/ shkrime paralele pa "database is locked" (OneDrive, shumë ekrane).
        await db.execute('PRAGMA busy_timeout = 10000');
        try {
          await db.execute('PRAGMA journal_mode = WAL');
        } catch (_) {}
        await DatabaseSchema.ensureShiftsSnapshotColumn(db);
        await DatabaseSchema.ensureSalesOrderMetadataColumns(db);
        await DatabaseSchema.ensureSalesCloseMetadataColumns(db);
        await DatabaseSchema.ensureActivationArchiveTables(db);
        await DatabaseSchema.ensureDefaultMenuPresent(db);
      },
    );
  }

  /// Stable device UUID from [app_meta] — same key as [AuditContextService].
  Future<String> syncDeviceId() async {
    if (_cachedSyncDeviceId != null) return _cachedSyncDeviceId!;
    final db = await database;
    _cachedSyncDeviceId = await DatabaseSchema.resolveDeviceId(db);
    return _cachedSyncDeviceId!;
  }

  /// businessId / branchId / deviceId stamp for sync-critical inserts.
  Future<Map<String, String>> syncScope() async {
    return DatabaseSchema.syncScopeStamp(await syncDeviceId());
  }

  /// createdAt + updatedAt (or updatedAt only) for sync-critical inserts.
  Map<String, String> syncTimestamps({
    bool includeCreatedAt = true,
    DateTime? when,
  }) =>
      DatabaseSchema.syncTimestampStamp(
        includeCreatedAt: includeCreatedAt,
        when: when,
      );

  /// syncStatus pending + lastSyncedAt null for sync-critical inserts.
  Map<String, Object?> syncStatus() => DatabaseSchema.syncStatusStamp();

  // ──────────────────────────── TABLES ──────────────────────────────────────

  static const int defaultTableCount = 15;

  /// Porosi aktive (fatura të hapura) për këtë tavolinë — nuk duhet fshirë.
  Future<bool> tableHasOpenBusiness(int tableId) async {
    final db = await database;
    final rows = await db.query(
      'tables',
      where: 'id = ?',
      whereArgs: [tableId],
      limit: 1,
    );
    if (rows.isNotEmpty && ((rows.first['occupied'] as int?) ?? 0) == 1) {
      return true;
    }
    final orders = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM current_orders WHERE tableId = ?',
            [tableId],
          ),
        ) ??
        0;
    if (orders > 0) return true;
    final lines = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM current_order_lines WHERE tableId = ?',
            [tableId],
          ),
        ) ??
        0;
    return lines > 0;
  }

  /// Rikrijon rreshtat në [tables] për çdo tavolinë që ka porosi në DB.
  Future<void> reconcileTablesWithActiveOrders() async {
    await withDbRetry(() async {
      final db = await database;
      await _reconcileTablesWithActiveOrders(db);
    });
  }

  Future<void> _reconcileTablesWithActiveOrders(Database db) async {
    final tableIds = <int>{};
    for (final r in await db.query('current_orders')) {
      tableIds.add((r['tableId'] as num).toInt());
    }
    for (final r in await db.query('current_order_lines')) {
      tableIds.add((r['tableId'] as num).toInt());
    }
    for (final id in tableIds) {
      final exists = await db.query(
        'tables',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;

      final metas = await db.query(
        'current_orders',
        where: 'tableId = ?',
        whereArgs: [id],
        orderBy: 'currentTotal DESC',
        limit: 1,
      );
      double? total;
      String? waiter;
      int? orderNo;
      if (metas.isNotEmpty) {
        final m = metas.first;
        total = (m['currentTotal'] as num?)?.toDouble();
        waiter = m['waiterName'] as String?;
        orderNo = (m['orderNumber'] as num?)?.toInt();
      }
      if (total == null || total == 0) {
        final lineRows = await db.query(
          'current_order_lines',
          where: 'tableId = ?',
          whereArgs: [id],
        );
        total = 0;
        for (final l in lineRows) {
          final price = (l['productPrice'] as num).toDouble();
          final qty = (l['qty'] as num).toInt();
          total = total! + price * qty;
        }
      }
      await db.insert('tables', {
        'id': id,
        'occupied': 1,
        'currentTotal': total == 0 ? null : total,
        'assignedWaiterName': waiter,
        'currentOrderNumber': orderNo,
      });
    }
  }

  /// Siguron që ekzistojnë tavolina në DB — vetëm shtim, asnjëherë fshirje.
  Future<void> ensureDefaultTables({int count = defaultTableCount}) async {
    await withDbRetry(() async {
      await _reconcileTablesWithActiveOrders(await database);
      final db = await database;
      final existing = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM tables'),
          ) ??
          0;
      if (existing > 0) return;
      final n = count.clamp(1, 48);
      for (var i = 1; i <= n; i++) {
        await _insertTable(db, i);
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchTables() async {
    return withDbRetry(() async {
      final db = await database;
      return db.query('tables', orderBy: 'id ASC');
    });
  }

  Future<void> insertTable(int id) async {
    await withDbRetry(() async {
      await _insertTable(await database, id);
    });
  }

  Future<void> _insertTable(Database db, int id) async {
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

  /// Fshin tavolinën vetëm nëse nuk ka faturë/porosi të hapura.
  Future<bool> deleteTableIfSafe(int id) async {
    if (await tableHasOpenBusiness(id)) return false;
    final db = await database;
    await db.delete('current_orders', where: 'tableId = ?', whereArgs: [id]);
    await db.delete(
      'current_order_lines',
      where: 'tableId = ?',
      whereArgs: [id],
    );
    await db.delete('tables', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  Future<void> upsertCurrentOrderMeta({
    required int tableId,
    required String waiterName,
    required int orderNumber,
    required double currentTotal,
  }) async {
    final db = await database;
    final existing = await fetchCurrentOrderMeta(tableId, waiterName);
    final scope = await syncScope();
    final ts = syncTimestamps();
    final orderUuid = existing?['uuid'] as String? ?? DatabaseSchema.generateUuid();
    await db.insert('current_orders', {
      'tableId': tableId,
      'waiterName': waiterName,
      'orderNumber': orderNumber,
      'currentTotal': currentTotal,
      'updatedAt': ts['updatedAt'],
      'createdAt': existing?['createdAt'] ?? ts['createdAt'],
      'uuid': orderUuid,
      ...scope,
      ...syncStatus(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final row = await fetchCurrentOrderMeta(tableId, waiterName);
    if (row != null) {
      await _queueOutboxRow(
        'current_orders',
        row,
        existing == null ? 'create' : 'update',
      );
    }
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
    return withDbRetry(() async {
      final db = await database;
      return db.query(
        'current_orders',
        where: 'waiterName = ?',
        whereArgs: [waiterName],
      );
    });
  }

  Future<void> replaceCurrentOrderLines(
    int tableId,
    String waiterName,
    List<Map<String, dynamic>> lines,
  ) async {
    final db = await database;
    final scope = await syncScope();
    final ts = syncTimestamps();
    await db.transaction((txn) async {
      final oldLines = await txn.query(
        'current_order_lines',
        where: 'tableId = ? AND waiterName = ?',
        whereArgs: [tableId, waiterName],
      );
      for (final row in oldLines) {
        await _queueOutboxRow(
          'current_order_lines',
          row,
          'delete',
          txn: txn,
        );
      }
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
          'uuid': DatabaseSchema.generateUuid(),
          ...scope,
          ...syncStatus(),
          ...ts,
        });
      }
      final newLines = await txn.query(
        'current_order_lines',
        where: 'tableId = ? AND waiterName = ?',
        whereArgs: [tableId, waiterName],
      );
      for (final row in newLines) {
        await _queueOutboxRow(
          'current_order_lines',
          row,
          'create',
          txn: txn,
        );
      }
    });
    _scheduleSyncAfterLocalMutation();
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

  Future<void> clearCurrentOrder(
    int tableId,
    String waiterName, {
    bool clearPrintHistory = false,
    /// When true (manual cancel / void), queue [printed_orders] delete to cloud.
    /// After PAGUAJ, leave false so paid rows stay visible on mobile.
    bool queuePrintedOrderDeleteOnClear = false,
  }) async {
    final db = await database;
    final orderMeta = await fetchCurrentOrderMeta(tableId, waiterName);
    final orderLines = await fetchCurrentOrderLines(tableId, waiterName);
    await db.transaction((txn) async {
      if (orderMeta != null) {
        await _queueOutboxRow('current_orders', orderMeta, 'delete', txn: txn);
      }
      for (final row in orderLines) {
        await _queueOutboxRow(
          'current_order_lines',
          row,
          'delete',
          txn: txn,
        );
      }
      await txn.delete(
        'current_orders',
        where: 'tableId = ? AND waiterName = ?',
        whereArgs: [tableId, waiterName],
      );
      await txn.delete(
        'current_order_lines',
        where: 'tableId = ? AND waiterName = ?',
        whereArgs: [tableId, waiterName],
      );
    });
    _scheduleSyncAfterLocalMutation();
    if (clearPrintHistory) {
      await clearKitchenPrintsForTable(
        tableId,
        waiterName,
        queueSyncDelete: queuePrintedOrderDeleteOnClear,
      );
    }
  }

  // ───────────────────────── KITCHEN PRINT HISTORY ────────────────────────

  /// Regjistron një PRINTO të veçantë (batch-i i asaj shtypjeje).
  Future<int> insertKitchenPrint({
    required int tableId,
    required String waiterName,
    required int orderNumber,
    required List<Map<String, dynamic>> lines,
    int? shiftId,
  }) async {
    if (lines.isEmpty) return -1;
    final db = await database;
    final scope = await syncScope();
    final printedAt = DateTime.now().toIso8601String();
    final ts = syncTimestamps(when: DateTime.now());
    var total = 0.0;
    for (final l in lines) {
      total += (l['lineTotal'] as num).toDouble();
    }
    final printId = await db.transaction<int>((txn) async {
      final printId = await txn.insert('kitchen_prints', {
        'tableId': tableId,
        'waiterName': waiterName,
        'orderNumber': orderNumber,
        'total': total,
        'printedAt': printedAt,
        'shiftId': shiftId,
        'uuid': DatabaseSchema.generateUuid(),
        'createdAt': printedAt,
        'updatedAt': printedAt,
        ...scope,
        ...syncStatus(),
      });
      for (final line in lines) {
        await txn.insert('kitchen_print_lines', {
          'printId': printId,
          'productId': line['productId'],
          'productName': line['productName'],
          'productPrice': line['productPrice'],
          'productEmoji': line['productEmoji'] ?? '☕',
          'imagePath': line['imagePath'],
          'qty': line['qty'],
          'lineTotal': line['lineTotal'],
          'uuid': DatabaseSchema.generateUuid(),
          ...scope,
          ...syncStatus(),
          ...ts,
        });
      }
      final printRow = await _fetchEntityRow(
        'kitchen_prints',
        where: 'id = ?',
        whereArgs: [printId],
        txn: txn,
      );
      if (printRow != null) {
        await _queuePrintedOrderOutbox(
          printRow: printRow,
          batchLines: lines,
          operation: 'create',
          txn: txn,
        );
      }
      return printId;
    });
    if (printId > 0) {
      _scheduleSyncAfterLocalMutation();
    }
    return printId;
  }

  Future<List<Map<String, dynamic>>> fetchKitchenPrintsForWaiter(
    String waiterName, {
    int? shiftId,
  }) async {
    final db = await database;
    if (shiftId != null) {
      return db.query(
        'kitchen_prints',
        where: 'waiterName = ? AND shiftId = ?',
        whereArgs: [waiterName, shiftId],
        orderBy: 'printedAt DESC',
      );
    }
    return db.query(
      'kitchen_prints',
      where: 'waiterName = ?',
      whereArgs: [waiterName],
      orderBy: 'printedAt DESC',
    );
  }

  Future<List<Map<String, dynamic>>> fetchKitchenPrintLines(int printId) async {
    final db = await database;
    return db.query(
      'kitchen_print_lines',
      where: 'printId = ?',
      whereArgs: [printId],
      orderBy: 'id ASC',
    );
  }

  Future<Map<String, dynamic>?> fetchKitchenPrintById(int printId) async {
    final db = await database;
    final rows = await db.query(
      'kitchen_prints',
      where: 'id = ?',
      whereArgs: [printId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Removes one kitchen print batch. Sync delete only when [queueSyncDelete] is
  /// true (void/cancel); after payment, clear local history without cloud delete.
  Future<void> deleteKitchenPrint(
    int printId, {
    bool queueSyncDelete = true,
  }) async {
    final db = await database;
    final meta = await fetchKitchenPrintById(printId);
    await db.transaction((txn) async {
      if (queueSyncDelete && meta != null) {
        await _queuePrintedOrderOutbox(
          printRow: meta,
          batchLines: const [],
          operation: 'delete',
          txn: txn,
        );
      }
      await txn.delete(
        'kitchen_print_lines',
        where: 'printId = ?',
        whereArgs: [printId],
      );
      await txn.delete(
        'kitchen_prints',
        where: 'id = ?',
        whereArgs: [printId],
      );
    });
    if (queueSyncDelete) {
      _scheduleSyncAfterLocalMutation();
    }
  }

  /// Clears local [kitchen_prints] for a table. Default: no cloud delete (post-pay).
  Future<void> clearKitchenPrintsForTable(
    int tableId,
    String waiterName, {
    bool queueSyncDelete = false,
  }) async {
    final db = await database;
    final prints = await db.query(
      'kitchen_prints',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
    );
    for (final p in prints) {
      await deleteKitchenPrint(
        (p['id'] as num).toInt(),
        queueSyncDelete: queueSyncDelete,
      );
    }
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

  static const String _waiterOrderCountersKey = 'waiter_order_counters';

  static String _normalizeWaiterForOrderCounter(String raw) {
    final n = raw.trim();
    return n.isEmpty ? 'Panjohur' : n;
  }

  /// Numri «Porosia #» për kamarier — rinishet nga 1 kur mbyllhet gjendja.
  Future<int> consumeNextWaiterOrderNumber(String waiterName) async {
    final name = _normalizeWaiterForOrderCounter(waiterName);
    final db = await database;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: [_waiterOrderCountersKey],
        limit: 1,
      );
      final map = <String, int>{};
      if (rows.isNotEmpty) {
        final raw = rows.first['value']?.toString() ?? '{}';
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>?;
          if (decoded != null) {
            for (final e in decoded.entries) {
              final v = e.value;
              if (v is num) map[e.key] = v.toInt();
            }
          }
        } catch (_) {}
      }
      final next = (map[name] ?? 0) + 1;
      map[name] = next;
      await txn.insert(
        'app_meta',
        {
          'key': _waiterOrderCountersKey,
          'value': jsonEncode(map),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return next;
    });
  }

  /// Pas mbylljes së gjendjes: çdo kamarier fillon përsëri nga Porosia #1.
  Future<void> resetOrderNumberCountersForNewShift() async {
    final db = await database;
    final today = _localOrderDateKey();
    await db.transaction((txn) async {
      await txn.insert(
        'app_meta',
        {'key': _waiterOrderCountersKey, 'value': '{}'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_meta',
        {'key': 'global_order_number_date', 'value': today},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_meta',
        {'key': 'global_order_number', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Numri i radhës për «Porosia #» — rinishet nga 1 çdo ditë kalendari (lokal).
  static String _localOrderDateKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  Future<int> consumeNextGlobalOrderNumber() async {
    final db = await database;
    final today = _localOrderDateKey();
    return db.transaction<int>((txn) async {
      final dateRows = await txn.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['global_order_number_date'],
        limit: 1,
      );
      final storedDate = dateRows.isEmpty
          ? ''
          : dateRows.first['value']?.toString() ?? '';

      final counterRows = await txn.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: ['global_order_number'],
        limit: 1,
      );

      var current = 0;
      if (storedDate == today) {
        final raw = counterRows.isEmpty
            ? '0'
            : counterRows.first['value']?.toString() ?? '0';
        current = int.tryParse(raw) ?? 0;
      }

      final next = current + 1;
      await txn.insert('app_meta', {
        'key': 'global_order_number_date',
        'value': today,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final scope = await syncScope();
    final ts = syncTimestamps();
    final categoryUuid = DatabaseSchema.generateUuid();
    await db.insert('categories', {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'sortOrder': sortOrder,
      'uuid': categoryUuid,
      ...scope,
      ...syncStatus(),
      ...ts,
    });
    final row = await _fetchEntityRow(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (row != null) {
      await _queueOutboxRow('categories', row, 'create');
    }
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await DatabaseSchema.markBuiltinCategoryHidden(db, id);
    final row = await _fetchEntityRow(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    // Products with this categoryId are deleted by the ON DELETE CASCADE FK.
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    if (row != null) {
      await _queueOutboxRow('categories', row, 'delete');
    }
  }

  // ──────────────────────────── PRODUCTS ────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final db = await database;
    return db.query(
      'products',
      orderBy: 'categoryId ASC, sortOrder ASC, rowid ASC',
    );
  }

  Future<int> _nextProductSortOrder(DatabaseExecutor db, String categoryId) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(MAX(sortOrder), -1) + 1 AS n FROM products WHERE categoryId = ?',
      [categoryId],
    );
    return (r.first['n'] as num?)?.toInt() ?? 0;
  }

  Future<void> setProductOrderInCategory(
    String categoryId,
    List<String> orderedProductIds,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedProductIds.length; i++) {
        await txn.update(
          'products',
          {'sortOrder': i},
          where: 'id = ? AND categoryId = ?',
          whereArgs: [orderedProductIds[i], categoryId],
        );
      }
    });
    for (final id in orderedProductIds) {
      final row = await _fetchEntityRow(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (row != null) {
        await _queueOutboxRow('products', row, 'update');
      }
    }
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
    final scope = await syncScope();
    final ts = syncTimestamps();
    final sortOrder = await _nextProductSortOrder(db, categoryId);
    await db.insert('products', {
      'id': id,
      'name': name,
      'price': price,
      'emoji': emoji,
      'imagePath': imagePath,
      'categoryId': categoryId,
      'sortOrder': sortOrder,
      'uuid': DatabaseSchema.generateUuid(),
      ...scope,
      ...syncStatus(),
      ...ts,
    });
    final row = await _fetchEntityRow(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (row != null) {
      await _queueOutboxRow('products', row, 'create');
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> fields) async {
    final db = await database;
    await db.update(
      'products',
      {
        ...fields,
        ...syncTimestamps(includeCreatedAt: false),
        ...syncStatus(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final row = await _fetchEntityRow(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (row != null) {
      await _queueOutboxRow('products', row, 'update');
    }
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await DatabaseSchema.markBuiltinProductHidden(db, id);
    final row = await _fetchEntityRow(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    if (row != null) {
      await _queueOutboxRow('products', row, 'delete');
    }
  }

  Future<void> moveProductCategory(
    String productId,
    String newCategoryId,
  ) async {
    final db = await database;
    final sortOrder = await _nextProductSortOrder(db, newCategoryId);
    await db.update(
      'products',
      {'categoryId': newCategoryId, 'sortOrder': sortOrder},
      where: 'id = ?',
      whereArgs: [productId],
    );
    final row = await _fetchEntityRow(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    if (row != null) {
      await _queueOutboxRow('products', row, 'update');
    }
  }

  // ──────────────────────────── WAITERS ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWaiters() async {
    final db = await database;
    return db.query('waiters', orderBy: 'id ASC');
  }

  Future<int> insertWaiter(
    String name,
    String pinHash,
    String pinSalt, {
    required String pinView,
  }) async {
    final db = await database;
    final scope = await syncScope();
    final now = DateTime.now().toIso8601String();
    final ts = syncTimestamps(when: DateTime.now());
    final waiterId = await db.insert('waiters', {
      'name': name,
      'pin': pinHash,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'pinUpdatedAt': now,
      'pinView': pinView,
      'uuid': DatabaseSchema.generateUuid(),
      ...scope,
      ...syncStatus(),
      ...ts,
    });
    await _queueOutboxById('waiters', 'waiters', waiterId, operation: 'create');
    return waiterId;
  }

  Future<void> updateWaiterPin(
    int id,
    String hash,
    String salt, {
    String? pinView,
  }) async {
    final db = await database;
    final map = <String, Object?>{
      'pin': hash,
      'pinHash': hash,
      'pinSalt': salt,
      'pinUpdatedAt': DateTime.now().toIso8601String(),
    };
    if (pinView != null) map['pinView'] = pinView;
    await db.update('waiters', map, where: 'id = ?', whereArgs: [id]);
    await _queueOutboxById('waiters', 'waiters', id, operation: 'update');
  }

  Future<void> updateWaiterPinViewOnly(int id, String pinView) async {
    final db = await database;
    await db.update(
      'waiters',
      {'pinView': pinView},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _queueOutboxById('waiters', 'waiters', id, operation: 'update');
  }

  Future<void> deleteWaiterById(int id) async {
    final db = await database;
    final row = await _fetchEntityRow(
      'waiters',
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete('waiters', where: 'id = ?', whereArgs: [id]);
    if (row != null) {
      await _queueOutboxRow('waiters', row, 'delete');
    }
  }

  // ─────────────────────────── MANAGERS ───────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchManagers() async {
    final db = await database;
    return db.query('managers', orderBy: 'id ASC');
  }

  Future<int> insertManager(
    String name,
    String pinHash,
    String pinSalt, {
    required String pinView,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('managers', {
      'name': name,
      'pin': pinHash,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'pinUpdatedAt': now,
      'pinView': pinView,
    });
  }

  Future<void> deleteManagerById(int id) async {
    final db = await database;
    await db.delete('managers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateManagerPinViewOnly(int id, String pinView) async {
    final db = await database;
    await db.update(
      'managers',
      {'pinView': pinView},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAdminPinViewOnly(String pinView) async {
    final db = await database;
    try {
      await db.update(
        'company',
        {'adminPinView': pinView},
        where: 'id = 1',
      );
    } catch (_) {
      try {
        await db.execute('ALTER TABLE company ADD COLUMN adminPinView TEXT');
      } catch (_) {}
      await db.update(
        'company',
        {'adminPinView': pinView},
        where: 'id = 1',
      );
    }
  }

  // ────────────────────────────── SALES ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSales() async {
    final db = await database;
    return db.query('sales', orderBy: 'timestamp DESC');
  }

  /// [DesktopReality] — TEMP. Latest completed sales in SQLite + matching outbox rows.
  /// Triggered from manager dashboard in debug mode. Remove after parity confirmed.
  Future<void> runSalesParityDiagnostic() async {
    final db = await database;

    final sales = await db.rawQuery('''
      SELECT uuid, total, timestamp, syncStatus, deletedAt, businessId, branchId
      FROM sales
      WHERE deletedAt IS NULL
      ORDER BY timestamp DESC
      LIMIT 20
    ''');

    debugPrint('[DesktopReality] salesCount=${sales.length}');
    for (final s in sales) {
      debugPrint(
        '[DesktopReality] sale uuid=${s['uuid']} '
        'total=${s['total']} soldAt=${s['timestamp']} '
        'status=completed syncStatus=${s['syncStatus']} '
        'deletedAt=${s['deletedAt']} '
        'businessId=${s['businessId']} branchId=${s['branchId']}',
      );
    }

    if (sales.isEmpty) return;

    final uuids = sales
        .map((s) => s['uuid'] as String?)
        .whereType<String>()
        .toList();
    final placeholders = List.filled(uuids.length, '?').join(',');
    final outbox = await db.rawQuery('''
      SELECT entityType, entityUuid, syncStatus, retryCount, lastError
      FROM outbox
      WHERE entityType = 'sales' AND entityUuid IN ($placeholders)
    ''', uuids);

    final pending = outbox.where((r) => r['syncStatus'] == 'pending').length;
    final failed = outbox.where((r) => r['syncStatus'] == 'failed').length;
    final synced = outbox.where((r) => r['syncStatus'] == 'synced').length;
    debugPrint(
      '[DesktopReality] outboxForLatestSales pending=$pending '
      'failed=$failed synced=$synced total=${outbox.length}',
    );

    final outboxByUuid = {
      for (final o in outbox) o['entityUuid'] as String: o,
    };
    for (final uuid in uuids) {
      final o = outboxByUuid[uuid];
      if (o == null) {
        debugPrint(
          '[DesktopReality] outbox uuid=$uuid status=NOT_QUEUED '
          'retryCount=0 lastError=null',
        );
        continue;
      }
      debugPrint(
        '[DesktopReality] outbox uuid=${o['entityUuid']} '
        'status=${o['syncStatus']} retryCount=${o['retryCount']} '
        'lastError=${o['lastError']}',
      );
    }
  }

  /// Resolves a local [sales.id] to the sale's sync [uuid] (for legacy outbox rows).
  Future<String?> fetchSaleUuidByLocalId(int saleId) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      columns: ['uuid'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['uuid'] as String?;
  }

  Future<void> insertSale({
    required String waiterName,
    required int tableId,
    required double total,
    int? shiftId,
  }) async {
    final db = await database;
    final scope = await syncScope();
    final ts = syncTimestamps();
    final saleId = await db.insert('sales', {
      'waiterName': waiterName,
      'tableId': tableId,
      'total': total,
      'timestamp': ts['createdAt'],
      if (shiftId != null) 'shiftId': shiftId,
      'uuid': DatabaseSchema.generateUuid(),
      ...scope,
      ...syncStatus(),
      ...ts,
    });
    await _queueOutboxById('sales', 'sales', saleId, operation: 'create');
  }

  Future<void> clearSales() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_lines');
      await txn.delete('sales');
    });
  }

  // ──────────────────────────── SALE LINES ──────────────────────────────────

  /// Meta key for in-flight payment idempotency (table + waiter).
  static String paymentPendingMetaKey(int tableId, String waiterName) =>
      'payment_pending_${tableId}_${waiterName.trim()}';

  Future<String?> getPendingPaymentSaleUuid(
    int tableId,
    String waiterName,
  ) =>
      getAppMeta(paymentPendingMetaKey(tableId, waiterName));

  Future<void> setPendingPaymentSaleUuid(
    int tableId,
    String waiterName,
    String saleUuid,
  ) =>
      setAppMeta(paymentPendingMetaKey(tableId, waiterName), saleUuid);

  Future<void> clearPendingPaymentSaleUuid(
    int tableId,
    String waiterName,
  ) =>
      setAppMeta(paymentPendingMetaKey(tableId, waiterName), '');

  /// Returns sale primary key when [saleUuid] exists, else `null`.
  Future<int?> fetchSaleIdByUuid(String saleUuid) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [saleUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  /// Resolves or creates a stable sale UUID for the current payment attempt.
  Future<String> resolvePaymentSaleUuid({
    required int tableId,
    required String waiterName,
  }) async {
    final pending = await getPendingPaymentSaleUuid(tableId, waiterName);
    if (pending != null && pending.isNotEmpty) {
      final existingId = await fetchSaleIdByUuid(pending);
      if (existingId != null) return pending;
    }
    final saleUuid = DatabaseSchema.generateUuid();
    await setPendingPaymentSaleUuid(tableId, waiterName, saleUuid);
    return saleUuid;
  }

  /// Inserts a sale header + line items atomically (idempotent on [saleUuid]).
  ///
  /// If a sale with the same [saleUuid] already exists, returns that row and
  /// does not insert duplicate lines or outbox events.
  Future<SaleInsertResult> insertSaleWithLines({
    required String saleUuid,
    required String waiterName,
    required int tableId,
    required double total,
    required List<Map<String, dynamic>> lines,
    int? shiftId,
    int? orderNumber,
    String? tableName,
  }) async {
    final db = await database;
    final scope = await syncScope();
    final ts = syncTimestamps();
    final timestamp = ts['createdAt']!;
    // ignore: avoid_print
    print(
      '[TimezoneFix] localNow=${DateTime.now().toIso8601String()} '
      'utcNow=${DateTime.now().toUtc().toIso8601String()} '
      'soldAt=$timestamp',
    );
    final result = await db.transaction<SaleInsertResult>((txn) async {
      final existing = await txn.query(
        'sales',
        where: 'uuid = ?',
        whereArgs: [saleUuid],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final saleId = existing.first['id'] as int;
        await _linkPrintedOrdersToSale(
          tableId: tableId,
          waiterName: waiterName,
          saleUuid: saleUuid,
          txn: txn,
        );
        return SaleInsertResult(
          saleId: saleId,
          saleUuid: saleUuid,
          wasExisting: true,
        );
      }

      // TEMP [SyncDiag] — log sync scope stamp to catch 'local-business' IDs.
      // ignore: avoid_print
      print(
        '[SyncDiag] insertSaleWithLines scope: businessId=${scope['businessId']} '
        'branchId=${scope['branchId']} deviceId=${scope['deviceId']}',
      );

      int saleId;
      try {
        saleId = await txn.insert('sales', {
          'waiterName': waiterName,
          'tableId': tableId,
          'total': total,
          'timestamp': timestamp,
          if (shiftId != null) 'shiftId': shiftId,
          if (orderNumber != null && orderNumber > 0) 'orderNumber': orderNumber,
          if (tableName != null && tableName.trim().isNotEmpty)
            'tableName': tableName.trim(),
          'uuid': saleUuid,
          ...scope,
          ...syncStatus(),
          ...ts,
        });
      } on DatabaseException catch (e) {
        if (!e.isUniqueConstraintError()) rethrow;
        final raced = await txn.query(
          'sales',
          where: 'uuid = ?',
          whereArgs: [saleUuid],
          limit: 1,
        );
        if (raced.isEmpty) rethrow;
        return SaleInsertResult(
          saleId: raced.first['id'] as int,
          saleUuid: saleUuid,
          wasExisting: true,
        );
      }

      // ignore: avoid_print
      print('[SyncDiag] sale created uuid=$saleUuid saleId=$saleId');

      await _queueOutboxByIdIfAbsent(
        'sales',
        'sales',
        saleId,
        operation: 'create',
        txn: txn,
      );
      // ignore: avoid_print
      print(
        '[SyncDiag] queued to outbox entityType=sales uuid=$saleUuid '
        'soldAt=$timestamp',
      );
      // ignore: avoid_print
      print(
        '[TimezoneFix] queued to outbox uuid=$saleUuid soldAt=$timestamp',
      );
      for (final line in lines) {
        final lineUuid = DatabaseSchema.generateUuid();
        final lineId = await txn.insert('sale_lines', {
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
          'updatedAt': timestamp,
          'uuid': lineUuid,
          ...scope,
          ...syncStatus(),
        });
        await _queueOutboxByIdIfAbsent(
          'sale_lines',
          'sale_lines',
          lineId,
          operation: 'create',
          txn: txn,
          payloadExtras: {'saleUuid': saleUuid},
        );
        // ignore: avoid_print
        print('[SyncDiag] queued to outbox entityType=sale_lines uuid=$lineUuid');
      }
      await _linkPrintedOrdersToSale(
        tableId: tableId,
        waiterName: waiterName,
        saleUuid: saleUuid,
        txn: txn,
      );
      return SaleInsertResult(
        saleId: saleId,
        saleUuid: saleUuid,
        wasExisting: false,
      );
    });
    _scheduleSyncAfterLocalMutation();
    return result;
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
    final scope = await syncScope();
    final ts = syncTimestamps(when: date);
    final expenseId = await db.insert('expenses', {
      'type': type,
      'description': description,
      'amount': amount,
      'timestamp': ts['createdAt'],
      'shiftId': shiftId,
      'uuid': DatabaseSchema.generateUuid(),
      ...scope,
      ...syncStatus(),
      ...ts,
    });
    await _queueOutboxById(
      'expenses',
      'expenses',
      expenseId,
      operation: 'create',
    );
    return expenseId;
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

  Future<void> updateAdminPin(String hash, String salt, {String? pinView}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final base = <String, Object?>{
      'adminPinHash': hash,
      'adminPinSalt': salt,
      'adminPinUpdatedAt': now,
    };
    if (pinView != null) base['adminPinView'] = pinView;
    try {
      final existing = await db.query(
        'company',
        columns: ['adminPinCreatedAt'],
        where: 'id = 1',
      );
      final createdAt =
          (existing.isNotEmpty && existing.first['adminPinCreatedAt'] != null)
          ? existing.first['adminPinCreatedAt'] as String
          : now;
      base['adminPinCreatedAt'] = createdAt;
      await db.update('company', base, where: 'id = 1');
    } catch (_) {
      // Columns missing on very old DBs — add them first.
      try { await db.execute("ALTER TABLE company ADD COLUMN adminPinHash TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE company ADD COLUMN adminPinSalt TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE company ADD COLUMN adminPinCreatedAt TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE company ADD COLUMN adminPinUpdatedAt TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE company ADD COLUMN adminPinView TEXT"); } catch (_) {}
      base['adminPinCreatedAt'] = now;
      await db.update('company', base, where: 'id = 1');
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
    final existing = await db.query(
      'waiter_salaries',
      where: 'waiterName = ?',
      whereArgs: [waiterName],
      limit: 1,
    );
    final scope = await syncScope();
    final ts = syncTimestamps();
    final salaryUuid = existing.isEmpty
        ? DatabaseSchema.generateUuid()
        : existing.first['uuid'] as String? ?? DatabaseSchema.generateUuid();
    await db.insert('waiter_salaries', {
      'waiterName': waiterName,
      'dailyRate': dailyRate,
      'uuid': salaryUuid,
      ...scope,
      ...syncStatus(),
      ...ts,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final row = await _fetchEntityRow(
      'waiter_salaries',
      where: 'waiterName = ?',
      whereArgs: [waiterName],
    );
    if (row != null) {
      await _queueOutboxRow(
        'waiter_salaries',
        row,
        existing.isEmpty ? 'create' : 'update',
      );
    }
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
    final scope = await syncScope();
    final ts = syncTimestamps(when: date);
    final advanceId = await db.insert('advances', {
      'waiterName': waiterName,
      'amount': amount,
      'note': note,
      'timestamp': ts['createdAt'],
      'uuid': DatabaseSchema.generateUuid(),
      ...scope,
      ...syncStatus(),
      ...ts,
    });
    await _queueOutboxById(
      'advances',
      'advances',
      advanceId,
      operation: 'create',
    );
    return advanceId;
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
    final scope = await syncScope();
    final ts = syncTimestamps();
    if (worked) {
      final existing = await db.query(
        'waiter_worked_days',
        where: 'waiterName = ? AND workDate = ?',
        whereArgs: [waiterName, date],
        limit: 1,
      );
      if (existing.isEmpty) {
        final workedDayId = await db.insert('waiter_worked_days', {
          'waiterName': waiterName,
          'workDate': date,
          'createdAt': date,
          'updatedAt': ts['updatedAt'],
          'uuid': DatabaseSchema.generateUuid(),
          ...scope,
          ...syncStatus(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (workedDayId > 0) {
          await _queueOutboxById(
            'waiter_worked_days',
            'waiter_worked_days',
            workedDayId,
            operation: 'create',
          );
        }
      }
    } else {
      final row = await _fetchEntityRow(
        'waiter_worked_days',
        where: 'waiterName = ? AND workDate = ?',
        whereArgs: [waiterName, date],
      );
      await db.delete(
        'waiter_worked_days',
        where: 'waiterName = ? AND workDate = ?',
        whereArgs: [waiterName, date],
      );
      if (row != null) {
        await _queueOutboxRow('waiter_worked_days', row, 'delete');
      }
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
    final scope = await syncScope();
    final opened = DatabaseSchema.toSyncUtcIso(openedAt);
    final ts = syncTimestamps(when: openedAt);
    return db.insert('shifts', {
      'openedAt': opened,
      'openedBy': openedBy,
      'openingCash': openingCash,
      'status': 'open',
      'uuid': DatabaseSchema.generateUuid(),
      'createdAt': opened,
      'updatedAt': ts['updatedAt'],
      ...scope,
      ...syncStatus(),
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
    await DatabaseSchema.ensureShiftsSnapshotColumn(db);
    final row = <String, Object?>{
      'closedAt': DatabaseSchema.toSyncUtcIso(closedAt),
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
    await _queueOutboxById('shifts', 'shifts', shiftId, operation: 'update');
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

  /// Closed shift archives (çdo mbyllje gjendje) — për panelin Shitjet.
  Future<List<Map<String, dynamic>>> fetchClosedShifts() async {
    final db = await database;
    return db.query(
      'shifts',
      where: "status = 'closed' AND closedAt IS NOT NULL",
      orderBy: 'closedAt DESC',
    );
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
    final scope = await syncScope();
    final now = DateTime.now().toIso8601String();
    final adjustmentId = await db.insert('sale_adjustments', {
      'saleId': saleId,
      'saleLineId': saleLineId,
      'adjustmentType': adjustmentType,
      'productName': productName,
      'quantity': quantity,
      'amount': amount,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': now,
      'updatedAt': now,
      'uuid': DatabaseSchema.generateUuid(),
      ...scope,
      ...syncStatus(),
    });
    await _queueOutboxById(
      'sale_adjustments',
      'sale_adjustments',
      adjustmentId,
      operation: 'create',
    );
    return adjustmentId;
  }

  /// Deletes a sale and all related lines and adjustments (manager void).
  Future<void> deleteSaleById(int saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'sale_adjustments',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      await txn.delete(
        'sale_lines',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      await txn.delete(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
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

  Future<String?> getPullCursor() => getAppMeta('sync_pull_cursor');

  Future<void> setPullCursor(String cursor) => setAppMeta('sync_pull_cursor', cursor);

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

  /// A ka të paktën një tavolinë me faturë/porosi të hapura.
  Future<bool> hasAnyOpenTableBusiness() async {
    final db = await database;
    final occupied = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM tables WHERE occupied = 1',
          ),
        ) ??
        0;
    if (occupied > 0) return true;
    final orders = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM current_orders'),
        ) ??
        0;
    if (orders > 0) return true;
    final lines = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM current_order_lines'),
        ) ??
        0;
    return lines > 0;
  }

  static const String activationResetCloseReason =
      'Closed during activation reset';

  /// Returns open table/order count and combined total for activation UI.
  Future<OpenTablesSummary> getOpenTablesSummary() async {
    await reconcileTablesWithActiveOrders();
    final db = await database;
    final orderRows = await db.query('current_orders');
    var count = orderRows.length;
    var totalAmount = 0.0;

    for (final row in orderRows) {
      var lineTotal = (row['currentTotal'] as num?)?.toDouble() ?? 0;
      if (lineTotal <= 0) {
        final tableId = (row['tableId'] as num).toInt();
        final waiterName = row['waiterName'] as String;
        final lines = await fetchCurrentOrderLines(tableId, waiterName);
        lineTotal = _sumOrderLineMaps(lines);
      }
      totalAmount += lineTotal;
    }

    if (count == 0) {
      final occupiedRows = await db.query(
        'tables',
        where: 'occupied = 1 OR currentTotal IS NOT NULL',
      );
      count = occupiedRows.length;
      for (final row in occupiedRows) {
        totalAmount += (row['currentTotal'] as num?)?.toDouble() ?? 0;
      }
    }

    return OpenTablesSummary(
      count: count,
      totalAmount: double.parse(totalAmount.toStringAsFixed(2)),
    );
  }

  double _sumOrderLineMaps(List<Map<String, dynamic>> lines) {
    var total = 0.0;
    for (final line in lines) {
      final price = (line['productPrice'] as num).toDouble();
      final qty = (line['qty'] as num).toInt();
      total += double.parse((price * qty).toStringAsFixed(2));
    }
    return total;
  }

  Future<String?> _categoryNameForProduct(
    DatabaseExecutor db,
    String productId,
  ) async {
    final rows = await db.rawQuery(
      'SELECT c.name AS categoryName '
      'FROM products p '
      'LEFT JOIN categories c ON c.id = p.categoryId '
      'WHERE p.id = ? '
      'LIMIT 1',
      [productId],
    );
    if (rows.isEmpty) return null;
    return rows.first['categoryName'] as String?;
  }

  /// Closes open tables without deleting financial totals — converts unpaid
  /// orders to [sales] with status `completed_local` when total > 0.
  Future<void> closeOpenTablesSafely() async {
    await reconcileTablesWithActiveOrders();
    final db = await database;
    await DatabaseSchema.ensureSalesCloseMetadataColumns(db);
    final closedAt = DatabaseSchema.toSyncUtcIso();
    final openShift = await fetchOpenShift();
    final shiftId = (openShift?['id'] as num?)?.toInt();

    final orderMetas = await db.query('current_orders');
    for (final meta in orderMetas) {
      final tableId = (meta['tableId'] as num).toInt();
      final waiterName = meta['waiterName'] as String;
      final orderNumber = (meta['orderNumber'] as num?)?.toInt();
      final lines = await fetchCurrentOrderLines(tableId, waiterName);
      final lineMaps = <Map<String, dynamic>>[];
      for (final line in lines) {
        final lineTotal = double.parse(
          (((line['productPrice'] as num).toDouble()) *
                  (line['qty'] as num).toInt())
              .toStringAsFixed(2),
        );
        lineMaps.add({
          'productId': line['productId'],
          'productName': line['productName'],
          'productEmoji': line['productEmoji'] ?? '☕',
          'productImagePath': line['imagePath'],
          'productPrice': (line['productPrice'] as num).toDouble(),
          'quantity': (line['qty'] as num).toInt(),
          'lineTotal': lineTotal,
          'categoryName': await _categoryNameForProduct(
            db,
            line['productId'] as String,
          ),
          'tableName': 'Tavolina $tableId',
          'waiterName': waiterName,
        });
      }

      var total = (meta['currentTotal'] as num?)?.toDouble() ?? 0;
      if (total <= 0 && lineMaps.isNotEmpty) {
        total = _sumOrderLineMaps(lines);
      }

      if (total > 0) {
        final saleUuid = DatabaseSchema.generateUuid();
        final result = await insertSaleWithLines(
          saleUuid: saleUuid,
          waiterName: waiterName,
          tableId: tableId,
          total: total,
          lines: lineMaps,
          shiftId: shiftId,
          orderNumber: orderNumber,
          tableName: 'Tavolina $tableId',
        );
        await db.update(
          'sales',
          {
            'status': 'completed_local',
            'closeReason': activationResetCloseReason,
            'closedAt': closedAt,
          },
          where: 'id = ?',
          whereArgs: [result.saleId],
        );
      }

      await updateTable(
        tableId,
        occupied: false,
        currentTotal: null,
        assignedWaiterName: null,
        currentOrderNumber: orderNumber,
      );
      await clearCurrentOrder(
        tableId,
        waiterName,
        clearPrintHistory: false,
      );
    }

    await clearAllCurrentOrdersAndResetTables();
  }

  /// Copies operational order/sale data into local archive tables before wipe.
  Future<void> archiveClosedOrdersBeforeReset() async {
    final db = await database;
    await DatabaseSchema.ensureActivationArchiveTables(db);
    await DatabaseSchema.ensureSalesCloseMetadataColumns(db);

    final batchId = DatabaseSchema.generateUuid();
    final archivedAt = DatabaseSchema.toSyncUtcIso();

    await db.transaction((txn) async {
      final sales = await txn.query('sales');
      for (final sale in sales) {
        final total = (sale['total'] as num?)?.toDouble() ?? 0;
        final archivedOrderId = await txn.insert('local_archived_orders', {
          'archiveBatchId': batchId,
          'archivedAt': archivedAt,
          'sourceEntity': 'sale',
          'sourceId': sale['id'],
          'tableId': sale['tableId'],
          'waiterName': sale['waiterName'],
          'orderNumber': sale['orderNumber'],
          'status': sale['status'] ?? 'completed',
          'totalAmount': total,
          'subtotal': total,
          'tax': 0,
          'discount': 0,
          'closeReason': sale['closeReason'],
          'closedAt': sale['closedAt'],
          'rowJson': jsonEncode(sale),
        });

        final saleLines = await txn.query(
          'sale_lines',
          where: 'saleId = ?',
          whereArgs: [sale['id']],
        );
        for (final line in saleLines) {
          await txn.insert('local_archived_order_lines', {
            'archiveBatchId': batchId,
            'archivedOrderId': archivedOrderId,
            'sourceEntity': 'sale_line',
            'sourceId': line['id'],
            'rowJson': jsonEncode(line),
          });
        }

        await txn.insert('local_archived_payments', {
          'archiveBatchId': batchId,
          'saleId': sale['id'],
          'rowJson': jsonEncode({
            'saleId': sale['id'],
            'saleUuid': sale['uuid'],
            'total': total,
            'timestamp': sale['timestamp'],
            'waiterName': sale['waiterName'],
            'tableId': sale['tableId'],
          }),
        });
      }

      final openOrders = await txn.query('current_orders');
      for (final order in openOrders) {
        final tableId = (order['tableId'] as num).toInt();
        final waiterName = order['waiterName'] as String;
        final total = (order['currentTotal'] as num?)?.toDouble() ?? 0;
        final archivedOrderId = await txn.insert('local_archived_orders', {
          'archiveBatchId': batchId,
          'archivedAt': archivedAt,
          'sourceEntity': 'current_order',
          'sourceId': order['uuid'],
          'tableId': tableId,
          'waiterName': waiterName,
          'orderNumber': order['orderNumber'],
          'status': 'open',
          'totalAmount': total,
          'subtotal': total,
          'tax': 0,
          'discount': 0,
          'rowJson': jsonEncode(order),
        });

        final orderLines = await txn.query(
          'current_order_lines',
          where: 'tableId = ? AND waiterName = ?',
          whereArgs: [tableId, waiterName],
        );
        for (final line in orderLines) {
          await txn.insert('local_archived_order_lines', {
            'archiveBatchId': batchId,
            'archivedOrderId': archivedOrderId,
            'sourceEntity': 'current_order_line',
            'sourceId': line['id'],
            'rowJson': jsonEncode(line),
          });
        }
      }

      final sessions = await txn.query(
        'tables',
        where: 'occupied = 1 OR currentTotal IS NOT NULL',
      );
      for (final session in sessions) {
        final occupied = ((session['occupied'] as int?) ?? 0) == 1;
        await txn.insert('local_archived_table_sessions', {
          'archiveBatchId': batchId,
          'tableId': session['id'],
          'status': occupied ? 'open' : 'closed',
          'totalAmount': session['currentTotal'],
          'waiterName': session['assignedWaiterName'],
          'orderNumber': session['currentOrderNumber'],
          'rowJson': jsonEncode(session),
        });
      }
    });
  }

  /// Deletes local business/operational data for a new tenant activation.
  ///
  /// Preserves [company] (printer/admin settings), [shift] singleton row,
  /// [audit_logs] (immutable audit trail), [audit_device_id], and
  /// activation-related [app_meta] keys.
  ///
  /// When [skipOpenTableCheck] is false, throws if open tables remain.
  /// Always archives sales/orders locally before deleting tenant data.
  Future<void> clearLocalBusinessData({bool skipOpenTableCheck = false}) async {
    if (!skipOpenTableCheck && await hasAnyOpenTableBusiness()) {
      throw StateError(
        'Ka tavolina me porosi të hapura. Paguaj ose mbyll porositë '
        'para se të pastrosh të dhënat lokale.',
      );
    }
    await archiveClosedOrdersBeforeReset();
    final db = await database;
    await db.transaction((txn) async {
      for (final table in DatabaseSchema.tenantResetTables) {
        await txn.delete(table);
      }
      await DatabaseSchema.seedEmptyTables(txn);
      await txn.update(
        'shift',
        {
          'status': 'closed',
          'openedAt': null,
          'closedAt': null,
        },
        where: 'id = 1',
      );
    });
    for (final key in DatabaseSchema.tenantResetAppMetaKeys) {
      if (key == 'global_order_number') {
        await setAppMeta(key, '0');
      } else {
        await setAppMeta(key, '');
      }
    }
    await ensureDefaultMenuPresent();
  }

  /// Rikthen kategori/pije parazgjedhura nëse mungojnë.
  Future<void> ensureDefaultMenuPresent() async {
    final db = await database;
    await DatabaseSchema.ensureDefaultMenuPresent(db);
  }

  /// Returns true if any scoped table has rows stamped with [businessId].
  Future<bool> hasLocalDataForBusiness(String businessId) async {
    final db = await database;
    final tables = [
      ...DatabaseSchema.syncScopeTables,
      'inventory_items',
      'stock_movements',
    ];
    for (final table in tables) {
      final rows = await db.rawQuery(
        'SELECT 1 FROM $table WHERE businessId = ? LIMIT 1',
        [businessId],
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  /// Returns true if any operational table has rows for another business.
  ///
  /// [audit_logs] is not checked — preserved immutable history may reference
  /// prior tenants and must not block wipe or diagnostics.
  Future<bool> hasLocalDataForOtherBusiness(String businessId) async {
    final db = await database;
    for (final table in DatabaseSchema.tenantForeignDataCheckTables) {
      final rows = await db.rawQuery(
        'SELECT 1 FROM $table '
        'WHERE businessId IS NOT NULL AND businessId != ? '
        'LIMIT 1',
        [businessId],
      );
      if (rows.isNotEmpty) return true;
    }
    for (final table in ['inventory_items', 'stock_movements']) {
      final rows = await db.rawQuery(
        'SELECT 1 FROM $table '
        'WHERE businessId IS NOT NULL AND businessId != ? '
        'LIMIT 1',
        [businessId],
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  /// Rough signal that the device has operational data (not just empty schema).
  Future<bool> hasMeaningfulLocalBusinessData() async {
    final db = await database;
    final checks = <String>[
      'SELECT COUNT(*) AS c FROM sales',
      'SELECT COUNT(*) AS c FROM expenses',
      'SELECT COUNT(*) AS c FROM waiters',
      'SELECT COUNT(*) AS c FROM products',
      'SELECT COUNT(*) AS c FROM outbox',
    ];
    for (final sql in checks) {
      final count = Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
      if (count > 0) return true;
    }
    final occupied = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) AS c FROM tables WHERE occupied = 1'),
    );
    return (occupied ?? 0) > 0;
  }

  // ─────────────────────── OUTBOX DIAGNOSTICS ──────────────────────────────

  Future<int> getPendingOutboxCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM outbox WHERE syncStatus = ?',
      [DatabaseSchema.kSyncStatusPending],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> getFailedOutboxCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM outbox WHERE syncStatus = ?',
      [DatabaseSchema.kOutboxSyncFailed],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentFailedOutboxEvents({
    int limit = 10,
  }) async {
    final db = await database;
    return db.query(
      'outbox',
      where: 'syncStatus = ?',
      whereArgs: [DatabaseSchema.kOutboxSyncFailed],
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
  }

  /// All failed outbox rows, newest first (no row cap).
  Future<List<Map<String, dynamic>>> getAllFailedOutboxEvents() async {
    final db = await database;
    return db.query(
      'outbox',
      where: 'syncStatus = ?',
      whereArgs: [DatabaseSchema.kOutboxSyncFailed],
      orderBy: 'updatedAt DESC',
    );
  }

  /// Resets one failed outbox row to pending. Returns `true` if a row was updated.
  Future<bool> retryFailedOutboxEvent(String uuid) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final count = await db.update(
      'outbox',
      {
        'syncStatus': DatabaseSchema.kSyncStatusPending,
        'lastError': null,
        'retryCount': 0,
        'updatedAt': now,
      },
      where: 'uuid = ? AND syncStatus = ?',
      whereArgs: [uuid, DatabaseSchema.kOutboxSyncFailed],
    );
    return count > 0;
  }

  /// Resets all failed outbox events to pending so they are retried on next push.
  Future<int> retryFailedOutboxEvents() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.update(
      'outbox',
      {
        'syncStatus': DatabaseSchema.kSyncStatusPending,
        'lastError':  null,
        'retryCount': 0,
        'updatedAt':  now,
      },
      where: 'syncStatus = ?',
      whereArgs: [DatabaseSchema.kOutboxSyncFailed],
    );
  }

  /// Deletes already-synced outbox rows and clears the stored sync error flag.
  Future<void> clearResolvedSyncErrors() async {
    final db = await database;
    await db.delete(
      'outbox',
      where: 'syncStatus = ?',
      whereArgs: [DatabaseSchema.kOutboxSyncSynced],
    );
    await setAppMeta('sync_last_error', '');
  }

  /// Removes legacy outbox rows whose [entityType] is not supported by pos_api.
  ///
  /// Only touches the [outbox] table. Does not run automatically — call from
  /// sync diagnostics or another operator-controlled action.
  Future<UnsupportedOutboxCleanupResult> cleanupUnsupportedOutboxEvents() async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'outbox',
        columns: ['id', 'entityType'],
      );

      final idsToDelete = <Object>[];
      final removedByEntityType = <String, int>{};

      for (final row in rows) {
        final rawType = row['entityType'] as String? ?? '';
        if (isSupportedSyncEntityType(rawType)) continue;

        final id = row['id'];
        if (id == null) continue;

        idsToDelete.add(id);
        final key = normalizeSyncEntityType(rawType);
        removedByEntityType[key] = (removedByEntityType[key] ?? 0) + 1;
      }

      if (idsToDelete.isNotEmpty) {
        final placeholders = List.filled(idsToDelete.length, '?').join(',');
        await txn.delete(
          'outbox',
          where: 'id IN ($placeholders)',
          whereArgs: idsToDelete,
        );
      }

      final result = UnsupportedOutboxCleanupResult(
        totalRemoved: idsToDelete.length,
        removedByEntityType: removedByEntityType,
      );

      if (result.totalRemoved > 0) {
        debugPrint('[SyncCleanup] Removed unsupported outbox rows:');
        final sortedKeys = result.removedByEntityType.keys.toList()..sort();
        for (final key in sortedKeys) {
          debugPrint('- $key: ${result.removedByEntityType[key]}');
        }
      }

      return result;
    });
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
    final scope = await syncScope();
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
        'deviceId':     deviceId ?? scope['deviceId'],
        'sessionId':    sessionId,
        'terminalName': terminalName,
        'appVersion':   appVersion,
        'platform':     platform,
        'uuid':         DatabaseSchema.generateUuid(),
        'businessId':   scope['businessId'],
        'branchId':     scope['branchId'],
        'updatedAt':    now,
        ...syncStatus(),
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

  // ─────────────────────────── INVENTORY ────────────────────────────────────

  /// Registers a stock-tracked item (not linked to POS sale deduction yet).
  Future<int> insertInventoryItem({
    required String name,
    required String unit,
    String? productUuid,
    double currentQuantity = 0,
    double lowStockThreshold = 0,
    double costPerUnit = 0,
    bool isActive = true,
  }) async {
    final db = await database;
    final scope = await syncScope();
    final ts = syncTimestamps();
    final itemId = await db.insert('inventory_items', {
      'uuid': DatabaseSchema.generateUuid(),
      'productUuid': productUuid,
      'name': name,
      'unit': unit,
      'currentQuantity': currentQuantity,
      'lowStockThreshold': lowStockThreshold,
      'costPerUnit': costPerUnit,
      'isActive': isActive ? 1 : 0,
      ...scope,
      ...ts,
      ...syncStatus(),
    });
    await _queueOutboxById(
      'inventory_items',
      'inventory_items',
      itemId,
      operation: 'create',
    );
    return itemId;
  }

  /// Updates an inventory item; soft-delete via [deletedAt] / [isActive] = 0.
  Future<void> updateInventoryItem(
    int id,
    Map<String, dynamic> fields,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final patch = Map<String, Object?>.from(fields);
    patch['updatedAt'] = patch['updatedAt'] ?? now;
    patch['syncStatus'] = DatabaseSchema.kSyncStatusPending;
    patch['lastSyncedAt'] = null;
    if (patch.containsKey('isActive') && patch['isActive'] is bool) {
      patch['isActive'] = (patch['isActive'] as bool) ? 1 : 0;
    }
    await db.update(
      'inventory_items',
      patch,
      where: 'id = ?',
      whereArgs: [id],
    );
    final row = await _fetchEntityRow(
      'inventory_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (row != null) {
      final deleted = row['deletedAt'] != null ||
          (row['isActive'] as num?)?.toInt() == 0;
      await _queueOutboxRow(
        'inventory_items',
        row,
        deleted ? 'delete' : 'update',
      );
    }
  }

  /// Active, non-deleted inventory items.
  Future<List<Map<String, dynamic>>> getInventoryItems({
    bool includeInactive = false,
  }) async {
    final db = await database;
    final where = <String>['deletedAt IS NULL'];
    if (!includeInactive) {
      where.add('isActive = 1');
    }
    return db.query(
      'inventory_items',
      where: where.join(' AND '),
      orderBy: 'name ASC',
    );
  }

  /// Items at or below [lowStockThreshold] (active, not deleted).
  Future<List<Map<String, dynamic>>> getLowStockItems() async {
    final db = await database;
    return db.query(
      'inventory_items',
      where: 'deletedAt IS NULL AND isActive = 1 '
          'AND currentQuantity <= lowStockThreshold',
      orderBy: 'currentQuantity ASC, name ASC',
    );
  }

  /// Records stock movement and updates [currentQuantity] atomically.
  Future<int> insertStockMovement({
    required String inventoryItemUuid,
    required String movementType,
    required double quantity,
    String? reason,
    String? referenceType,
    String? referenceUuid,
  }) async {
    if (!DatabaseSchema.stockMovementTypes.contains(movementType)) {
      throw ArgumentError.value(
        movementType,
        'movementType',
        'Must be one of: ${DatabaseSchema.stockMovementTypes.join(', ')}',
      );
    }
    if (movementType != 'adjustment' && quantity == 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be non-zero');
    }

    final db = await database;
    final scope = await syncScope();
    final ts = syncTimestamps();
    final delta = DatabaseSchema.stockQuantityDelta(movementType, quantity);

    final movementId = await db.transaction<int>((txn) async {
      final items = await txn.query(
        'inventory_items',
        where: 'uuid = ? AND deletedAt IS NULL',
        whereArgs: [inventoryItemUuid],
        limit: 1,
      );
      if (items.isEmpty) {
        throw StateError('Inventory item not found: $inventoryItemUuid');
      }
      final item = items.first;
      final itemId = item['id'] as int;
      final current = (item['currentQuantity'] as num).toDouble();
      final newQty = current + delta;
      final now = ts['updatedAt']!;

      await txn.update(
        'inventory_items',
        {
          'currentQuantity': newQty,
          'updatedAt': now,
          'syncStatus': DatabaseSchema.kSyncStatusPending,
          'lastSyncedAt': null,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      final movementId = await txn.insert('stock_movements', {
        'uuid': DatabaseSchema.generateUuid(),
        'inventoryItemUuid': inventoryItemUuid,
        'movementType': movementType,
        'quantity': quantity,
        'reason': reason,
        'referenceType': referenceType,
        'referenceUuid': referenceUuid,
        ...scope,
        ...ts,
        ...syncStatus(),
      });

      await _queueOutboxById(
        'inventory_items',
        'inventory_items',
        itemId,
        operation: 'update',
        txn: txn,
      );
      await _queueOutboxById(
        'stock_movements',
        'stock_movements',
        movementId,
        operation: 'create',
        txn: txn,
      );
      return movementId;
    });
    _scheduleSyncAfterLocalMutation();
    return movementId;
  }

  /// Movement history for one inventory item, newest first.
  Future<List<Map<String, dynamic>>> getStockMovementsForItem(
    String inventoryItemUuid, {
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      'stock_movements',
      where: 'inventoryItemUuid = ? AND deletedAt IS NULL',
      whereArgs: [inventoryItemUuid],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
  }

  // ───────────────────────────── OUTBOX ─────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchEntityRow(
    String table, {
    required String where,
    required List<Object?> whereArgs,
    Transaction? txn,
  }) async {
    final rows = txn != null
        ? await txn.query(
            table,
            where: where,
            whereArgs: whereArgs,
            limit: 1,
          )
        : await (await database).query(
            table,
            where: where,
            whereArgs: whereArgs,
            limit: 1,
          );
    return rows.isEmpty ? null : rows.first;
  }

  /// Enqueues one outbox row; optional [txn] keeps queue aligned with entity writes.
  Future<String> _enqueueOutbox({
    required String entityType,
    required String entityUuid,
    required String operation,
    required Map<String, dynamic> payload,
    Transaction? txn,
    String? businessId,
    String? branchId,
    String? deviceId,
  }) async {
    if (!isSupportedSyncEntityType(entityType)) {
      debugPrint(
        '[Sync] Skipping unsupported entityType: '
        '${normalizeSyncEntityType(entityType)}',
      );
      return '';
    }
    if (!DatabaseSchema.outboxOperations.contains(operation)) {
      throw ArgumentError.value(
        operation,
        'operation',
        'Must be one of: ${DatabaseSchema.outboxOperations.join(', ')}',
      );
    }
    final scope = await syncScope();
    final now = DateTime.now().toIso8601String();
    final eventUuid = DatabaseSchema.generateUuid();
    final row = <String, Object?>{
      'uuid': eventUuid,
      'businessId': businessId ?? scope['businessId']!,
      'branchId': branchId ?? scope['branchId']!,
      'deviceId': deviceId ?? scope['deviceId']!,
      'entityType': entityType,
      'entityUuid': entityUuid,
      'operation': operation,
      'payloadJson': jsonEncode(payload),
      'syncStatus': DatabaseSchema.kSyncStatusPending,
      'retryCount': 0,
      'createdAt': now,
      'updatedAt': now,
    };
    if (txn != null) {
      await txn.insert('outbox', row);
    } else {
      final db = await database;
      await db.insert('outbox', row);
    }
    if (txn == null) {
      _scheduleSyncAfterLocalMutation();
    }
    return eventUuid;
  }

  /// Nudges immediate outbox push after a successful local commit (non-blocking).
  void _scheduleSyncAfterLocalMutation() {
    unawaited(BackgroundSyncService.instance.triggerImmediateSync());
  }

  Future<void> _queueOutboxRow(
    String entityType,
    Map<String, dynamic> row,
    String operation, {
    Transaction? txn,
    Map<String, dynamic>? payloadExtras,
  }) async {
    final entityUuid = row['uuid'] as String?;
    if (entityUuid == null || entityUuid.isEmpty) return;
    final payload = Map<String, dynamic>.from(row);
    if (payloadExtras != null) {
      payload.addAll(payloadExtras);
    }
    await _enqueueOutbox(
      entityType: entityType,
      entityUuid: entityUuid,
      operation: operation,
      payload: payload,
      txn: txn,
    );
  }

  Future<void> _queueOutboxById(
    String entityType,
    String table,
    Object id, {
    required String operation,
    String idColumn = 'id',
    Transaction? txn,
    Map<String, dynamic>? payloadExtras,
  }) async {
    final row = await _fetchEntityRow(
      table,
      where: '$idColumn = ?',
      whereArgs: [id],
      txn: txn,
    );
    if (row != null) {
      await _queueOutboxRow(
        entityType,
        row,
        operation,
        txn: txn,
        payloadExtras: payloadExtras,
      );
    }
  }

  Map<String, dynamic> _buildPrintedOrderPayload({
    required Map<String, dynamic> printRow,
    required List<Map<String, dynamic>> batchLines,
    String status = 'printed',
    String? saleUuid,
  }) {
    final tableId = (printRow['tableId'] as num).toInt();
    final entityUuid = printRow['uuid'] as String? ?? '';
    if (status == 'paid' && saleUuid != null && saleUuid.isNotEmpty) {
      return PrintedOrderSyncPayload.paidUpdate(
        uuid: entityUuid,
        saleUuid: saleUuid,
      );
    }
    return PrintedOrderSyncPayload.create(
      uuid: entityUuid,
      orderNumber: (printRow['orderNumber'] as num).toInt(),
      tableId: tableId,
      waiterName: printRow['waiterName'] as String,
      total: (printRow['total'] as num).toDouble(),
      itemsCount: PrintedOrderSyncPayload.itemsCountFromLines(batchLines),
      printedAt: printRow['printedAt'] as String,
    );
  }

  Future<void> _queuePrintedOrderOutbox({
    required Map<String, dynamic> printRow,
    required List<Map<String, dynamic>> batchLines,
    required String operation,
    Transaction? txn,
    String status = 'printed',
    String? saleUuid,
  }) async {
    final entityUuid = printRow['uuid'] as String?;
    if (entityUuid == null || entityUuid.isEmpty) return;

    if (operation == 'create' && txn != null) {
      final exists = await _hasOutboxEventForEntity(
        entityType: 'printed_orders',
        entityUuid: entityUuid,
        operation: 'create',
        txn: txn,
      );
      if (exists) return;
    }

    if (operation == 'update' &&
        status == 'paid' &&
        txn != null &&
        saleUuid != null) {
      final exists = await _hasOutboxEventForEntity(
        entityType: 'printed_orders',
        entityUuid: entityUuid,
        operation: 'update',
        txn: txn,
      );
      if (exists) return;
    }

    final payload = _buildPrintedOrderPayload(
      printRow: printRow,
      batchLines: batchLines,
      status: status,
      saleUuid: saleUuid,
    );
    await _enqueueOutbox(
      entityType: 'printed_orders',
      entityUuid: entityUuid,
      operation: operation,
      payload: payload,
      txn: txn,
    );
  }

  Future<void> _linkPrintedOrdersToSale({
    required int tableId,
    required String waiterName,
    required String saleUuid,
    required Transaction txn,
  }) async {
    final prints = await txn.query(
      'kitchen_prints',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
    );
    for (final printRow in prints) {
      final printId = (printRow['id'] as num).toInt();
      final lineRows = await txn.query(
        'kitchen_print_lines',
        where: 'printId = ?',
        whereArgs: [printId],
      );
      final batchLines = lineRows
          .map(
            (r) => <String, dynamic>{
              'qty': r['qty'],
            },
          )
          .toList();
      await _queuePrintedOrderOutbox(
        printRow: printRow,
        batchLines: batchLines,
        operation: 'update',
        txn: txn,
        status: 'paid',
        saleUuid: saleUuid,
      );
    }
  }

  Future<bool> _hasOutboxEventForEntity({
    required String entityType,
    required String entityUuid,
    required String operation,
    required Transaction txn,
  }) async {
    final rows = await txn.query(
      'outbox',
      columns: ['id'],
      where:
          'entityType = ? AND entityUuid = ? AND operation = ?',
      whereArgs: [entityType, entityUuid, operation],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _queueOutboxByIdIfAbsent(
    String entityType,
    String table,
    Object id, {
    required String operation,
    String idColumn = 'id',
    Transaction? txn,
    Map<String, dynamic>? payloadExtras,
  }) async {
    final row = await _fetchEntityRow(
      table,
      where: '$idColumn = ?',
      whereArgs: [id],
      txn: txn,
    );
    if (row == null) {
      // ignore: avoid_print
      print('[SyncDiag] WARN _queueOutboxByIdIfAbsent: row not found entityType=$entityType id=$id — outbox entry skipped');
      return;
    }
    final entityUuid = row['uuid'] as String?;
    if (entityUuid == null || entityUuid.isEmpty) {
      // ignore: avoid_print
      print('[SyncDiag] WARN _queueOutboxByIdIfAbsent: uuid is null/empty entityType=$entityType id=$id — outbox entry skipped');
      return;
    }
    if (txn != null) {
      final exists = await _hasOutboxEventForEntity(
        entityType: entityType,
        entityUuid: entityUuid,
        operation: operation,
        txn: txn,
      );
      if (exists) return;
    }
    await _queueOutboxRow(
      entityType,
      row,
      operation,
      txn: txn,
      payloadExtras: payloadExtras,
    );
  }

  /// Enqueues a local change for future upload. Does not perform network I/O.
  ///
  /// [operation] must be one of: `create`, `update`, `delete`.
  /// Returns the new event's [uuid].
  Future<String> insertOutboxEvent({
    required String entityType,
    required String entityUuid,
    required String operation,
    required String payloadJson,
    String? businessId,
    String? branchId,
    String? deviceId,
  }) async {
    return _enqueueOutbox(
      entityType: entityType,
      entityUuid: entityUuid,
      operation: operation,
      payload: jsonDecode(payloadJson) as Map<String, dynamic>,
      businessId: businessId,
      branchId: branchId,
      deviceId: deviceId,
    );
  }

  /// Pending outbox events — revenue entities first, then FIFO within tier.
  Future<List<Map<String, dynamic>>> getPendingOutboxEvents({
    int limit = 100,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT * FROM outbox
      WHERE syncStatus = ?
      ORDER BY
        CASE REPLACE(LOWER(TRIM(entityType)), '-', '_')
          WHEN 'sales' THEN 0
          WHEN 'sale_lines' THEN 1
          WHEN 'sale_adjustments' THEN 2
          WHEN 'categories' THEN 3
          WHEN 'products' THEN 4
          WHEN 'shifts' THEN 5
          WHEN 'expenses' THEN 6
          WHEN 'inventory_items' THEN 7
          WHEN 'stock_movements' THEN 8
          ELSE 50
        END ASC,
        createdAt ASC
      LIMIT ?
      ''',
      [DatabaseSchema.kSyncStatusPending, limit],
    );
  }

  /// Marks an outbox row as successfully synced.
  Future<void> markOutboxEventSynced(String uuid) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'outbox',
      {
        'syncStatus': DatabaseSchema.kOutboxSyncSynced,
        'lastSyncedAt': now,
        'updatedAt': now,
        'lastError': null,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Marks an outbox row as failed and increments [retryCount].
  Future<void> markOutboxEventFailed(String uuid, String error) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'outbox',
      columns: ['retryCount'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final retry = rows.isEmpty
        ? 1
        : ((rows.first['retryCount'] as num?)?.toInt() ?? 0) + 1;
    await db.update(
      'outbox',
      {
        'syncStatus': DatabaseSchema.kOutboxSyncFailed,
        'lastError': error,
        'retryCount': retry,
        'updatedAt': now,
        'lastAttemptAt': now,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}

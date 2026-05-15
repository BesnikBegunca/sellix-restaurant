import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

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
      version: 13,
      onCreate: DatabaseSchema.create,
      onUpgrade: DatabaseSchema.upgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await DatabaseSchema.ensureShiftsSnapshotColumn(db);
      },
    );
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

  Future<void> clearCurrentOrder(
    int tableId,
    String waiterName, {
    bool clearPrintHistory = false,
  }) async {
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
    if (clearPrintHistory) {
      await clearKitchenPrintsForTable(tableId, waiterName);
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
    final printedAt = DateTime.now().toIso8601String();
    var total = 0.0;
    for (final l in lines) {
      total += (l['lineTotal'] as num).toDouble();
    }
    return db.transaction<int>((txn) async {
      final printId = await txn.insert('kitchen_prints', {
        'tableId': tableId,
        'waiterName': waiterName,
        'orderNumber': orderNumber,
        'total': total,
        'printedAt': printedAt,
        'shiftId': shiftId,
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
        });
      }
      return printId;
    });
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

  Future<void> deleteKitchenPrint(int printId) async {
    final db = await database;
    await db.delete(
      'kitchen_print_lines',
      where: 'printId = ?',
      whereArgs: [printId],
    );
    await db.delete(
      'kitchen_prints',
      where: 'id = ?',
      whereArgs: [printId],
    );
  }

  Future<void> clearKitchenPrintsForTable(int tableId, String waiterName) async {
    final db = await database;
    final prints = await db.query(
      'kitchen_prints',
      where: 'tableId = ? AND waiterName = ?',
      whereArgs: [tableId, waiterName],
    );
    for (final p in prints) {
      await deleteKitchenPrint((p['id'] as num).toInt());
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
    await DatabaseSchema.ensureShiftsSnapshotColumn(db);
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

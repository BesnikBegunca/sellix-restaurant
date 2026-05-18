import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Applies a `/sync/pull` response into the local SQLite database.
///
/// All entity types are written inside a single caller-provided transaction.
/// Any exception propagates to the caller so the transaction is rolled back
/// and the pull cursor is NOT advanced.
class PullSyncApplyService {
  PullSyncApplyService._();
  static final PullSyncApplyService instance = PullSyncApplyService._();

  static const String _synced = 'synced';

  /// Apply all entity lists from a pull response inside [txn].
  ///
  /// [entities] is the `entities` map from the server response.
  /// [syncedAt]  is the ISO-8601 timestamp to stamp as [lastSyncedAt].
  ///
  /// Entity apply order matches FK dependency:
  ///   categories → products → shifts → sales → sale_lines →
  ///   sale_adjustments → expenses → inventory_items → stock_movements
  Future<PullSyncApplyResult> applyEntities(
    Map<String, dynamic> entities,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    var upserted = 0;
    var skipped = 0;
    var softDeleted = 0;

    void add(_ApplyStats s) {
      upserted += s.upserted;
      skipped += s.skipped;
      softDeleted += s.softDeleted;
    }

    add(await _applyList(entities['categories'], (e) => _applyCategory(e, txn, syncedAt)));
    add(await _applyList(entities['products'],   (e) => _applyProduct(e, txn, syncedAt)));
    add(await _applyList(entities['shifts'],      (e) => _applyShift(e, txn, syncedAt)));
    add(await _applyList(entities['sales'],       (e) => _applySale(e, txn, syncedAt)));
    add(await _applyList(entities['sale_lines'],  (e) => _applySaleLine(e, txn, syncedAt)));
    add(await _applyList(entities['sale_adjustments'], (e) => _applySaleAdjustment(e, txn, syncedAt)));
    add(await _applyList(entities['expenses'],         (e) => _applyExpense(e, txn, syncedAt)));
    add(await _applyList(entities['inventory_items'],  (e) => _applyInventoryItem(e, txn, syncedAt)));
    add(await _applyList(entities['stock_movements'],  (e) => _applyStockMovement(e, txn, syncedAt)));

    return PullSyncApplyResult(
      upserted: upserted,
      skipped: skipped,
      softDeleted: softDeleted,
    );
  }

  // ── Internal dispatch ───────────────────────────────────────────────────────

  Future<_ApplyStats> _applyList(
    dynamic list,
    Future<_RowAction> Function(Map<String, dynamic>) applyOne,
  ) async {
    if (list is! List || list.isEmpty) return const _ApplyStats(0, 0, 0);
    var upserted = 0;
    var skipped = 0;
    var softDeleted = 0;
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final action = await applyOne(item);
      switch (action) {
        case _RowAction.upserted:   upserted++;   break;
        case _RowAction.softDeleted: softDeleted++; break;
        case _RowAction.skipped:    skipped++;    break;
      }
    }
    return _ApplyStats(upserted, skipped, softDeleted);
  }

  // ── Entity apply methods ────────────────────────────────────────────────────

  Future<_RowAction> _applyCategory(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'categories',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip category $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'categories',
        {
          'name':       e['name'] as String? ?? '',
          'sortOrder':  e['sortOrder'] as int? ?? 0,
          'businessId': e['businessId'],
          'branchId':   e['branchId'],
          'deviceId':   e['deviceId'],
          'updatedAt':  e['updatedAt'],
          'deletedAt':  deletedAt,
          'syncStatus': _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'categories',
        {
          'id':           e['id'] as String? ?? uuid,
          'uuid':         uuid,
          'name':         e['name'] as String? ?? '',
          'iconCodePoint': 0,
          'sortOrder':    e['sortOrder'] as int? ?? 0,
          'businessId':   e['businessId'],
          'branchId':     e['branchId'],
          'deviceId':     e['deviceId'],
          'createdAt':    e['createdAt'],
          'updatedAt':    e['updatedAt'],
          'deletedAt':    deletedAt,
          'syncStatus':   _synced,
          'lastSyncedAt': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applyProduct(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'products',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip product $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'products',
        {
          'name':       e['name'] as String? ?? '',
          'price':      _toDouble(e['price']),
          'categoryId': e['categoryUuid'] ?? '',
          'businessId': e['businessId'],
          'branchId':   e['branchId'],
          'deviceId':   e['deviceId'],
          'updatedAt':  e['updatedAt'],
          'deletedAt':  deletedAt,
          'syncStatus': _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'products',
        {
          'id':         e['id'] as String? ?? uuid,
          'uuid':       uuid,
          'name':       e['name'] as String? ?? '',
          'price':      _toDouble(e['price']),
          'emoji':      '☕',
          'categoryId': e['categoryUuid'] ?? '',
          'businessId': e['businessId'],
          'branchId':   e['branchId'],
          'deviceId':   e['deviceId'],
          'createdAt':  e['createdAt'],
          'updatedAt':  e['updatedAt'],
          'deletedAt':  deletedAt,
          'syncStatus': _synced,
          'lastSyncedAt': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applyShift(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'shifts',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip shift $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'shifts',
        {
          'status':      e['status'] as String? ?? 'open',
          'openedAt':    e['openedAt'],
          'closedAt':    e['closedAt'],
          'openingCash': _toDouble(e['openingCash']),
          'businessId':  e['businessId'],
          'branchId':    e['branchId'],
          'deviceId':    e['deviceId'],
          'createdAt':   e['createdAt'],
          'updatedAt':   e['updatedAt'],
          'deletedAt':   deletedAt,
          'syncStatus':  _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'shifts',
        {
          'uuid':        uuid,
          'status':      e['status'] as String? ?? 'open',
          'openedAt':    e['openedAt'] as String? ?? syncedAt,
          'closedAt':    e['closedAt'],
          'openingCash': _toDouble(e['openingCash']),
          'businessId':  e['businessId'],
          'branchId':    e['branchId'],
          'deviceId':    e['deviceId'],
          'createdAt':   e['createdAt'],
          'updatedAt':   e['updatedAt'],
          'deletedAt':   deletedAt,
          'syncStatus':  _synced,
          'lastSyncedAt': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applySale(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'sales',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip sale $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'sales',
        {
          'total':      _toDouble(e['total']),
          'businessId': e['businessId'],
          'branchId':   e['branchId'],
          'deviceId':   e['deviceId'],
          'updatedAt':  e['updatedAt'],
          'deletedAt':  deletedAt,
          'syncStatus': _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'sales',
        {
          'uuid':       uuid,
          'waiterName': '',
          'tableId':    0,
          'total':      _toDouble(e['total']),
          'timestamp':  e['soldAt'] as String? ?? syncedAt,
          'businessId': e['businessId'],
          'branchId':   e['branchId'],
          'deviceId':   e['deviceId'],
          'createdAt':  e['createdAt'],
          'updatedAt':  e['updatedAt'],
          'deletedAt':  deletedAt,
          'syncStatus': _synced,
          'lastSyncedAt': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applySaleLine(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'sale_lines',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip sale_line $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'sale_lines',
        {
          'productId':    e['productUuid'],
          'productName':  e['name'] as String? ?? '',
          'productPrice': _toDouble(e['price']),
          'quantity':     _toInt(e['quantity']),
          'lineTotal':    _toDouble(e['lineTotal']),
          'businessId':   e['businessId'],
          'branchId':     e['branchId'],
          'deviceId':     e['deviceId'],
          'updatedAt':    e['updatedAt'],
          'deletedAt':    deletedAt,
          'syncStatus':   _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      // Resolve local integer saleId from saleUuid — skip if parent missing.
      final saleUuid = e['saleUuid'] as String?;
      final saleRows = saleUuid == null
          ? <Map<String, Object?>>[]
          : await txn.query('sales', columns: ['id'], where: 'uuid = ?', whereArgs: [saleUuid], limit: 1);
      if (saleRows.isEmpty) {
        if (kDebugMode) debugPrint('PullSync: skip sale_line $uuid (parent sale not found)');
        return _RowAction.skipped;
      }
      await txn.insert(
        'sale_lines',
        {
          'uuid':         uuid,
          'saleId':       saleRows.first['id'] as int,
          'productId':    e['productUuid'],
          'productName':  e['name'] as String? ?? '',
          'productPrice': _toDouble(e['price']),
          'quantity':     _toInt(e['quantity']),
          'lineTotal':    _toDouble(e['lineTotal']),
          'createdAt':    e['createdAt'] as String? ?? syncedAt,
          'businessId':   e['businessId'],
          'branchId':     e['branchId'],
          'deviceId':     e['deviceId'],
          'updatedAt':    e['updatedAt'],
          'deletedAt':    deletedAt,
          'syncStatus':   _synced,
          'lastSyncedAt': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applySaleAdjustment(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'sale_adjustments',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip sale_adjustment $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'sale_adjustments',
        {
          'amount':     _toDouble(e['amount']),
          'reason':     e['reason'],
          'businessId': e['businessId'],
          'branchId':   e['branchId'],
          'deviceId':   e['deviceId'],
          'updatedAt':  e['updatedAt'],
          'deletedAt':  deletedAt,
          'syncStatus': _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      final saleUuid = e['saleUuid'] as String?;
      final saleRows = saleUuid == null
          ? <Map<String, Object?>>[]
          : await txn.query('sales', columns: ['id'], where: 'uuid = ?', whereArgs: [saleUuid], limit: 1);
      if (saleRows.isEmpty) {
        if (kDebugMode) debugPrint('PullSync: skip sale_adjustment $uuid (parent sale not found)');
        return _RowAction.skipped;
      }
      await txn.insert(
        'sale_adjustments',
        {
          'uuid':           uuid,
          'saleId':         saleRows.first['id'] as int,
          'adjustmentType': e['type'] as String? ?? '',
          'amount':         _toDouble(e['amount']),
          'reason':         e['reason'],
          'createdAt':      e['createdAt'] as String? ?? syncedAt,
          'businessId':     e['businessId'],
          'branchId':       e['branchId'],
          'deviceId':       e['deviceId'],
          'updatedAt':      e['updatedAt'],
          'deletedAt':      deletedAt,
          'syncStatus':     _synced,
          'lastSyncedAt':   syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applyExpense(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'expenses',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip expense $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'expenses',
        {
          'type':        e['category'] as String? ?? '',
          'description': e['description'] as String? ?? '',
          'amount':      _toDouble(e['amount']),
          'businessId':  e['businessId'],
          'branchId':    e['branchId'],
          'deviceId':    e['deviceId'],
          'updatedAt':   e['updatedAt'],
          'deletedAt':   deletedAt,
          'syncStatus':  _synced,
          'lastSyncedAt': syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'expenses',
        {
          'uuid':        uuid,
          'type':        e['category'] as String? ?? '',
          'description': e['description'] as String? ?? '',
          'amount':      _toDouble(e['amount']),
          'timestamp':   e['expenseAt'] as String? ?? syncedAt,
          'businessId':  e['businessId'],
          'branchId':    e['branchId'],
          'deviceId':    e['deviceId'],
          'createdAt':   e['createdAt'],
          'updatedAt':   e['updatedAt'],
          'deletedAt':   deletedAt,
          'syncStatus':  _synced,
          'lastSyncedAt': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applyInventoryItem(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'inventory_items',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip inventory_item $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'inventory_items',
        {
          'productUuid':       e['productUuid'],
          'name':              e['name'] as String? ?? '',
          'unit':              e['unit'] as String? ?? 'pcs',
          'currentQuantity':   _toDouble(e['currentQuantity']),
          'lowStockThreshold': _toDouble(e['lowStockThreshold']),
          'costPerUnit':       _toDouble(e['costPerUnit']),
          'isActive':          e['isActive'] == true ? 1 : 0,
          'businessId':        e['businessId'],
          'branchId':          e['branchId'],
          'deviceId':          e['deviceId'],
          'updatedAt':         e['updatedAt'] as String? ?? syncedAt,
          'deletedAt':         deletedAt,
          'syncStatus':        _synced,
          'lastSyncedAt':      syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'inventory_items',
        {
          'uuid':              uuid,
          'productUuid':       e['productUuid'],
          'name':              e['name'] as String? ?? '',
          'unit':              e['unit'] as String? ?? 'pcs',
          'currentQuantity':   _toDouble(e['currentQuantity']),
          'lowStockThreshold': _toDouble(e['lowStockThreshold']),
          'costPerUnit':       _toDouble(e['costPerUnit']),
          'isActive':          e['isActive'] == true ? 1 : 0,
          'businessId':        e['businessId'],
          'branchId':          e['branchId'],
          'deviceId':          e['deviceId'],
          'createdAt':         e['createdAt'] as String? ?? syncedAt,
          'updatedAt':         e['updatedAt'] as String? ?? syncedAt,
          'deletedAt':         deletedAt,
          'syncStatus':        _synced,
          'lastSyncedAt':      syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  Future<_RowAction> _applyStockMovement(
    Map<String, dynamic> e,
    DatabaseExecutor txn,
    String syncedAt,
  ) async {
    final uuid = e['uuid'] as String?;
    if (uuid == null) return _RowAction.skipped;

    final deletedAt = e['deletedAt'] as String?;
    final existing = await txn.query(
      'stock_movements',
      columns: ['syncStatus'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (existing.first['syncStatus'] == 'pending') {
        if (kDebugMode) debugPrint('PullSync: skip stock_movement $uuid (pending)');
        return _RowAction.skipped;
      }
      await txn.update(
        'stock_movements',
        {
          'inventoryItemUuid': e['inventoryItemUuid'] as String? ?? '',
          'movementType':      e['movementType'] as String? ?? 'adjustment',
          'quantity':          _toDouble(e['quantity']),
          'reason':            e['reason'],
          'referenceType':     e['referenceType'],
          'referenceUuid':     e['referenceUuid'],
          'businessId':        e['businessId'],
          'branchId':          e['branchId'],
          'deviceId':          e['deviceId'],
          'updatedAt':         e['updatedAt'] as String? ?? syncedAt,
          'deletedAt':         deletedAt,
          'syncStatus':        _synced,
          'lastSyncedAt':      syncedAt,
        },
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
    } else {
      await txn.insert(
        'stock_movements',
        {
          'uuid':              uuid,
          'inventoryItemUuid': e['inventoryItemUuid'] as String? ?? '',
          'movementType':      e['movementType'] as String? ?? 'adjustment',
          'quantity':          _toDouble(e['quantity']),
          'reason':            e['reason'],
          'referenceType':     e['referenceType'],
          'referenceUuid':     e['referenceUuid'],
          'businessId':        e['businessId'],
          'branchId':          e['branchId'],
          'deviceId':          e['deviceId'],
          'createdAt':         e['createdAt'] as String? ?? syncedAt,
          'updatedAt':         e['updatedAt'] as String? ?? syncedAt,
          'deletedAt':         deletedAt,
          'syncStatus':        _synced,
          'lastSyncedAt':      syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return deletedAt != null ? _RowAction.softDeleted : _RowAction.upserted;
  }

  // ── Type coercion helpers ───────────────────────────────────────────────────

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

// ── Result types ────────────────────────────────────────────────────────────

class PullSyncApplyResult {
  const PullSyncApplyResult({
    required this.upserted,
    required this.skipped,
    required this.softDeleted,
  });

  final int upserted;
  final int skipped;
  final int softDeleted;

  int get total => upserted + skipped + softDeleted;
}

enum _RowAction { upserted, softDeleted, skipped }

class _ApplyStats {
  const _ApplyStats(this.upserted, this.skipped, this.softDeleted);
  final int upserted;
  final int skipped;
  final int softDeleted;
}

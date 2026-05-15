part of 'manager_data.dart';

extension TablesMethods on ManagerData {
  // ─────────────────────────── tables ───────────────────────────────────────

  Future<void> setTableLayout({required int count, required int perRow}) async {
    tableCount = count.clamp(1, 48);
    tablesPerRow = perRow.clamp(2, 12);

    // Sync DB: insert missing tables, remove extras
    final existing = {for (final t in _cashierTables) t.id: t};
    final db = DatabaseService.instance;

    for (var i = 1; i <= tableCount; i++) {
      if (!existing.containsKey(i)) {
        await db.insertTable(i);
      }
    }
    for (final t in _cashierTables) {
      if (t.id > tableCount) {
        await db.deleteTable(t.id);
      }
    }

    // Rebuild cache from DB to reflect exact state
    final rows = await db.fetchTables();
    _cashierTables = rows.map(TableInfo.fromMap).toList();
    _notify();
  }

  Future<void> updateTableTotal(int tableId, double total, String waiterName) async {
    final current = _cashierTables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableInfo(id: tableId, occupied: false),
    );
    await DatabaseService.instance.updateTable(
      tableId,
      occupied: true,
      currentTotal: total,
      assignedWaiterName: waiterName,
      currentOrderNumber: current.currentOrderNumber,
    );
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(
        id: t.id,
        occupied: true,
        currentTotal: total,
        assignedWaiterName: waiterName,
        currentOrderNumber: t.currentOrderNumber,
      );
    }).toList();
    _notify();
  }

  Future<void> clearTable(int tableId, String waiterName) async {
    final current = _cashierTables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableInfo(id: tableId, occupied: false),
    );
    await DatabaseService.instance.updateTable(
      tableId,
      occupied: false,
      currentTotal: null,
      assignedWaiterName: null,
      currentOrderNumber: current.currentOrderNumber ?? 0,
    );
    await DatabaseService.instance.clearCurrentOrder(tableId, waiterName);
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(
        id: t.id,
        occupied: false,
        currentTotal: null,
        assignedWaiterName: null,
        currentOrderNumber: t.currentOrderNumber ?? 0,
      );
    }).toList();
    _notify();
  }

  Future<void> addCashierTable() async {
    final nextId = _cashierTables.isEmpty
        ? 1
        : _cashierTables.map((e) => e.id).reduce(math.max) + 1;
    await DatabaseService.instance.insertTable(nextId);
    _cashierTables = [
      ..._cashierTables,
      TableInfo(id: nextId, occupied: false),
    ];
    tableCount = _cashierTables.length;
    _notify();
  }

  Future<void> saveCurrentOrder({
    required int tableId,
    required int orderNumber,
    required String waiterName,
    required List<CurrentOrderLine> lines,
  }) async {
    final currentTotal = lines.fold<double>(
      0,
      (sum, l) => sum + (l.product.price * l.qty),
    );
    final db = DatabaseService.instance;
    await db.upsertCurrentOrderMeta(
      tableId: tableId,
      waiterName: waiterName,
      orderNumber: orderNumber,
      currentTotal: currentTotal,
    );
    await db.replaceCurrentOrderLines(
      tableId,
      waiterName,
      lines
          .map(
            (l) => {
              'productId': l.product.id,
              'productName': l.product.name,
              'productPrice': l.product.price,
              'productEmoji': l.product.emoji,
              'imagePath': l.product.imagePath,
              'qty': l.qty,
            },
          )
          .toList(),
    );

    final current = _cashierTables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableInfo(id: tableId, occupied: false),
    );
    await db.updateTable(
      tableId,
      occupied: lines.isNotEmpty,
      currentTotal: currentTotal == 0 ? null : currentTotal,
      assignedWaiterName: waiterName,
      currentOrderNumber: orderNumber,
    );
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(
        id: t.id,
        occupied: lines.isNotEmpty,
        currentTotal: currentTotal == 0 ? null : currentTotal,
        assignedWaiterName: waiterName,
        currentOrderNumber: orderNumber,
      );
    }).toList();
    _notify();
  }

  Future<List<CurrentOrderLine>> loadCurrentOrderLines(
    int tableId,
    String waiterName,
  ) async {
    final rows = await DatabaseService.instance.fetchCurrentOrderLines(
      tableId,
      waiterName,
    );
    return rows
        .map(
          (r) => CurrentOrderLine(
            product: ProductItem(
              id: r['productId'] as String,
              name: r['productName'] as String,
              price: (r['productPrice'] as num).toDouble(),
              emoji: r['productEmoji'] as String? ?? '☕',
              imagePath: r['imagePath'] as String?,
            ),
            qty: (r['qty'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<TableInfo>> tablesForWaiter(String waiterName) async {
    final rows = await DatabaseService.instance.fetchCurrentOrderMetasForWaiter(
      waiterName,
    );
    final byTable = <int, Map<String, dynamic>>{
      for (final r in rows) (r['tableId'] as num).toInt(): r,
    };
    return _cashierTables.map((t) {
      final m = byTable[t.id];
      if (m == null) {
        return TableInfo(
          id: t.id,
          occupied: false,
          currentTotal: null,
          currentOrderNumber: t.currentOrderNumber ?? 0,
        );
      }
      return TableInfo(
        id: t.id,
        occupied: true,
        currentTotal: (m['currentTotal'] as num).toDouble(),
        assignedWaiterName: waiterName,
        currentOrderNumber: (m['orderNumber'] as num).toInt(),
      );
    }).toList();
  }


}

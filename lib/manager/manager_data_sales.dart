part of 'manager_data.dart';

extension SalesMethods on ManagerData {
  // ─────────────────────────── sales / top employee ─────────────────────────

  Future<void> recordSale(
    String waiterName,
    double amount, {
    int tableId = 0,
  }) async {
    LicenseGateService.instance.enforceOrThrow();
    if (waiterName.trim().isEmpty) return;
    final now = DateTime.now();
    await SalesRepository.instance.insertSale(
      waiterName: waiterName,
      tableId: tableId,
      total: amount,
      shiftId: _currentShiftId,
    );
    final sale = SaleRow(
      waiterName: waiterName,
      tableId: tableId,
      total: amount,
      timestamp: now,
      shiftId: _currentShiftId,
    );
    _salesHistory.insert(0, sale);
    waiterSales[waiterName] = (waiterSales[waiterName] ?? 0) + amount;
    _notify();
  }

  /// Records a sale together with its per-product line items in one atomic
  /// transaction.  If the DB write fails the exception propagates to the caller
  /// (the payment UI) and neither the sale header nor any line row is written.
  ///
  /// All product fields (name, price, emoji, category) are snapshotted at call
  /// time, so future catalogue edits never alter historical records.
  /// Persists sale + lines idempotently; returns DB result for payment UI.
  Future<SaleInsertResult> recordSaleWithLines({
    required String saleUuid,
    required String waiterName,
    required double total,
    required int tableId,
    required String tableName,
    required List<CurrentOrderLine> lines,
    int? orderNumber,
  }) async {
    LicenseGateService.instance.enforceOrThrow();
    if (waiterName.trim().isEmpty) {
      throw StateError('Kamarieri mungon.');
    }

    // Build categoryName snapshot from the current in-memory menu.
    final categoryByProductId = <String, String>{};
    for (final cat in _categories) {
      for (final p in cat.products) {
        categoryByProductId[p.id] = cat.name;
      }
    }

    final lineMaps = lines.map((l) {
      final lineTotal = double.parse(
        (l.product.price * l.qty).toStringAsFixed(2),
      );
      return <String, dynamic>{
        'productId': l.product.id,
        'productName': l.product.name,
        'productEmoji': l.product.emoji,
        'productImagePath': l.product.imagePath,
        'productPrice': l.product.price,
        'quantity': l.qty,
        'lineTotal': lineTotal,
        'categoryName': categoryByProductId[l.product.id],
        'tableName': tableName,
        'waiterName': waiterName,
      };
    }).toList();

    final now = DateTime.now();
    final result = await SalesRepository.instance.insertSaleWithLines(
      saleUuid: saleUuid,
      waiterName: waiterName,
      tableId: tableId,
      total: total,
      lines: lineMaps,
      shiftId: _currentShiftId,
      orderNumber: orderNumber,
      tableName: tableName,
    );

    if (result.wasExisting) {
      await _reloadSales();
    } else {
      final sale = SaleRow(
        dbId: result.saleId,
        waiterName: waiterName,
        tableId: tableId,
        total: total,
        timestamp: now,
        shiftId: _currentShiftId,
      );
      _salesHistory.insert(0, sale);
      waiterSales[waiterName] = (waiterSales[waiterName] ?? 0) + total;
      AuditLogService.instance.logSale(
        waiterName: waiterName,
        saleId: result.saleId,
        tableId: tableId,
        total: total,
        itemCount: lines.length,
        shiftId: _currentShiftId,
      );
    }
    _notify();
    return result;
  }

  /// Resolves stable sale UUID for payment (reuses pending if sale already saved).
  Future<String> resolvePaymentSaleUuid({
    required int tableId,
    required String waiterName,
  }) =>
      SalesRepository.instance.resolvePaymentSaleUuid(
        tableId: tableId,
        waiterName: waiterName,
      );

  Future<void> clearPendingPaymentSaleUuid(
    int tableId,
    String waiterName,
  ) =>
      SalesRepository.instance.clearPendingPaymentSaleUuid(
        tableId,
        waiterName,
      );

  /// Resets waiter totals for the current view without deleting any DB records.
  /// Historical sales are permanently preserved in [_salesHistory].
  Future<void> clearWaiterSales() async {
    waiterSales = {};
    _notify();
  }

  /// Fshin plotësisht një porosi (shitje + rreshta) dhe përditëson totalin e kamarierit.
  Future<void> voidSale({
    required int saleId,
    String? reason,
    String? performedBy,
  }) async {
    SaleRow? sale;
    for (final s in _salesHistory) {
      if (s.dbId == saleId) {
        sale = s;
        break;
      }
    }
    if (sale == null) {
      throw StateError('Porosia #$saleId nuk u gjet.');
    }

    await SalesRepository.instance.deleteSaleById(saleId);
    AuditLogService.instance.logAdjustment(
      adjustmentType: 'void',
      saleId: saleId,
      amount: sale.total,
      reason: reason ?? tr.porosiFshireMenaxheri,
      performedBy: performedBy ?? 'Menaxher',
      shiftId: _currentShiftId,
    );
    await _reloadSales();
    _notify();
  }

  /// Records a refund, void, or discount against an existing sale.
  /// The original sale and its line items are never modified.
  Future<SaleAdjustmentRow> recordAdjustment({
    required int saleId,
    int? saleLineId,
    required String adjustmentType,
    String? productName,
    int? quantity,
    required double amount,
    String? reason,
    String? createdBy,
  }) async {
    final newId = await SalesRepository.instance.insertSaleAdjustment(
      saleId: saleId,
      saleLineId: saleLineId,
      adjustmentType: adjustmentType,
      productName: productName,
      quantity: quantity,
      amount: amount,
      reason: reason,
      createdBy: createdBy,
    );
    AuditLogService.instance.logAdjustment(
      adjustmentType: adjustmentType,
      saleId:         saleId,
      amount:         amount,
      reason:         reason,
      performedBy:    createdBy,
      shiftId:        _currentShiftId,
    );
    return SaleAdjustmentRow(
      id: newId,
      saleId: saleId,
      saleLineId: saleLineId,
      adjustmentType: adjustmentType,
      productName: productName,
      quantity: quantity,
      amount: amount,
      reason: reason,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  List<MapEntry<String, double>> get employeeSalesSorted {
    final entries = waiterSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  MapEntry<String, double> get topEmployee {
    if (waiterSales.isEmpty) return const MapEntry('—', 0.0);
    return waiterSales.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }
}

import '../models/sale_insert_result.dart';
import '../services/database_service.dart';

/// Sales headers, lines, adjustments, and history reads.
class SalesRepository {
  SalesRepository._();
  static final SalesRepository instance = SalesRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<List<Map<String, dynamic>>> fetchSales() => _db.fetchSales();

  Future<List<Map<String, dynamic>>> fetchFilteredSales({
    DateTime? from,
    DateTime? to,
    String? waiterName,
    int? tableId,
    int? saleId,
  }) =>
      _db.fetchFilteredSales(
        from: from,
        to: to,
        waiterName: waiterName,
        tableId: tableId,
        saleId: saleId,
      );

  Future<List<Map<String, dynamic>>> fetchSaleLines(int saleId) =>
      _db.fetchSaleLines(saleId);

  Future<List<Map<String, dynamic>>> fetchSaleLinesForSales(
    List<int> saleIds,
  ) =>
      _db.fetchSaleLinesForSales(saleIds);

  Future<List<Map<String, dynamic>>> fetchAdjustmentsForSales(
    List<int> saleIds,
  ) =>
      _db.fetchAdjustmentsForSales(saleIds);

  Future<void> insertSale({
    required String waiterName,
    required int tableId,
    required double total,
    int? shiftId,
  }) =>
      _db.insertSale(
        waiterName: waiterName,
        tableId: tableId,
        total: total,
        shiftId: shiftId,
      );

  Future<SaleInsertResult> insertSaleWithLines({
    required String saleUuid,
    required String waiterName,
    required int tableId,
    required double total,
    required List<Map<String, dynamic>> lines,
    int? shiftId,
    int? orderNumber,
    String? tableName,
  }) =>
      _db.insertSaleWithLines(
        saleUuid: saleUuid,
        waiterName: waiterName,
        tableId: tableId,
        total: total,
        lines: lines,
        shiftId: shiftId,
        orderNumber: orderNumber,
        tableName: tableName,
      );

  Future<String> resolvePaymentSaleUuid({
    required int tableId,
    required String waiterName,
  }) =>
      _db.resolvePaymentSaleUuid(tableId: tableId, waiterName: waiterName);

  Future<void> clearPendingPaymentSaleUuid(
    int tableId,
    String waiterName,
  ) =>
      _db.clearPendingPaymentSaleUuid(tableId, waiterName);

  Future<int> insertSaleAdjustment({
    required int saleId,
    int? saleLineId,
    required String adjustmentType,
    String? productName,
    int? quantity,
    required double amount,
    String? reason,
    String? createdBy,
  }) =>
      _db.insertSaleAdjustment(
        saleId: saleId,
        saleLineId: saleLineId,
        adjustmentType: adjustmentType,
        productName: productName,
        quantity: quantity,
        amount: amount,
        reason: reason,
        createdBy: createdBy,
      );

  Future<void> deleteSaleById(int saleId) => _db.deleteSaleById(saleId);
}

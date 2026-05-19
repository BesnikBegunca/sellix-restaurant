/// Result of an idempotent [DatabaseService.insertSaleWithLines] call.
class SaleInsertResult {
  const SaleInsertResult({
    required this.saleId,
    required this.saleUuid,
    required this.wasExisting,
  });

  final int saleId;
  final String saleUuid;

  /// `true` when a row with [saleUuid] already existed (no duplicate writes).
  final bool wasExisting;
}

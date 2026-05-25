/// Pure payload builders for [printed_orders] sync (operational lifecycle only).
class PrintedOrderSyncPayload {
  PrintedOrderSyncPayload._();

  static int itemsCountFromLines(List<Map<String, dynamic>> lines) {
    var count = 0;
    for (final line in lines) {
      count += (line['qty'] as num?)?.toInt() ?? 0;
    }
    return count;
  }

  static String tableDisplayName(int tableId) => 'Tavolina $tableId';

  /// Full payload for PRINTO → `create` (status [printed]).
  static Map<String, dynamic> create({
    required String uuid,
    required int orderNumber,
    required int tableId,
    required String waiterName,
    required double total,
    required int itemsCount,
    required String printedAt,
  }) {
    return <String, dynamic>{
      'uuid': uuid,
      'orderNumber': orderNumber,
      'tableId': tableId,
      'tableName': tableDisplayName(tableId),
      'waiterName': waiterName,
      'total': total,
      'itemsCount': itemsCount,
      'status': 'printed',
      'printedAt': printedAt,
    };
  }

  /// Minimal payload for PAGUAJ → `update` (same uuid, no new entity).
  static Map<String, dynamic> paidUpdate({
    required String uuid,
    required String saleUuid,
  }) {
    return <String, dynamic>{
      'uuid': uuid,
      'status': 'paid',
      'saleUuid': saleUuid,
    };
  }
}

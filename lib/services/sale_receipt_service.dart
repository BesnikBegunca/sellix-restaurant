import '../models/mock_data.dart';
import '../models/pos_models.dart';
import 'receipt_printer.dart';
import 'receipt_text.dart';

/// Prints payment receipts from persisted sale snapshots (reprint / history).
class SaleReceiptService {
  SaleReceiptService._();

  static Future<bool> reprintPaymentReceipt({
    required SaleRow sale,
    required List<SaleLineRow> lines,
    required String companyName,
  }) async {
    if (lines.isEmpty) return false;

    final receiptLines = lines
        .map(
          (l) => ReceiptLine(
            product: ProductItem(
              id: l.productId ?? l.productName,
              name: l.productName,
              price: l.productPrice,
              emoji: l.productEmoji,
              imagePath: l.productImagePath,
            ),
            qty: l.quantity,
          ),
        )
        .toList();

    return ReceiptPrinter.printKitchenOrder(
      companyName: companyName,
      waiterName: sale.waiterName,
      tableNumber: sale.tableId,
      orderNumber: sale.dbId ?? 0,
      lines: receiptLines,
      total: sale.total,
      paymentReceipt: true,
    );
  }
}

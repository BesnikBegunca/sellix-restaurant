import 'receipt_text.dart';
import 'printer_settings_store.dart';
import 'windows_printers_service.dart';

class ReceiptPrinter {
  const ReceiptPrinter();

  static Future<bool> printKitchenOrder({
    required String companyName,
    required String waiterName,
    required int tableNumber,
    required int orderNumber,
    required List<ReceiptLine> lines,
    required double total,
  }) async {
    final text = buildKitchenOrderReceiptText(
      companyName: companyName,
      waiterName: waiterName,
      tableNumber: tableNumber,
      orderNumber: orderNumber,
      lines: lines,
      total: total,
    );

    final selectedPrinter = await PrinterSettingsStore.loadSelectedPrinterName();
    if (selectedPrinter.trim().isEmpty) {
      return false;
    }

    return WindowsPrintersService.printRawText(
      printerName: selectedPrinter,
      text: '$text\n\n\n',
    );
  }
}

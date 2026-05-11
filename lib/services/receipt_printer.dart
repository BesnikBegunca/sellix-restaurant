import 'receipt_text.dart';
import 'printer_settings_store.dart';
import 'windows_printers_service.dart';

class ReceiptPrinter {
  const ReceiptPrinter();

  static String _stripStyleTags(String text) {
    return text.replaceAll('[[B]]', '').replaceAll('[[/B]]', '');
  }

  static Future<bool> printKitchenOrder({
    required String companyName,
    required String waiterName,
    required int tableNumber,
    required int orderNumber,
    required List<ReceiptLine> lines,
    required double total,
    bool paymentReceipt = false,
  }) async {
    final text = buildKitchenOrderReceiptText(
      companyName: companyName,
      waiterName: waiterName,
      tableNumber: tableNumber,
      orderNumber: orderNumber,
      lines: lines,
      total: total,
      paymentReceipt: paymentReceipt,
    );

    final selectedPrinter = await PrinterSettingsStore.loadSelectedPrinterName();
    if (selectedPrinter.trim().isEmpty) {
      return false;
    }

    final ok = await WindowsPrintersService.printRawText(
      printerName: selectedPrinter,
      text: '$text\n\n\n',
    );
    if (ok) return true;

    // Fallback: retry without style markers so printing never blocks.
    final plain = _stripStyleTags(text);
    return WindowsPrintersService.printRawText(
      printerName: selectedPrinter,
      text: '$plain\n\n\n',
    );
  }

  static Future<bool> printShiftStatus({
    required String companyName,
    required Map<String, double> waiterTotals,
  }) async {
    final text = buildShiftReceiptText(
      companyName: companyName,
      waiterTotals: waiterTotals,
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

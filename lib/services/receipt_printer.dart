import '../manager/manager_data.dart';
import 'escpos/escpos_printer_service.dart';
import 'escpos/escpos_receipt_builder.dart';
import 'printer_settings_store.dart';
import 'receipt_text.dart';
import 'windows_printers_service.dart';

/// Titulli i kuponit të gjendjes (shift) në printer.
enum ShiftReceiptHeader {
  /// Kur shtypet «Shtyp gjendjen».
  pressed,

  /// Kur konfirmohet mbyllja e gjendjes.
  closed,
}

extension ShiftReceiptHeaderTitle on ShiftReceiptHeader {
  String get receiptTitle => switch (this) {
        ShiftReceiptHeader.pressed => 'GJENDJA E SHTYPUR',
        ShiftReceiptHeader.closed => 'GJENDJA E MBYLLUR',
      };
}

/// High-level receipt printing facade used by [PosOrderScreen].
///
/// Routing logic:
/// 1. If no printer is configured → return false immediately.
/// 2. If ESC/POS mode is enabled (default) → attempt raw ESC/POS bytes via
///    [EscPosPrinterService] (includes 1 automatic retry + text fallback).
/// 3. If ESC/POS mode is disabled → use legacy text-mode printing directly.
///
/// The payment flow is never blocked: every print call is wrapped in try/catch
/// at the call site in [PosOrderScreen._payTable] and [PosOrderScreen._sendOrder].
class ReceiptPrinter {
  const ReceiptPrinter();

  // ── Kitchen order receipt ─────────────────────────────────────────────────

  static Future<bool> printKitchenOrder({
    required String companyName,
    required String waiterName,
    required int tableNumber,
    required int orderNumber,
    required List<ReceiptLine> lines,
    required double total,
    bool paymentReceipt = false,
  }) async {
    final selectedPrinter = await PrinterSettingsStore.loadSelectedPrinterName();
    if (selectedPrinter.trim().isEmpty) return false;

    final data = ManagerData.instance;

    if (data.useEscPos) {
      final profile = EscPosPrinterService.instance.profileFor(
        selectedPrinter,
        paperWidthMm: data.paperWidthMm,
      );
      final bytes = paymentReceipt
          ? EscPosReceiptBuilder.buildPaymentReceipt(
              profile: profile,
              companyName: companyName,
              waiterName: waiterName,
              tableNumber: tableNumber,
              orderNumber: orderNumber,
              lines: lines,
              total: total,
              footerText: data.receiptFooter,
              businessAddress: data.businessAddress,
              businessPhone: data.businessPhone,
            )
          : EscPosReceiptBuilder.buildKitchenReceipt(
              profile: profile,
              companyName: companyName,
              waiterName: waiterName,
              tableNumber: tableNumber,
              orderNumber: orderNumber,
              lines: lines,
              total: total,
            );

      final fallback = buildKitchenOrderReceiptText(
        companyName: companyName,
        waiterName: waiterName,
        tableNumber: tableNumber,
        orderNumber: orderNumber,
        lines: lines,
        total: total,
        paymentReceipt: paymentReceipt,
      );

      return EscPosPrinterService.instance.printNow(
        printerName: selectedPrinter,
        escPosBytes: bytes,
        fallbackText: fallback,
      );
    }

    // Legacy text-mode (ESC/POS disabled in settings).
    final text = buildKitchenOrderReceiptText(
      companyName: companyName,
      waiterName: waiterName,
      tableNumber: tableNumber,
      orderNumber: orderNumber,
      lines: lines,
      total: total,
      paymentReceipt: paymentReceipt,
    );
    final ok = await WindowsPrintersService.printRawText(
      printerName: selectedPrinter,
      text: '$text\n\n\n',
    );
    if (ok) return true;
    // Fallback: strip style tags and retry.
    final plain = text.replaceAll('[[B]]', '').replaceAll('[[/B]]', '');
    return WindowsPrintersService.printRawText(
      printerName: selectedPrinter,
      text: '$plain\n\n\n',
    );
  }

  // ── Shift status receipt ──────────────────────────────────────────────────

  static Future<bool> printShiftStatus({
    required ShiftReceiptHeader header,
    required String companyName,
    required Map<String, double> waiterTotals,
    double? summaryPaid,
    double? summaryOpen,
    DateTime? reportTime,
  }) async {
    final title = header.receiptTitle;
    final selectedPrinter = await PrinterSettingsStore.loadSelectedPrinterName();
    if (selectedPrinter.trim().isEmpty) return false;

    final data = ManagerData.instance;

    if (data.useEscPos) {
      final profile = EscPosPrinterService.instance.profileFor(
        selectedPrinter,
        paperWidthMm: data.paperWidthMm,
      );
      final bytes = EscPosReceiptBuilder.buildShiftReceipt(
        profile: profile,
        title: title,
        companyName: companyName,
        waiterTotals: waiterTotals,
        summaryPaid: summaryPaid,
        summaryOpen: summaryOpen,
        reportTime: reportTime,
      );
      final fallback = buildShiftReceiptText(
        title: title,
        companyName: companyName,
        waiterTotals: waiterTotals,
        summaryPaid: summaryPaid,
        summaryOpen: summaryOpen,
        reportTime: reportTime,
      );
      return EscPosPrinterService.instance.printNow(
        printerName: selectedPrinter,
        escPosBytes: bytes,
        fallbackText: fallback,
      );
    }

    final text = buildShiftReceiptText(
      title: title,
      companyName: companyName,
      waiterTotals: waiterTotals,
      summaryPaid: summaryPaid,
      summaryOpen: summaryOpen,
      reportTime: reportTime,
    );
    return WindowsPrintersService.printRawText(
      printerName: selectedPrinter,
      text: '$text\n\n\n',
    );
  }
}

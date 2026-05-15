import 'dart:typed_data';

import '../receipt_text.dart';
import 'escpos_bytes.dart';
import 'printer_profile.dart';

/// Builds ESC/POS byte payloads for every receipt type used in the POS.
///
/// All public methods return a [Uint8List] ready to be sent as a RAW
/// Windows print job.  The layout mirrors the existing text receipt so
/// the visual output is consistent whether printing via ESC/POS or fallback.
class EscPosReceiptBuilder {
  const EscPosReceiptBuilder._();

  // ── Public builders ──────────────────────────────────────────────────────

  /// Kitchen order receipt (sent to the kitchen printer on "Send Order").
  static Uint8List buildKitchenReceipt({
    required PrinterProfile profile,
    required String companyName,
    required String waiterName,
    required int tableNumber,
    required int orderNumber,
    required List<ReceiptLine> lines,
    required double total,
  }) {
    final b = EscPosBytes(paperWidthMm: profile.paperWidthMm);
    final w = b.lineWidth;

    b.reset();
    _header(b, companyName);
    _waiterTable(b, waiterName, tableNumber);
    b.lf();
    _itemsHeader(b, w);
    _itemLines(b, lines, w);
    b.separator();
    _totalLine(b, total, w);
    b.lf();
    _metaLines(b, orderNumber);
    b.lf(4);

    if (profile.supportsCut) b.partialCut();
    return b.build();
  }

  /// Payment receipt (sent to the customer printer on "Pay").
  static Uint8List buildPaymentReceipt({
    required PrinterProfile profile,
    required String companyName,
    required String waiterName,
    required int tableNumber,
    required int orderNumber,
    required List<ReceiptLine> lines,
    required double total,
    required String footerText,
    String? businessAddress,
    String? businessPhone,
    int? shiftId,
  }) {
    final b = EscPosBytes(paperWidthMm: profile.paperWidthMm);
    final w = b.lineWidth;

    b.reset();

    // Receipt type banner
    b.boldCenteredLine('Fature per Pagese');
    b.lf();

    _header(b, companyName);

    // Optional address / phone under the company name
    if (businessAddress != null && businessAddress.isNotEmpty) {
      b.alignCenter().textLine(businessAddress).alignLeft();
    }
    if (businessPhone != null && businessPhone.isNotEmpty) {
      b.alignCenter().textLine('Tel: $businessPhone').alignLeft();
    }
    b.separator();

    _waiterTable(b, waiterName, tableNumber);
    if (shiftId != null) {
      b.textLine('Turni: #$shiftId');
    }
    b.lf();
    _itemsHeader(b, w);
    _itemLines(b, lines, w);
    b.separator();
    _totalLine(b, total, w);
    b.lf();
    _metaLines(b, orderNumber);
    b.lf();
    b.boldCenteredLine(footerText.isNotEmpty ? footerText : 'Ju Faleminderit!');
    b.lf(4);

    if (profile.supportsCut) b.partialCut();
    return b.build();
  }

  /// Shift summary receipt (printed when "Print shift status" is tapped).
  static Uint8List buildShiftReceipt({
    required PrinterProfile profile,
    required String companyName,
    required Map<String, double> waiterTotals,
    double? summaryPaid,
    double? summaryOpen,
    DateTime? reportTime,
  }) {
    final b = EscPosBytes(paperWidthMm: profile.paperWidthMm);
    final w = b.lineWidth;

    b.reset();
    _header(b, companyName);
    b.boldCenteredLine('GJENDJA');
    b.separator();

    final colW = w ~/ 2;
    b.textLine(
      b.col('Kamarjeri', colW) + b.col('Totali', colW, rightAlign: true),
    );
    b.lf();

    final names = waiterTotals.keys.toList()..sort();
    var grand = 0.0;
    for (final name in names) {
      final amount = waiterTotals[name] ?? 0;
      grand += amount;
      b.textLine(
        b.col(name, colW) +
            b.col(_money(amount), colW, rightAlign: true),
      );
    }

    b.separator();
    b.textLine(
      b.col('TOTALI', colW) + b.col(_money(grand), colW, rightAlign: true),
    );
    if (summaryPaid != null && summaryOpen != null) {
      b.lf();
      b.textLine(
        b.col('Paguar', colW) +
            b.col(_money(summaryPaid), colW, rightAlign: true),
      );
      b.textLine(
        b.col('Hapur', colW) +
            b.col(_money(summaryOpen), colW, rightAlign: true),
      );
    }
    if (reportTime != null) {
      final t = reportTime;
      final ts =
          '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      b.lf();
      b.textLine(ts);
    }
    b.lf(4);

    if (profile.supportsCut) b.partialCut();
    return b.build();
  }

  /// Test receipt — printed from Admin Settings to verify all ESC/POS features.
  static Uint8List buildTestReceipt({
    required PrinterProfile profile,
    required String companyName,
  }) {
    final b = EscPosBytes(paperWidthMm: profile.paperWidthMm);
    final w = b.lineWidth;
    final now = DateTime.now();

    b.reset();
    b.boldCenteredLine('*** TEST PRINT ***');
    b.separator();
    b.centeredLine(companyName);
    b.centeredLine('ESC/POS Test Receipt');
    b.separator();

    // Alignment test
    b.alignLeft().textLine('Left aligned text').alignLeft();
    b.alignCenter().textLine('Center aligned text').alignLeft();
    b.alignRight().textLine('Right aligned text').alignLeft();
    b.separator();

    // Bold test
    b.boldOn().textLine('Bold text ON').boldOff();
    b.textLine('Normal text');
    b.lf();

    // Column test
    b.textLine(b.col('Item Name', w - 14) + b.col('Qty', 6, rightAlign: true) + b.col('Price', 8, rightAlign: true));
    b.textLine(b.col('Espresso', w - 14) + b.col('2', 6, rightAlign: true) + b.col('3.00', 8, rightAlign: true));
    b.textLine(b.col('Cappuccino', w - 14) + b.col('1', 6, rightAlign: true) + b.col('4.50', 8, rightAlign: true));
    b.separator();
    b.rowLR('TOTAL:', '11.50');
    b.lf();

    // Profile info
    b.textLine('Profile  : ${profile.name}');
    b.textLine('Paper    : ${profile.paperWidthMm}mm (${profile.charWidth} cols)');
    b.textLine('Cut      : ${profile.supportsCut ? "YES" : "NO"}');
    b.textLine('Drawer   : ${profile.supportsDrawer ? "YES" : "NO"}');
    b.separator();

    final ts = _two(now.day) +
        '.' +
        _two(now.month) +
        '.' +
        now.year.toString() +
        ' ' +
        _two(now.hour) +
        ':' +
        _two(now.minute);
    b.centeredLine(ts);
    b.centeredLine('POS System v1.0.0');
    b.lf(4);

    if (profile.supportsCut) b.partialCut();
    return b.build();
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  static void _header(EscPosBytes b, String companyName) {
    b.separator();
    b.boldCenteredLine(companyName);
    b.separator();
  }

  static void _waiterTable(EscPosBytes b, String waiter, int table) {
    b.rowLR('Kamarjeri: $waiter', 'Tavolina $table');
  }

  static void _itemsHeader(EscPosBytes b, int w) {
    final nc = w - 14; // name column width
    b.textLine(
      b.col('Produkti', nc) +
          b.col('Sasia', 6, rightAlign: true) +
          b.col('Cmimi', 8, rightAlign: true),
    );
    b.lf();
  }

  static void _itemLines(EscPosBytes b, List<ReceiptLine> lines, int w) {
    final nc = w - 14;
    for (final line in lines) {
      final namePart = b.col(line.product.name, nc);
      final qtyPart  = b.col(line.qty.toString(), 6, rightAlign: true);
      final pricePart = b.col(_money(line.product.price), 8, rightAlign: true);
      b.textLine('$namePart$qtyPart$pricePart');
    }
  }

  static void _totalLine(EscPosBytes b, double total, int w) {
    b.boldOn();
    b.rowLR('Total:', _money(total));
    b.boldOff();
  }

  static void _metaLines(EscPosBytes b, int orderNumber) {
    final now = DateTime.now();
    b.textLine('Order #$orderNumber');
    b.textLine(
      'Date: '
      '${_two(now.day)}.${_two(now.month)}.${now.year} '
      '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}',
    );
  }

  static String _money(double v) => v.toStringAsFixed(2);
  static String _two(int v) => v.toString().padLeft(2, '0');
}

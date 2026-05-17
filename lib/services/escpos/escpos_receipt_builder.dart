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
    b.boldCenteredDoubleLine('TOTALI PER PAGESE');
    b.lf();

    final name = companyName.trim();
    if (name.isNotEmpty) {
      b.boldCenteredLine(name);
    }
    b.separator();

    // Optional address / phone under the company name
    if (businessAddress != null && businessAddress.isNotEmpty) {
      b.alignCenter().textLine(businessAddress).alignLeft();
    }
    if (businessPhone != null && businessPhone.isNotEmpty) {
      b.alignCenter().textLine('Tel: $businessPhone').alignLeft();
    }

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
    b.separator();
    b.boldCenteredDoubleLine('GJENDJA');
    b.lf();
    final name = companyName.trim();
    if (name.isNotEmpty) {
      b.boldCenteredLine(name);
    }
    b.separator();

    final colW = w ~/ 2;
    final shiftHeader =
        b.col('Perdoruesi', colW) + b.col('Totali', colW, rightAlign: true);
    b.boldOn().textLine(shiftHeader).boldOff();
    b.separator();

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
    b.boldOn();
    b.textLine(
      b.col('Totali', colW) + b.col(_money(grand), colW, rightAlign: true),
    );
    b.boldOff();
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
    final nc = _nameColW(w);
    b.textLine(
      b.col('Produkti', nc) +
          b.col('Sasia', _qtyColW, rightAlign: true) +
          b.col('Cmimi', _unitColW, rightAlign: true) +
          b.col('Vlera', _valueColW, rightAlign: true),
    );
    b.textLine(
      b.col('Espresso', nc) +
          b.col('2', _qtyColW, rightAlign: true) +
          b.col('3.00', _unitColW, rightAlign: true) +
          b.col('6.00', _valueColW, rightAlign: true),
    );
    b.textLine(
      b.col('Cappuccino', nc) +
          b.col('1', _qtyColW, rightAlign: true) +
          b.col('4.50', _unitColW, rightAlign: true) +
          b.col('4.50', _valueColW, rightAlign: true),
    );
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
    final name = companyName.trim();
    b.separator();
    if (name.isNotEmpty) {
      b.boldCenteredLine(name);
    }
    b.separator();
  }

  static void _waiterTable(EscPosBytes b, String waiter, int table) {
    b.rowLR('Perdoruesi: $waiter', 'Tavolina $table');
  }

  static const _qtyColW = 5; // "Sasia" = 5 shkronja
  static const _unitColW = 7;
  static const _valueColW = 8;

  static int _nameColW(int lineWidth) =>
      lineWidth - _qtyColW - _unitColW - _valueColW;

  static void _itemsHeader(EscPosBytes b, int w) {
    final nc = _nameColW(w);
    final header =
        b.col('Produkti', nc) +
        b.col('Sasia', _qtyColW, rightAlign: true) +
        b.col('Cmimi', _unitColW, rightAlign: true) +
        b.col('Vlera', _valueColW, rightAlign: true);
    b.boldOn().textLine(header).boldOff();
    b.separator();
  }

  static void _itemLines(EscPosBytes b, List<ReceiptLine> lines, int w) {
    final nc = _nameColW(w);
    for (final line in lines) {
      final lineValue = line.product.price * line.qty;
      final namePart = b.col(line.product.name, nc);
      final qtyPart = b.col(line.qty.toString(), _qtyColW, rightAlign: true);
      final unitPart =
          b.col(_money(line.product.price), _unitColW, rightAlign: true);
      final valuePart =
          b.col(_money(lineValue), _valueColW, rightAlign: true);
      b.textLine('$namePart$qtyPart$unitPart$valuePart');
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

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../manager/manager_data.dart';

// ─────────────────────────── data contract ───────────────────────────────────

/// Lightweight container passed to the PDF builder so it does not need to
/// reach back into the UI layer.
class SalesHistoryReportData {
  const SalesHistoryReportData({
    required this.dateRangeLabel,
    required this.companyName,
    required this.sales,
    required this.analytics,
  });

  final String dateRangeLabel;
  final String companyName;
  final List<SaleWithLinesData> sales;
  final SalesAnalyticsData analytics;
}

class SaleWithLinesData {
  const SaleWithLinesData({
    required this.sale,
    required this.lines,
    this.adjustments = const [],
  });

  final SaleRow sale;
  final List<SaleLineRow> lines;
  final List<SaleAdjustmentRow> adjustments;
}

class SalesAnalyticsData {
  const SalesAnalyticsData({
    required this.totalSales,
    required this.grossRevenue,
    this.totalRefunded = 0,
    required this.avgOrderValue,
    required this.totalItemsSold,
    required this.topProducts,
    required this.topCategories,
    required this.topWaiterName,
    required this.topWaiterRevenue,
  });

  final int totalSales;
  final double grossRevenue;
  final double totalRefunded;
  final double avgOrderValue;
  final int totalItemsSold;
  final List<({String name, double revenue, int qty})> topProducts;
  final List<({String name, double revenue})> topCategories;
  final String topWaiterName;
  final double topWaiterRevenue;

  double get netRevenue => grossRevenue - totalRefunded;
}

// ─────────────────────────── builder ─────────────────────────────────────────

Future<Uint8List> buildSalesHistoryPdfBytes(
  SalesHistoryReportData data,
) async {
  final pdf = pw.Document();
  final now = DateTime.now();

  String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String fmtDateTime(DateTime d) =>
      '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  final a = data.analytics;

  // ── helpers ───────────────────────────────────────────────────────────────

  pw.TableRow hdr2(String a, String b) => _row2(a, b, header: true);
  pw.TableRow hdr5(String a, String b, String c, String d, String e) =>
      _row5(a, b, c, d, e, header: true);

  // ── page ─────────────────────────────────────────────────────────────────

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        // ── title ──────────────────────────────────────────────────────────
        pw.Text(
          data.companyName.isNotEmpty ? data.companyName : 'POS System',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Historiku i Shitjeve — ${data.dateRangeLabel}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          'Gjeneruar: ${fmtDateTime(now)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.SizedBox(height: 18),

        // ── summary stats ──────────────────────────────────────────────────
        pw.Text(
          'Përmbledhje',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.2),
          },
          children: [
            hdr2('Metrika', 'Vlera'),
            _row2('Shitje gjithsej', '${a.totalSales}'),
            _row2('Të ardhura bruto', '${a.grossRevenue.toStringAsFixed(2)}€'),
            if (a.totalRefunded > 0)
              _row2('Rimbursime', '-${a.totalRefunded.toStringAsFixed(2)}€'),
            if (a.totalRefunded > 0)
              _row2('Të ardhura neto', '${a.netRevenue.toStringAsFixed(2)}€'),
            _row2('Mesatarja e porosisë', '${a.avgOrderValue.toStringAsFixed(2)}€'),
            _row2('Artikuj të shitur', '${a.totalItemsSold}'),
            _row2(
              'Kamarieri top',
              a.topWaiterName == '—'
                  ? '—'
                  : '${a.topWaiterName} (${a.topWaiterRevenue.toStringAsFixed(2)}€)',
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        // ── top products ───────────────────────────────────────────────────
        if (a.topProducts.isNotEmpty) ...[
          pw.Text(
            'Produktet më të shitura (top ${a.topProducts.length})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.2),
            },
            children: [
              _row3('Produkti', 'Sasia', 'Të ardhura', header: true),
              for (final p in a.topProducts)
                _row3(
                  p.name,
                  '${p.qty}',
                  '${p.revenue.toStringAsFixed(2)}€',
                ),
            ],
          ),
          pw.SizedBox(height: 18),
        ],

        // ── top categories ─────────────────────────────────────────────────
        if (a.topCategories.isNotEmpty) ...[
          pw.Text(
            'Të ardhurat sipas kategorisë',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.2),
            },
            children: [
              hdr2('Kategoria', 'Të ardhura'),
              for (final c in a.topCategories)
                _row2(c.name, '${c.revenue.toStringAsFixed(2)}€'),
            ],
          ),
          pw.SizedBox(height: 18),
        ],

        // ── sale list ──────────────────────────────────────────────────────
        pw.Text(
          'Detajet e shitjeve',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),

        if (data.sales.isEmpty)
          pw.Text(
            'Nuk ka shitje në këtë periudhë.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          )
        else
          for (final s in data.sales) ...[
            // Sale header row
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Shitja #${s.sale.dbId ?? '?'}  ·  ${s.sale.waiterName}  ·  Table ${s.sale.tableId}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    fmtDateTime(s.sale.timestamp),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    '${s.sale.total.toStringAsFixed(2)}€',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Line items
            if (s.lines.isNotEmpty)
              pw.Table(
                border: pw.TableBorder(
                  left: const pw.BorderSide(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  right: const pw.BorderSide(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  bottom: const pw.BorderSide(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  horizontalInside: const pw.BorderSide(
                    color: PdfColors.grey300,
                    width: 0.3,
                  ),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(0.9),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  hdr5('Produkti', 'Kat.', 'Sasia', 'Çmimi', 'Totali'),
                  for (final l in s.lines)
                    _row5(
                      l.productName,
                      l.categoryName ?? '—',
                      '×${l.quantity}',
                      '${l.productPrice.toStringAsFixed(2)}€',
                      '${l.lineTotal.toStringAsFixed(2)}€',
                    ),
                ],
              )
            else
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    right: pw.BorderSide(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                    bottom: pw.BorderSide(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                  ),
                ),
                child: pw.Text(
                  'Nuk ka linja produktesh të regjistruara.',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            // Adjustment rows (refunds/voids)
            if (s.adjustments.isNotEmpty)
              pw.Table(
                border: pw.TableBorder(
                  left: const pw.BorderSide(
                    color: PdfColors.red200,
                    width: 0.5,
                  ),
                  right: const pw.BorderSide(
                    color: PdfColors.red200,
                    width: 0.5,
                  ),
                  bottom: const pw.BorderSide(
                    color: PdfColors.red200,
                    width: 0.5,
                  ),
                  horizontalInside: const pw.BorderSide(
                    color: PdfColors.red100,
                    width: 0.3,
                  ),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.red50),
                    children: [
                      for (final t in ['Lloji', 'Arsyeja', 'Shuma'])
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            t,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final adj in s.adjustments)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            adj.adjustmentType,
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.red700,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            adj.reason ?? '—',
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '-${adj.amount.toStringAsFixed(2)}€',
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            pw.SizedBox(height: 6),
          ],

        pw.SizedBox(height: 12),
        pw.Text(
          'Çmimet janë snapshot-e në kohën e pagesës dhe nuk ndikohen nga ndryshimet e mëvonshme të katalogut.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  return pdf.save();
}

// ─────────────────────────── table row helpers ───────────────────────────────

pw.TableRow _row2(String a, String b, {bool header = false}) {
  final style = pw.TextStyle(
    fontSize: header ? 9 : 8,
    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.TableRow(
    decoration:
        header ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
    children: [
      for (final t in [a, b])
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(t, style: style),
        ),
    ],
  );
}

pw.TableRow _row3(String a, String b, String c, {bool header = false}) {
  final style = pw.TextStyle(
    fontSize: header ? 9 : 8,
    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.TableRow(
    decoration:
        header ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
    children: [
      for (final t in [a, b, c])
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(t, style: style),
        ),
    ],
  );
}

pw.TableRow _row5(
  String a,
  String b,
  String c,
  String d,
  String e, {
  bool header = false,
}) {
  final style = pw.TextStyle(
    fontSize: header ? 8 : 7,
    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.TableRow(
    decoration:
        header ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
    children: [
      for (final t in [a, b, c, d, e])
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t, style: style),
        ),
    ],
  );
}

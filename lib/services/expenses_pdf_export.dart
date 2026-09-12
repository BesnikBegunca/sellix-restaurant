import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../manager/manager_data.dart';
import '../l10n/tr.dart';

/// Gjeneron PDF për listën e shpenzimeve (A4, tabelë + përmbledhje).
Future<Uint8List> buildExpensesPdfBytes({
  required List<ExpenseRow> rows,
  // Defaults cannot call tr (it resolves at runtime), so resolve it here.
  String? businessName,
}) async {
  final name = businessName ?? tr.posSystem;
  final total = rows.fold<double>(0, (s, e) => s + e.amount);
  final byType = <String, double>{};
  for (final e in rows) {
    byType[e.type] = (byType[e.type] ?? 0) + e.amount;
  }

  String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Raport shpenzimesh / rrogash',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Gjeneruar: ${fmtDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.green200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                  pw.Text(
                    '${rows.length} rreshta',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.1),
            1: const pw.FlexColumnWidth(2.4),
            2: const pw.FlexColumnWidth(0.9),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfHead(tr.lloji),
                _pdfHead(tr.pershkrimi2),
                _pdfHead('Shuma', right: true),
                _pdfHead('Data'),
              ],
            ),
            for (final e in rows)
              pw.TableRow(
                children: [
                  _pdfCell(e.type),
                  _pdfCell(e.description),
                  _pdfCell('\$${e.amount.toStringAsFixed(2)}', right: true),
                  _pdfCell(fmtDate(e.date)),
                ],
              ),
          ],
        ),
        if (byType.isNotEmpty) ...[
          pw.SizedBox(height: 28),
          pw.Text(
            tr.permbledhjeSipasLlojit,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _pdfHead(tr.lloji),
                  _pdfHead('Shuma', right: true),
                ],
              ),
              for (final kv in byType.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
                pw.TableRow(
                  children: [
                    _pdfCell(kv.key),
                    _pdfCell('\$${kv.value.toStringAsFixed(2)}', right: true),
                  ],
                ),
            ],
          ),
        ],
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _pdfHead(String s, {bool right = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: pw.Text(
      s,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

pw.Widget _pdfCell(String s, {bool right = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(
      s,
      style: const pw.TextStyle(fontSize: 9),
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

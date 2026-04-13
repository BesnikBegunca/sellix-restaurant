import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../manager/manager_data.dart';

/// Raport PDF përmbledhës për menaxherin (fitime demo, shpenzime, staf, tavolina).
Future<Uint8List> buildManagerSummaryPdfBytes(ManagerData m) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  final occupied = m.cashierTables.where((t) => t.occupied).length;
  final salesRows = m.employeeSalesSorted.take(12).toList();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          'POS System',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Raport përmbledhës menaxheri',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          'Gjeneruar: ${fmt(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Metrika kryesore',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.2),
          },
          children: [
            _pdfRow('Gjendja (shift)', m.shiftOpen ? 'E hapur' : 'E mbyllur', header: true),
            _pdfRow('Kamarierë të regjistruar', '${m.waiters.length}'),
            _pdfRow('Tavolina (gjithsej)', '${m.cashierTables.length}'),
            _pdfRow('Tavolina të zëna', '$occupied'),
            _pdfRow('Shpenzime totale (regjistër)', '\$${m.totalExpenses.toStringAsFixed(2)}'),
            _pdfRow('Fitim ditor (demo)', '\$${m.profitDaily().toStringAsFixed(2)}'),
            _pdfRow('Fitim javor (demo)', '\$${m.profitWeekly().toStringAsFixed(2)}'),
            _pdfRow('Fitim mujor (demo)', '\$${m.profitMonthly().toStringAsFixed(2)}'),
            _pdfRow(
              'Top puntor (sesion)',
              m.topEmployee.key == '—'
                  ? '—'
                  : '${m.topEmployee.key} (\$${m.topEmployee.value.toStringAsFixed(2)})',
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        pw.Text(
          'Shitje sipas kamarierit',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (salesRows.isEmpty)
          pw.Text(
            'Nuk ka shitje të regjistruara në sesion.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              _pdfRow('Kamarieri', 'Shitje', header: true),
              for (final e in salesRows)
                _pdfRow(e.key, '\$${e.value.toStringAsFixed(2)}'),
            ],
          ),
        pw.SizedBox(height: 22),
        pw.Text(
          'Shpenzime / rroga (deri në 25 rreshta)',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (m.expenses.isEmpty)
          pw.Text(
            'Nuk ka shpenzime të regjistruara.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.9),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(0.9),
            },
            children: [
              _pdfRow4('Lloji', 'Përshkrimi', 'Shuma', 'Data', header: true),
              for (final e in m.expenses.take(25))
                _pdfRow4(
                  e.type,
                  e.description.length > 40
                      ? '${e.description.substring(0, 37)}...'
                      : e.description,
                  '\$${e.amount.toStringAsFixed(2)}',
                  fmt(e.date),
                ),
            ],
          ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Shënim: vlerat e fitimit janë demo dhe varen nga logjika e aplikacionit.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.TableRow _pdfRow(String a, String b, {bool header = false}) {
  final style = pw.TextStyle(
    fontSize: header ? 10 : 9,
    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.TableRow(
    decoration: header
        ? const pw.BoxDecoration(color: PdfColors.grey200)
        : null,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(a, style: style),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(b, style: style),
      ),
    ],
  );
}

pw.TableRow _pdfRow4(
  String a,
  String b,
  String c,
  String d, {
  bool header = false,
}) {
  final style = pw.TextStyle(
    fontSize: header ? 9 : 8,
    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.TableRow(
    decoration: header
        ? const pw.BoxDecoration(color: PdfColors.grey200)
        : null,
    children: [
      for (final t in [a, b, c, d])
        pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(t, style: style),
        ),
    ],
  );
}

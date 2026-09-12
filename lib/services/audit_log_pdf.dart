import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'audit_log_service.dart';
import '../l10n/tr.dart';

/// Builds an A4 PDF audit report grouped by calendar day.
///
/// Hardening additions vs the base version:
/// - Page header on every page after the first (company name + page number)
/// - Footer with page X / N + export ID on every page
/// - Export metadata section (exportId, generatedBy, generatedAt, rowCount,
///   SHA-256 fingerprint of all log IDs)
/// - All text is read-only by design; no interactive fields
Future<Uint8List> buildAuditLogPdfBytes({
  required List<AuditLogRow> logs,
  required String dateRangeLabel,
  required String companyName,
  String generatedBy = 'manager',
  String? exportId,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  final resolvedExportId = exportId ?? _generateExportId(now);
  final company = companyName.isNotEmpty ? companyName : tr.posSystem;

  // ── helpers ─────────────────────────────────────────────────────────────────

  String fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  String fmtDateTime(DateTime d) => '${fmtDate(d)} ${fmtTime(d)}';

  // ── grouping ────────────────────────────────────────────────────────────────

  final byDay = <String, List<AuditLogRow>>{};
  for (final log in logs) {
    final key =
        '${log.createdAt.year}-${log.createdAt.month.toString().padLeft(2, '0')}-${log.createdAt.day.toString().padLeft(2, '0')}';
    byDay.putIfAbsent(key, () => []).add(log);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  // ── actor summary ────────────────────────────────────────────────────────────

  final actorCounts = <String, int>{};
  for (final l in logs) {
    final actor = l.performedBy ?? 'system';
    actorCounts[actor] = (actorCounts[actor] ?? 0) + 1;
  }
  final topActors = actorCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // ── export fingerprint — SHA-256 of sorted log IDs ────────────────────────

  final fingerprint = _computeFingerprint(logs);

  // ── page decorators ──────────────────────────────────────────────────────────

  pw.Widget _pageHeader(pw.Context ctx) {
    if (ctx.pageNumber == 1) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '$company — Audit Log — $dateRangeLabel',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
            pw.Text(
              'Faqe ${ctx.pageNumber}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _pageFooter(pw.Context ctx) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            trf.exportIdReadOnly(resolvedExportId),
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
          pw.Text(
            'Faqe ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
          ),
        ],
      ),
    ],
  );

  // ── document ─────────────────────────────────────────────────────────────────

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: _pageHeader,
      footer: _pageFooter,
      build: (context) => [
        // ── Title ──────────────────────────────────────────────────────────
        pw.Text(
          company,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Audit Log — $dateRangeLabel',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          'Gjeneruar: ${fmtDateTime(now)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.SizedBox(height: 16),

        // ── Summary ────────────────────────────────────────────────────────
        pw.Text(
          tr.permbledhje,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            _hdr2('Metrika', 'Vlera'),
            _row2('Veprime gjithsej', '${logs.length}'),
            _row2(tr.dite, '${days.length}'),
            _row2(tr.aktoreUnike, '${actorCounts.length}'),
            if (topActors.isNotEmpty)
              _row2(
                tr.aktoriShumeVeprime,
                '${topActors.first.key} (${topActors.first.value})',
              ),
          ],
        ),
        pw.SizedBox(height: 12),

        // ── Export metadata ────────────────────────────────────────────────
        pw.Text(
          'Metadatat e eksportit',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(3),
          },
          children: [
            _hdr2('Fusha', 'Vlera'),
            _row2('Export ID',      resolvedExportId),
            _row2('Gjeneruar nga', generatedBy),
            _row2(tr.gjeneruar,  fmtDateTime(now)),
            _row2('Rreshta total', '${logs.length}'),
            _row2('Fingerprint',   fingerprint),
          ],
        ),
        pw.SizedBox(height: 18),

        // ── Day-by-day log ─────────────────────────────────────────────────
        pw.Text(
          'Regjistri i veprimeve',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),

        if (logs.isEmpty)
          pw.Text(
            tr.nukKaVeprimeKetePeriudhe,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          )
        else
          for (final day in days) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text(
                _dayLabel(day),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Table(
              border: pw.TableBorder(
                left:   const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                right:  const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.3),
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(56),  // time
                1: const pw.FlexColumnWidth(1.4),  // action
                2: const pw.FixedColumnWidth(52),  // actor
                3: const pw.FlexColumnWidth(2),    // entity
                4: const pw.FlexColumnWidth(2),    // details
              },
              children: [
                _logHdr(),
                for (final log in byDay[day]!) _logRow(log, fmtTime),
              ],
            ),
            pw.SizedBox(height: 12),
          ],

        pw.SizedBox(height: 10),
        pw.Text(
          tr.kyRaportEshteVetemLeximRegjistri,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  return pdf.save();
}

// ── private helpers ───────────────────────────────────────────────────────────

String _generateExportId(DateTime now) {
  final ts = now.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
  return 'AX-$ts';
}

/// SHA-256 of sorted log IDs — detects if the exported set was tampered.
String _computeFingerprint(List<AuditLogRow> logs) {
  if (logs.isEmpty) return '(empty)';
  try {
    final sorted = logs.map((l) => l.id).toList()..sort();
    final input  = sorted.join(',');
    return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
  } catch (_) {
    return 'N/A';
  }
}

String _dayLabel(String isoDay) {
  try {
    final d = DateTime.parse(isoDay);
    final weekdays = [
      tr.hene, tr.marte, tr.merkure,
      'E enjte', 'E premte', tr.shtune, 'E diel',
    ];
    return '${weekdays[d.weekday - 1]}, '
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  } catch (_) {
    return isoDay;
  }
}

pw.TableRow _hdr2(String a, String b) => pw.TableRow(
  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
  children: [
    for (final t in [a, b])
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ),
  ],
);

pw.TableRow _row2(String a, String b) => pw.TableRow(
  children: [
    for (final t in [a, b])
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)),
      ),
  ],
);

pw.TableRow _logHdr() => pw.TableRow(
  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
  children: [
    for (final t in ['Ora', 'Veprimi', 'Aktori', 'Entiteti', 'Detajet'])
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ),
  ],
);

pw.TableRow _logRow(AuditLogRow log, String Function(DateTime) fmtTime) {
  final details  = log.details;
  final detailStr = details == null
      ? ''
      : details.entries.map((e) => '${e.key}: ${e.value}').join(', ');

  return pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          fmtTime(log.createdAt),
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          AuditAction.label(log.actionType),
          style: const pw.TextStyle(fontSize: 7),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          log.performedBy ?? '—',
          style: const pw.TextStyle(fontSize: 7),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          [
            if (log.entityType != null) log.entityType!,
            if (log.entityId   != null) '#${log.entityId}',
          ].join(' '),
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          detailStr,
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
          maxLines: 2,
        ),
      ),
    ],
  );
}

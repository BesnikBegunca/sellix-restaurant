import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../manager/manager_data.dart';
import '../../../services/expenses_pdf_export.dart';
import '../../../services/manager_summary_pdf.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/reports/report_card.dart';

class ReportsPanel extends StatefulWidget {
  const ReportsPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<ReportsPanel> {
  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
  }

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  Future<void> _pdf({required bool printOnly}) async {
    final bytes = await buildManagerSummaryPdfBytes(widget.m);
    if (!mounted) return;
    if (printOnly) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'raport_pos_system_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  String _buildExpensesCsv() {
    final b = StringBuffer();
    b.writeln('Lloji,Përshkrimi,Shuma,Data');
    for (final e in widget.m.expenses) {
      final desc = e.description.replaceAll('"', '""').replaceAll('\n', ' ');
      b.writeln(
        '"${e.type}","$desc",${e.amount.toStringAsFixed(2)},${e.date.toIso8601String()}',
      );
    }
    return b.toString();
  }

  Future<void> _exportCsv(BuildContext context) async {
    final csv = _buildExpensesCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV u kopjua në clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _expensesPdf(
    BuildContext context, {
    required bool printOnly,
  }) async {
    final rows = widget.m.expenses;
    if (rows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nuk ka shpenzime për eksport.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.negativeText,
        ),
      );
      return;
    }
    final bytes = await buildExpensesPdfBytes(rows: rows);
    if (!context.mounted) return;
    if (printOnly) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'expenses_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  static const _rMonths = [
    'Jan', 'Feb', 'Mars', 'Apr', 'Maj', 'Qer',
    'Kor', 'Gus', 'Sht', 'Tet', 'Nën', 'Dhj',
  ];

  String _fmtDay(DateTime d) => '${_rMonths[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekNum = ((now.difference(DateTime(now.year, 1, 1)).inDays +
                DateTime(now.year, 1, 1).weekday - 1) /
            7)
        .ceil();
    final yesterday = now.subtract(const Duration(days: 1));

    final recentItems = <({String title, String subtitle, VoidCallback onDownload, VoidCallback onPrint})>[
      (
        title: 'Raporti Ditor - ${_fmtDay(now)}',
        subtitle: 'Sot · ~245 KB',
        onDownload: () => _pdf(printOnly: false),
        onPrint: () => _pdf(printOnly: true),
      ),
      (
        title: 'Përmbledhja Javore - Java $weekNum',
        subtitle: '${_fmtDay(yesterday)} · ~890 KB',
        onDownload: () => _pdf(printOnly: false),
        onPrint: () => _pdf(printOnly: true),
      ),
      (
        title: 'Përmbledhje Shpenzimesh',
        subtitle: '${_fmtDay(now)} · ~120 KB',
        onDownload: () => _expensesPdf(context, printOnly: false),
        onPrint: () => _expensesPdf(context, printOnly: true),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Raporte'),
        const SizedBox(height: 6),
        const Text(
          'Gjenero dhe eksporto raporte biznesi',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ReportCard(
                  icon: Icons.attach_money_outlined,
                  title: 'Raporti i Shitjeve Ditore',
                  subtitle: "Complete breakdown of today's sales",
                  onExport: () => _pdf(printOnly: false),
                  onPrint: () => _pdf(printOnly: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ReportCard(
                  icon: Icons.people_outline,
                  title: 'Performanca e Stafit',
                  subtitle: 'Shitjet dhe statistikat individuale të kamarierëve',
                  onExport: () => _pdf(printOnly: false),
                  onPrint: () => _pdf(printOnly: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ReportCard(
                  icon: Icons.description_outlined,
                  title: 'Përmbledhje Shpenzimesh',
                  subtitle: 'Të gjitha shpenzimet të kategorizuara dhe totalizuara',
                  onExport: () => _expensesPdf(context, printOnly: false),
                  onPrint: () => _expensesPdf(context, printOnly: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ReportCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Raporti i Inventarit',
                  subtitle: 'Nivelet aktuale të stokut dhe përdorimi',
                  onExport: () => _exportCsv(context),
                  onPrint: () => _pdf(printOnly: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Raportet e Fundit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < recentItems.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.lightGreenBorder,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recentItems[i].title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkGreenText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recentItems[i].subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGreenText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Shkarko',
                          icon: const Icon(
                            Icons.download_outlined,
                            size: 20,
                            color: AppColors.mediumGreenText,
                          ),
                          onPressed: recentItems[i].onDownload,
                        ),
                        IconButton(
                          tooltip: 'Shtyp',
                          icon: const Icon(
                            Icons.print_outlined,
                            size: 20,
                            color: AppColors.mediumGreenText,
                          ),
                          onPressed: recentItems[i].onPrint,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

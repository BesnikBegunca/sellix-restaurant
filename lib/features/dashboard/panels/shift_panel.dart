import 'package:flutter/material.dart';
import '../../../manager/manager_data.dart';
import '../../../services/receipt_printer.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/stat_card.dart';

class ShiftPanel extends StatelessWidget {
  const ShiftPanel({super.key, required this.m});

  final ManagerData m;

  Future<void> _showPrintDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ShiftStatusReport report;
    try {
      report = await m.computeShiftStatusReport();
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Nuk u lexua gjendja: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.darkGreenText,
          ),
        );
      }
      return;
    }

    final waiterTotals = report.waiterGrandTotalsForPrint();
    final ok = await ReceiptPrinter.printShiftStatus(
      companyName: m.companyName ?? 'POS System',
      waiterTotals: waiterTotals,
      summaryPaid: report.grandPaid,
      summaryOpen: report.grandOpen,
      reportTime: report.generatedAt,
    );

    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Gjendja u dërgua në printer.'
                : 'Nuk u printua. Zgjidh printerin te Company Settings > Printers.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? AppColors.primaryGreen : AppColors.darkGreenText,
        ),
      );
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => GjendjaDialog(m: m, isClose: false, initialReport: report),
      );
    }
  }

  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => GjendjaDialog(m: m, isClose: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = m.shiftOpen;
    final openedAt = m.shiftOpenedAt;
    final closedAt = m.shiftClosedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('Gjendja'),
        const SizedBox(height: 6),
        const Text(
          'Hap, shtyp ose mbyll turne operative.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 28),

        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final statusCard = Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOpen
                      ? AppColors.primaryGreen.withValues(alpha: 0.3)
                      : AppColors.lightGreenBorder,
                  width: isOpen ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppColors.primaryGreen.withValues(alpha: 0.1)
                          : AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isOpen ? Icons.play_circle_outline : Icons.stop_circle_outlined,
                      size: 32,
                      color: isOpen ? AppColors.primaryGreen : AppColors.lightGreenText,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                    : AppColors.lightGreenBg,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isOpen ? AppColors.primaryGreen : AppColors.lightGreenText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOpen ? 'E HAPUR' : 'E MBYLLUR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isOpen ? AppColors.primaryGreen : AppColors.lightGreenText,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOpen ? 'Gjendja aktive' : 'Gjendja e mbyllur',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isOpen && openedAt != null
                              ? 'Hapur: ${_fmtDateTime(openedAt)}'
                              : closedAt != null
                                  ? 'Mbyllur: ${_fmtDateTime(closedAt)}'
                                  : 'Nuk ka informacion shift.',
                          style: const TextStyle(fontSize: 13, color: AppColors.lightGreenText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final actions = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _showPrintDialog(context),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Shtyp gjendjen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showCloseDialog(context),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Mbyll gjendjen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.softRed,
                    side: BorderSide(color: AppColors.softRed.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: statusCard),
                  const SizedBox(width: 24),
                  SizedBox(width: 220, child: actions),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [statusCard, const SizedBox(height: 20), actions],
            );
          },
        ),

        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            StatCard(
              title: 'Shitje (sesioni)',
              value: '${m.waiterSales.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)}€',
              icon: Icons.point_of_sale_outlined,
              accentColor: AppColors.warmGold,
            ),
            StatCard(
              title: 'Shpenzime',
              value: '${m.totalExpenses.toStringAsFixed(0)}€',
              icon: Icons.payments_outlined,
              accentColor: AppColors.softRed,
            ),
            StatCard(
              title: 'Fitim neto',
              value: '${m.profitToday.toStringAsFixed(0)}€',
              icon: Icons.trending_up,
              accentColor: AppColors.primaryGreen,
            ),
            StatCard(
              title: 'Staf aktiv',
              value: '${m.waiters.length}',
              icon: Icons.badge_outlined,
            ),
          ],
        ),
      ],
    );
  }

  static String _fmtDateTime(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }
}

class GjendjaDialog extends StatefulWidget {
  const GjendjaDialog({
    super.key,
    required this.m,
    required this.isClose,
    this.initialReport,
  });

  final ManagerData m;
  final bool isClose;
  final ShiftStatusReport? initialReport;

  @override
  State<GjendjaDialog> createState() => _GjendjaDialogState();
}

class _GjendjaDialogState extends State<GjendjaDialog> {
  ShiftStatusReport? _report;
  Object? _loadError;
  bool _loading = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _report = widget.initialReport;
    if (_report == null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    try {
      final r = await widget.m.computeShiftStatusReport();
      if (!mounted) return;
      setState(() { _report = r; _loadError = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e; _loading = false; });
    }
  }

  String _fmtTime(DateTime t) {
    final d = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$d.$mo.${t.year} $h:$mi:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        title: Text(
          widget.isClose ? 'Mbyll gjendjen' : 'Gjendja aktuale',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const SizedBox(
          width: 280,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anulo')),
        ],
      );
    }

    if (_loadError != null) {
      return AlertDialog(
        title: const Text('Gabim'),
        content: Text('$_loadError'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mbyll')),
          FilledButton(
            onPressed: () {
              setState(() { _loading = true; _loadError = null; });
              _load();
            },
            child: const Text('Riprovo'),
          ),
        ],
      );
    }

    final report = _report!;
    final names = report.byWaiter.keys.toList()..sort();
    final grandPaid = report.grandPaid;
    final grandOpen = report.grandOpen;
    final grandTotal = report.grandTotal;
    final shiftLine = report.shiftId != null
        ? 'Shift #${report.shiftId} · aktiv'
        : 'Pa shift aktiv në DB';

    return AlertDialog(
      title: Text(
        widget.isClose ? 'Mbyll gjendjen' : 'Gjendja aktuale',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(shiftLine, style: TextStyle(fontSize: 12, color: AppColors.mediumGreenText)),
              Text('Përditësuar: ${_fmtTime(report.generatedAt)}',
                  style: TextStyle(fontSize: 12, color: AppColors.mediumGreenText)),
              const SizedBox(height: 12),
              if (names.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nuk ka shitje të regjistruara për shift-in dhe as porosi të hapura në tavolina.',
                    style: TextStyle(color: AppColors.mediumGreenText),
                  ),
                )
              else
                ...names.map((name) {
                  final w = report.byWaiter[name]!;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(
                      'Paguar: ${w.paidTotal.toStringAsFixed(2)}€ · '
                      'Hapur: ${w.openTotal.toStringAsFixed(2)}€ · '
                      'Porosi: ${w.paidOrderCount} paguar, ${w.openOrderCount} hapur',
                      style: TextStyle(fontSize: 11, color: AppColors.mediumGreenText),
                    ),
                    trailing: Text('${w.grandTotal.toStringAsFixed(2)}€',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  );
                }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paguar (gjithsej)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mediumGreenText)),
                  Text('${grandPaid.toStringAsFixed(2)}€',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hapur / pa paguar',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mediumGreenText)),
                  Text('${grandOpen.toStringAsFixed(2)}€',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Totali', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('${grandTotal.toStringAsFixed(2)}€',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              if (widget.isClose)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Ky është veprim përfundimtar: ruhet snapshot-i i shift-it, '
                    'mbyllen porositë e hapura në tavolina dhe nis shift i ri. '
                    'Nuk mund të kthehet mbrapsht.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGreenText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => Navigator.of(context).pop(),
          child: Text(widget.isClose ? 'Anulo' : 'Mbyll'),
        ),
        if (widget.isClose)
          FilledButton(
            onPressed: (_closing || _loading)
                ? null
                : () async {
                    setState(() => _closing = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final closureReport = _report!;
                    try {
                      await widget.m.closeShift();
                      if (!context.mounted) return;

                      final waiterTotals = closureReport.waiterGrandTotalsForPrint();
                      final printed = await ReceiptPrinter.printShiftStatus(
                        companyName: widget.m.companyName ?? 'POS System',
                        waiterTotals: waiterTotals,
                        summaryPaid: closureReport.grandPaid,
                        summaryOpen: closureReport.grandOpen,
                        reportTime: closureReport.generatedAt,
                      );

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            printed
                                ? 'Shift-i u mbyll. Përmbledhja e të gjithë punonjësve u printua.'
                                : 'Shift-i u mbyll, por përmbledhja nuk u printua. '
                                    'Kontrollo printerin te Company Settings > Printers.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: printed ? AppColors.primaryGreen : AppColors.darkGreenText,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Mbyllja dështoi (shift-i mbeti aktiv): $e'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.darkGreenText,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _closing = false);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkGreenText,
              foregroundColor: AppColors.white,
            ),
            child: _closing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Konfirmo mbylljen'),
          ),
      ],
    );
  }
}

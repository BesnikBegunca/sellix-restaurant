import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../services/receipt_printer.dart';
import '../../../../theme/app_colors.dart';

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
      setState(() {
        _report = r;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulo'),
          ),
        ],
      );
    }

    if (_loadError != null) {
      return AlertDialog(
        title: const Text('Gabim'),
        content: Text('$_loadError'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mbyll'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadError = null;
              });
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
              Text(
                shiftLine,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGreenText,
                ),
              ),
              Text(
                'Përditësuar: ${_fmtTime(report.generatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGreenText,
                ),
              ),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                    trailing: Text(
                      '${w.grandTotal.toStringAsFixed(2)}€',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paguar (gjithsej)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  Text(
                    '${grandPaid.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hapur / pa paguar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  Text(
                    '${grandOpen.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Totali',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${grandTotal.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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

                      final waiterTotals = closureReport
                          .waiterGrandTotalsForPrint();
                      final printed = await ReceiptPrinter.printShiftStatus(
                        header: ShiftReceiptHeader.closed,
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
                          backgroundColor: printed
                              ? AppColors.primaryGreen
                              : AppColors.darkGreenText,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Mbyllja dështoi (shift-i mbeti aktiv): $e',
                          ),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Konfirmo mbylljen'),
          ),
      ],
    );
  }
}

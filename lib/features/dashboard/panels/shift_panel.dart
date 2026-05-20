import 'package:flutter/material.dart';
import '../../../manager/manager_data.dart';
import '../../../services/receipt_printer.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/stat_card.dart';
import '../widgets/shift/gjendja_dialog.dart';

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
      header: ShiftReceiptHeader.pressed,
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

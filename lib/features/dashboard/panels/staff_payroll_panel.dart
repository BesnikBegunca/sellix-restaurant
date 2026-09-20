import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../widgets/stat_card.dart';
import '../widgets/staff/payroll_summary_row.dart';
import '../widgets/staff/waiter_payroll_detail.dart';
import '../widgets/staff/waiter_summary_card.dart';
import '../../../l10n/tr.dart';

class StaffPayrollPanel extends StatefulWidget {
  const StaffPayrollPanel({super.key, required this.m});
  final ManagerData m;
  @override
  State<StaffPayrollPanel> createState() => _StaffPayrollPanelState();
}

class _StaffPayrollPanelState extends State<StaffPayrollPanel> {
  late DateTime _viewMonth;
  WaiterInfo? _selectedWaiter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    widget.m.addListener(_onData);
  }

  void _onData() {
    if (_selectedWaiter != null) {
      final still = widget.m.waiters.where(
        (w) => w.name == _selectedWaiter!.name,
      );
      if (still.isEmpty) _selectedWaiter = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.m.removeListener(_onData);
    super.dispose();
  }

  static List<String> get _monthNames => [
    'Janar',
    'Shkurt',
    'Mars',
    'Prill',
    'Maj',
    'Qershor',
    'Korrik',
    'Gusht',
    'Shtator',
    'Tetor',
    tr.nentor,
    'Dhjetor',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = widget.m;

    if (_selectedWaiter != null) {
      return WaiterPayrollDetail(
        waiter: _selectedWaiter!,
        m: m,
        viewMonth: _viewMonth,
        onMonthChanged: (dt) => setState(() => _viewMonth = dt),
        onBack: () => setState(() => _selectedWaiter = null),
      );
    }

    final periodStart = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final periodEnd = DateTime(
      _viewMonth.year,
      _viewMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    double totalGross = 0;
    double totalAdv = 0;
    double maxGross = 0;
    for (final w in m.waiters) {
      final worked = m.workedDaysInMonth(
        w.name,
        _viewMonth.year,
        _viewMonth.month,
      );
      final rate = m.getSalary(w.name);
      final gross = rate * worked;
      totalGross += gross;
      totalAdv += m.totalAdvancesFor(w.name, periodStart, periodEnd);
      if (gross > maxGross) maxGross = gross;
    }
    final totalNet = totalGross - totalAdv;
    final staffCount = m.waiters.length;
    final avgSalary = staffCount > 0 ? totalGross / staffCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.payments_outlined,
          title: 'Pagat & Avans',
          subtitle: 'Menaxho pagat dhe avanset e stafit sipas muajit.',
          actions: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _viewMonth = DateTime(
                        _viewMonth.year,
                        _viewMonth.month - 1,
                      ),
                    ),
                    icon: Icon(
                      Icons.chevron_left,
                      color: AppColors.primaryGreen,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _viewMonth = DateTime(
                        _viewMonth.year,
                        _viewMonth.month + 1,
                      ),
                    ),
                    icon: Icon(
                      Icons.chevron_right,
                      color: AppColors.primaryGreen,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
        PanelStatRow(
          cards: [
            StatCard(
              icon: Icons.account_balance_wallet_outlined,
              title: tr.pagesaGjithsej,
              value: '${totalGross.toStringAsFixed(0)}€',
              accentColor: AppColors.primaryGreen,
            ),
            StatCard(
              icon: Icons.money_off_outlined,
              title: tr.avanseGjithsej,
              value: '${totalAdv.toStringAsFixed(0)}€',
              accentColor: AppColors.softRed,
            ),
            StatCard(
              icon: Icons.people_outline,
              title: tr.numriStafit,
              value: '$staffCount',
            ),
            StatCard(
              icon: Icons.check_circle_outline,
              title: tr.pagesaNeto,
              value: '${totalNet.toStringAsFixed(0)}€',
              accentColor: totalNet >= 0
                  ? AppColors.primaryGreen
                  : AppColors.softRed,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (m.waiters.isEmpty)
          _buildEmptyState()
        else
          PanelColumns(
            breakpoint: 980,
            leftFlex: 7,
            rightFlex: 4,
            left: PanelCard(
              icon: Icons.badge_outlined,
              title: 'Paga e stafit',
              subtitle: 'Hap një kamarier për detaje dhe avans.',
              child: Column(
                children: [
                  for (int i = 0; i < m.waiters.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: AppColors.lightGreenBorder),
                    WaiterSummaryCard(
                      waiter: m.waiters[i],
                      m: m,
                      viewMonth: _viewMonth,
                      onTap: () =>
                          setState(() => _selectedWaiter = m.waiters[i]),
                    ),
                  ],
                ],
              ),
            ),
            right: PanelCard(
              icon: Icons.summarize_outlined,
              title: tr.permbledhjaMujore,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.pagesaGjithsej,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${totalGross.toStringAsFixed(0)}€',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PayrollSummaryRow(
                    label: tr.pagaMesatare,
                    value: '${avgSalary.toStringAsFixed(2)}€',
                  ),
                  Divider(height: 24, color: AppColors.lightGreenBorder),
                  PayrollSummaryRow(
                    label: tr.brutoLarte,
                    value: '${maxGross.toStringAsFixed(2)}€',
                  ),
                  Divider(height: 24, color: AppColors.lightGreenBorder),
                  PayrollSummaryRow(
                    label: tr.avanseGjithsej,
                    value: '-${totalAdv.toStringAsFixed(2)}€',
                    valueColor: totalAdv > 0
                        ? AppColors.softRed
                        : AppColors.mediumGreenText,
                  ),
                  Divider(height: 24, color: AppColors.lightGreenBorder),
                  PayrollSummaryRow(
                    label: tr.numriStafit,
                    value: '$staffCount',
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.badge_outlined,
                size: 32,
                color: AppColors.lightGreenText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr.nukKaKamariereRegjistruar,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr.shkoKamarieretShtuarPunonjes,
              style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
            ),
          ],
        ),
      ),
    );
  }
}

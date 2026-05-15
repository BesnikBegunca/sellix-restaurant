import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/stat_card.dart';
import '../widgets/staff/payroll_summary_row.dart';
import '../widgets/staff/waiter_payroll_detail.dart';
import '../widgets/staff/waiter_summary_card.dart';

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

  static const _monthNames = [
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
    'Nëntor',
    'Dhjetor',
  ];

  @override
  Widget build(BuildContext context) {
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
        Row(
          children: [
            Expanded(child: sectionTitle('Pagat & Avans')),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGreenBorder),
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
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primaryGreen,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                      style: const TextStyle(
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
                    icon: const Icon(
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
        const SizedBox(height: 4),
        const Text(
          'Menaxho pagat dhe avanset e stafit sipas muajit.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Pagesa Gjithsej',
                  value: '${totalGross.toStringAsFixed(0)}€',
                  accentColor: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.money_off_outlined,
                  title: 'Avanse Gjithsej',
                  value: '${totalAdv.toStringAsFixed(0)}€',
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.people_outline,
                  title: 'Numri i Stafit',
                  value: '$staffCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.check_circle_outline,
                  title: 'Pagesa Neto',
                  value: '${totalNet.toStringAsFixed(0)}€',
                  accentColor: totalNet >= 0
                      ? AppColors.primaryGreen
                      : AppColors.softRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (m.waiters.isEmpty)
          _buildEmptyState()
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paga e Stafit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (int i = 0; i < m.waiters.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AppColors.lightGreenBorder,
                            ),
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
                ),
                const SizedBox(width: 20),

                SizedBox(
                  width: 320,
                  child: Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Përmbledhja Mujore',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              const Text(
                                'Pagesa Gjithsej',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mediumGreenText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${totalGross.toStringAsFixed(0)}€',
                                style: const TextStyle(
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
                          label: 'Paga Mesatare',
                          value: '${avgSalary.toStringAsFixed(2)}€',
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        PayrollSummaryRow(
                          label: 'Bruto Më i Lartë',
                          value: '${maxGross.toStringAsFixed(2)}€',
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        PayrollSummaryRow(
                          label: 'Avanse Gjithsej',
                          value: '-${totalAdv.toStringAsFixed(2)}€',
                          valueColor: totalAdv > 0
                              ? AppColors.softRed
                              : AppColors.mediumGreenText,
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        PayrollSummaryRow(
                          label: 'Numri i Stafit',
                          value: '$staffCount',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreenBorder),
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
              child: const Icon(
                Icons.badge_outlined,
                size: 32,
                color: AppColors.lightGreenText,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nuk ka kamarierë të regjistruar.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Shko te "Kamarierët" për të shtuar punonjës.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.lightGreenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


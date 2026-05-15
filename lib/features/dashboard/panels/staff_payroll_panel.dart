import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/stat_card.dart';

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
      return _WaiterPayrollDetail(
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
                          _WaiterSummaryCard(
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
                        _PayrollSummaryRow(
                          label: 'Paga Mesatare',
                          value: '${avgSalary.toStringAsFixed(2)}€',
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        _PayrollSummaryRow(
                          label: 'Bruto Më i Lartë',
                          value: '${maxGross.toStringAsFixed(2)}€',
                        ),
                        const Divider(
                          height: 24,
                          color: AppColors.lightGreenBorder,
                        ),
                        _PayrollSummaryRow(
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
                        _PayrollSummaryRow(
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

class _PayrollSummaryRow extends StatelessWidget {
  const _PayrollSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mediumGreenText,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

class _WaiterSummaryCard extends StatelessWidget {
  const _WaiterSummaryCard({
    required this.waiter,
    required this.m,
    required this.viewMonth,
    required this.onTap,
  });

  final WaiterInfo waiter;
  final ManagerData m;
  final DateTime viewMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worked = m.workedDaysInMonth(
      waiter.name,
      viewMonth.year,
      viewMonth.month,
    );
    final rate = m.getSalary(waiter.name);
    final gross = rate * worked;
    final periodStart = DateTime(viewMonth.year, viewMonth.month, 1);
    final periodEnd = DateTime(
      viewMonth.year,
      viewMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );
    final totalAdv = m.totalAdvancesFor(waiter.name, periodStart, periodEnd);
    final net = gross - totalAdv;
    final initial =
        waiter.name.isNotEmpty ? waiter.name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waiter.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rate > 0
                        ? '${rate.toStringAsFixed(2)}€/ditë · $worked ditë'
                        : 'Pa pagë të caktuar',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                _statCell('Bruto', '${gross.toStringAsFixed(0)}€',
                    AppColors.darkGreenText),
                const SizedBox(width: 20),
                if (totalAdv > 0)
                  _statCell('Avans', '-${totalAdv.toStringAsFixed(0)}€',
                      AppColors.softRed),
                if (totalAdv > 0) const SizedBox(width: 20),
                _statCell(
                  'Neto',
                  '${net.toStringAsFixed(0)}€',
                  net >= 0 ? AppColors.primaryGreen : AppColors.softRed,
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumGreenText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mediumGreenText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _WaiterPayrollDetail extends StatefulWidget {
  const _WaiterPayrollDetail({
    required this.waiter,
    required this.m,
    required this.viewMonth,
    required this.onMonthChanged,
    required this.onBack,
  });

  final WaiterInfo waiter;
  final ManagerData m;
  final DateTime viewMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onBack;

  @override
  State<_WaiterPayrollDetail> createState() => _WaiterPayrollDetailState();
}

class _WaiterPayrollDetailState extends State<_WaiterPayrollDetail> {
  bool _editingRate = false;
  bool _advancesExpanded = false;
  late final TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    final rate = widget.m.getSalary(widget.waiter.name);
    _rateCtrl = TextEditingController(
      text: rate > 0 ? rate.toStringAsFixed(2) : '',
    );
    widget.m.addListener(_onData);
  }

  void _onData() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onData);
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRate() async {
    final val = double.tryParse(_rateCtrl.text.replaceAll(',', '.'));
    if (val != null && val >= 0) {
      await widget.m.setSalary(widget.waiter.name, val);
    }
    if (mounted) setState(() => _editingRate = false);
  }

  Future<void> _selectAllDays() async {
    final m = widget.m;
    final w = widget.waiter;
    final month = widget.viewMonth;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final allWorked = Iterable.generate(daysInMonth, (i) => i + 1).every(
      (day) => m.isDayWorked(w.name, DateTime(month.year, month.month, day)),
    );
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isWorked = m.isDayWorked(w.name, date);
      if (allWorked ? isWorked : !isWorked) {
        await m.toggleWorkedDay(w.name, date);
      }
    }
  }

  Future<void> _showAddAdvanceDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            'Avans — ${widget.waiter.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDeco('Shuma (€)'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: inputDeco('Shënim (opsional)'),
                  maxLength: 80,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.mediumGreenText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pickedDate.day.toString().padLeft(2, '0')}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}',
                      style: const TextStyle(
                        color: AppColors.darkGreenText,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setDlg(() => pickedDate = d);
                      },
                      child: const Text('Ndrysho'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Anulo',
                style: TextStyle(color: AppColors.mediumGreenText),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () async {
                final amount = double.tryParse(
                  amountCtrl.text.replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) return;
                await widget.m.addAdvance(
                  AdvanceRow(
                    waiterName: widget.waiter.name,
                    amount: amount,
                    note: noteCtrl.text.trim(),
                    date: pickedDate,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Regjistro'),
            ),
          ],
        ),
      ),
    );
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
  static const _dayLabels = ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'];

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final w = widget.waiter;
    final month = widget.viewMonth;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final worked = m.workedDaysInMonth(w.name, month.year, month.month);
    final rate = m.getSalary(w.name);
    final gross = rate * worked;
    final periodStart = DateTime(month.year, month.month, 1);
    final periodEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final totalAdv = m.totalAdvancesFor(w.name, periodStart, periodEnd);
    final net = gross - totalAdv;
    final monthAdvances = m.advancesFor(w.name, periodStart, periodEnd);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final totalCells = (firstWeekday - 1) + daysInMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              color: AppColors.primaryGreen,
              tooltip: 'Kthehu',
            ),
            CircleAvatar(
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
              radius: 18,
              child: Text(
                w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              w.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _showAddAdvanceDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Avans'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle()),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onMonthChanged(
                      DateTime(month.year, month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primaryGreen,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[month.month - 1]} ${month.year}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (_) {
                      final allWorked = Iterable.generate(
                        daysInMonth,
                        (i) => i + 1,
                      ).every(
                        (day) => m.isDayWorked(
                          w.name,
                          DateTime(month.year, month.month, day),
                        ),
                      );
                      return TextButton(
                        onPressed: _selectAllDays,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          allWorked ? 'Çzgjidh të Gjitha' : 'Zgjidh të Gjitha',
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => widget.onMonthChanged(
                      DateTime(month.year, month.month + 1),
                    ),
                    icon: const Icon(Icons.chevron_right),
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _dayLabels
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: totalCells,
                itemBuilder: (_, i) {
                  if (i < firstWeekday - 1) return const SizedBox.shrink();
                  final day = i - (firstWeekday - 1) + 1;
                  final date = DateTime(month.year, month.month, day);
                  final isWorked = m.isDayWorked(w.name, date);
                  return GestureDetector(
                    onTap: () async => m.toggleWorkedDay(w.name, date),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isWorked ? AppColors.primaryGreen : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isWorked
                            ? null
                            : Border.all(
                                color: AppColors.borderSubtle(0.08),
                                width: 0.5,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isWorked
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isWorked
                                ? AppColors.white
                                : AppColors.darkGreenText,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ditë të punuara: $worked / $daysInMonth  •  ${_monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.euro_outlined,
                    size: 18,
                    color: AppColors.mediumGreenText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Paga ditore:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_editingRate)
                    SizedBox(
                      width: 110,
                      height: 36,
                      child: TextField(
                        controller: _rateCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 2,
                            ),
                          ),
                          suffixText: '€',
                        ),
                        onSubmitted: (_) => _saveRate(),
                      ),
                    )
                  else
                    Text(
                      rate > 0
                          ? '${rate.toStringAsFixed(2)}€/ditë'
                          : 'E pacaktuar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: rate > 0
                            ? AppColors.darkGreenText
                            : AppColors.lightGreenText,
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (_editingRate) ...[
                    IconButton(
                      onPressed: _saveRate,
                      icon: const Icon(Icons.check, size: 18),
                      color: AppColors.primaryGreen,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _editingRate = false),
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.negativeText,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ] else
                    IconButton(
                      onPressed: () => setState(() => _editingRate = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: AppColors.mediumGreenText,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Ndrysho pagën ditore',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _payKpi(
                    'Ditë të punuara',
                    '$worked',
                    Icons.calendar_month_outlined,
                  ),
                  _payKpi(
                    'Paga bruto',
                    '${gross.toStringAsFixed(2)}€',
                    Icons.account_balance_wallet_outlined,
                  ),
                  _payKpi(
                    'Avanse',
                    '${totalAdv.toStringAsFixed(2)}€',
                    Icons.money_off_outlined,
                    negative: true,
                  ),
                  _payKpi(
                    'Mbetet',
                    '${net.toStringAsFixed(2)}€',
                    Icons.check_circle_outline,
                    positive: net >= 0,
                  ),
                ],
              ),
              if (monthAdvances.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () =>
                      setState(() => _advancesExpanded = !_advancesExpanded),
                  child: Row(
                    children: [
                      Icon(
                        _advancesExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: AppColors.mediumGreenText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Avanse (${monthAdvances.length})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mediumGreenText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_advancesExpanded) ...[
                  const SizedBox(height: 8),
                  ...monthAdvances.map(_buildAdvanceRow),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvanceRow(AdvanceRow a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.negativeBg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.negativeText.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.arrow_downward,
              size: 14,
              color: AppColors.negativeText,
            ),
            const SizedBox(width: 8),
            Text(
              '${a.amount.toStringAsFixed(2)}€',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.negativeText,
              ),
            ),
            if (a.note.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGreenText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            Text(
              '${a.date.day.toString().padLeft(2, '0')}.${a.date.month.toString().padLeft(2, '0')}.${a.date.year}',
              style: TextStyle(fontSize: 11, color: AppColors.lightGreenText),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () async {
                if (a.dbId != null) await widget.m.deleteAdvance(a.dbId!);
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              color: AppColors.negativeText,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Fshi avancin',
            ),
          ],
        ),
      ),
    );
  }

  Widget _payKpi(
    String label,
    String value,
    IconData icon, {
    bool negative = false,
    bool? positive,
  }) {
    final Color col = positive != null
        ? (positive ? AppColors.primaryGreen : AppColors.negativeText)
        : negative
        ? AppColors.negativeText
        : AppColors.darkGreenText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: negative
            ? AppColors.negativeBg.withValues(alpha: 0.4)
            : AppColors.lightGreenBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: negative
              ? AppColors.negativeText.withValues(alpha: 0.12)
              : AppColors.borderSubtle(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: col),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: AppColors.lightGreenText),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: col,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../shared/widgets/dashboard_helpers.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/tr.dart';

class WaiterPayrollDetail extends StatefulWidget {
  const WaiterPayrollDetail({
    super.key,
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
  State<WaiterPayrollDetail> createState() => _WaiterPayrollDetailState();
}

class _WaiterPayrollDetailState extends State<WaiterPayrollDetail> {
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
            style: TextStyle(
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
                  decoration: inputDeco(tr.shuma),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: inputDeco(tr.shenimOpsional),
                  maxLength: 80,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.mediumGreenText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pickedDate.day.toString().padLeft(2, '0')}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}',
                      style: TextStyle(
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
                      child: Text(tr.ndrysho),
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
                tr.anulo,
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
  static List<String> get _dayLabels => [tr.hen, 'Mar', tr.mer, 'Enj', 'Pre', 'Sht', 'Die'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              tooltip: tr.kthehu,
            ),
            CircleAvatar(
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
              radius: 18,
              child: Text(
                w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              w.name,
              style: TextStyle(
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
            color: scheme.surfaceContainerHighest,
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (_) {
                      final allWorked =
                          Iterable.generate(daysInMonth, (i) => i + 1).every(
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
                          allWorked ? tr.czgjidhGjitha : tr.zgjidhGjitha,
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
                  trf.daysWorkedOf(worked, daysInMonth, '${_monthNames[month.month - 1]} ${month.year}'),
                  style: TextStyle(
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
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
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
                            borderSide: BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
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
                          ? trf.ratePerDay(rate.toStringAsFixed(2))
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
                      tooltip: tr.ndryshoPagenDitore,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _payKpi(
                    tr.ditePunuara,
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
            Icon(
              Icons.arrow_downward,
              size: 14,
              color: AppColors.negativeText,
            ),
            const SizedBox(width: 8),
            Text(
              '${a.amount.toStringAsFixed(2)}€',
              style: TextStyle(
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
              tooltip: tr.fshiAvancin,
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../manager/manager_data.dart';
import '../../../services/expenses_pdf_export.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/expenses/expense_filter_chip.dart';
import '../widgets/expenses/expenses_data_table.dart';
import '../widgets/expenses/expenses_empty_state.dart';
import '../widgets/stat_card.dart';

enum _ExpSort { dateDesc, dateAsc, amountDesc, amountAsc }

class ExpensesPanel extends StatefulWidget {
  const ExpensesPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<ExpensesPanel> createState() => _ExpensesPanelState();
}

class _ExpensesPanelState extends State<ExpensesPanel> {
  final _searchCtrl = TextEditingController();
  String? _typeFilter;
  _ExpSort _sort = _ExpSort.dateDesc;

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
    _searchCtrl.addListener(_onM);
  }

  void _onM() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    _searchCtrl.removeListener(_onM);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ExpenseRow> _filtered(List<ExpenseRow> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = all.where((e) {
      if (_typeFilter != null && e.type != _typeFilter) return false;
      if (q.isEmpty) return true;
      return e.description.toLowerCase().contains(q) ||
          e.type.toLowerCase().contains(q) ||
          e.amount.toString().contains(q);
    }).toList();

    switch (_sort) {
      case _ExpSort.dateDesc:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case _ExpSort.dateAsc:
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case _ExpSort.amountDesc:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _ExpSort.amountAsc:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  int _indexInManager(ExpenseRow row) => widget.m.expenses.indexOf(row);

  Future<void> _exportPdf(
    BuildContext context, {
    required bool printDialog,
  }) async {
    final rows = _filtered(widget.m.expenses);
    if (rows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Nuk ka rreshta për eksport — shto ose ndrysho filtrat.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.negativeText,
        ),
      );
      return;
    }
    final bytes = await buildExpensesPdfBytes(rows: rows);
    if (!context.mounted) return;
    if (printDialog) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'shpenzime_pos_system_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    }
  }

  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mars',
    'Apr',
    'Maj',
    'Qer',
    'Kor',
    'Gus',
    'Sht',
    'Tet',
    'Nën',
    'Dhj',
  ];

  String _fmtDateLong(DateTime d) =>
      '${_monthsEn[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = widget.m;
    final filtered = _filtered(m.expenses);
    final totalAll = m.expenses.fold<double>(0, (s, e) => s + e.amount);
    final types = m.expenses.map((e) => e.type).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Shpenzime'),
        const SizedBox(height: 6),
        Text(
          'Ndjek, filtro dhe eksporto transaksionet operative.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  title: 'Shpenzime Gjithsej',
                  value: '${totalAll.toStringAsFixed(2)}€',
                  icon: Icons.attach_money,
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Today's Expenses",
                  value: '${m.expensesToday.toStringAsFixed(2)}€',
                  icon: Icons.trending_down_outlined,
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Transaksione',
                  value: '${m.expenses.length}',
                  icon: Icons.receipt_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Këtë Muaj',
                  value: '${m.expensesThisMonth.toStringAsFixed(0)}€',
                  icon: Icons.calendar_month_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Të gjitha transaksionet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(context, printDialog: false),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Eksporto PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreenText,
                        side: BorderSide(
                          color: AppColors.lightGreenBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => _exportPdf(context, printDialog: true),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Shtyp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreenText,
                        side: BorderSide(
                          color: AppColors.lightGreenBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openAddDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Shto Shpenzim'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.lightGreenText,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.lightGreenBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.lightGreenBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: TextStyle(
                      color: AppColors.lightGreenText,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ExpenseFilterChip(
                        label: 'Të gjitha',
                        selected: _typeFilter == null,
                        onTap: () => setState(() => _typeFilter = null),
                      ),
                      for (final t in types) ...[
                        const SizedBox(width: 8),
                        ExpenseFilterChip(
                          label: t,
                          selected: _typeFilter == t,
                          onTap: () => setState(() => _typeFilter = t),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (filtered.isEmpty)
                  ExpensesEmptyState(onAdd: () => _openAddDialog(context))
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final tableWidth = math.max(640.0, c.maxWidth);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: tableWidth,
                            maxWidth: tableWidth,
                          ),
                          child: ExpensesDataTable(
                            rows: filtered,
                            fmtDate: _fmtDateLong,
                            onDelete: (row) {
                              final i = _indexInManager(row);
                              if (i >= 0) m.removeExpenseAt(i);
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final result = await showDialog<_AddExpenseResult>(
      context: context,
      builder: (_) => const _AddExpenseDialog(),
    );
    if (result == null || !context.mounted) return;
    widget.m.addExpense(
      ExpenseRow(
        type: result.type,
        description: result.description,
        amount: result.amount,
      ),
    );
  }
}

class _AddExpenseResult {
  const _AddExpenseResult({
    required this.type,
    required this.description,
    required this.amount,
  });

  final String type;
  final String description;
  final double amount;
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  var _selType = 'Shpenzim';

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    final description = _descCtrl.text.trim();
    if (amount <= 0 || description.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(
      _AddExpenseResult(
        type: _selType,
        description: description,
        amount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shto shpenzim / rrogë'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: inputDeco('Lloji'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Shpenzim',
                      child: Text('Shpenzim'),
                    ),
                    DropdownMenuItem(value: 'Rrogë', child: Text('Rrogë')),
                    DropdownMenuItem(value: 'Bonus', child: Text('Bonus')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selType = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: inputDeco('Përshkrimi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amtCtrl,
              decoration: inputDeco('Shuma'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anulo'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ruaj')),
      ],
    );
  }
}

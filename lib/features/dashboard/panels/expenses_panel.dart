import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../manager/manager_data.dart';
import '../../../services/expenses_pdf_export.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
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

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
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
    'Jan', 'Feb', 'Mars', 'Apr', 'Maj', 'Qer',
    'Kor', 'Gus', 'Sht', 'Tet', 'Nën', 'Dhj',
  ];

  String _fmtDateLong(DateTime d) =>
      '${_monthsEn[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final filtered = _filtered(m.expenses);
    final totalAll = m.expenses.fold<double>(0, (s, e) => s + e.amount);
    final types = m.expenses.map((e) => e.type).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Shpenzime'),
        const SizedBox(height: 6),
        const Text(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
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
                        side: const BorderSide(
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
                        side: const BorderSide(
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
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.lightGreenText,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.lightGreenBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.lightGreenBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: const TextStyle(
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
                      _ExpenseFilterChip(
                        label: 'Të gjitha',
                        selected: _typeFilter == null,
                        onTap: () => setState(() => _typeFilter = null),
                      ),
                      for (final t in types) ...[
                        const SizedBox(width: 8),
                        _ExpenseFilterChip(
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
                  _ExpensesEmptyState(onAdd: () => _openAddDialog(context))
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
                          child: _ExpensesDataTable(
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
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    var selType = 'Shpenzim';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Shto shpenzim / rrogë'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputDecorator(
                  decoration: inputDeco('Lloji'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selType,
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
                        if (v != null) {
                          setSt(() => selType = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: inputDeco('Përshkrimi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  decoration: inputDeco('Shuma (USD)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anulo'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ruaj'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && context.mounted) {
      final a = double.tryParse(amtCtrl.text.trim()) ?? 0;
      if (a > 0 && descCtrl.text.trim().isNotEmpty) {
        widget.m.addExpense(
          ExpenseRow(
            type: selType,
            description: descCtrl.text.trim(),
            amount: a,
          ),
        );
      }
    }
    descCtrl.dispose();
    amtCtrl.dispose();
  }
}

class _ExpensesEmptyState extends StatelessWidget {
  const _ExpensesEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.08)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.lightGreenText.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Nuk ka rreshta që përputhen me filtrat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zbraz kërkimin, zgjidh "Të gjitha" te lloji, ose shto një transaksion të ri.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.mediumGreenText),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Shto transaksion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseFilterChip extends StatelessWidget {
  const _ExpenseFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.lightGreenBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.white : AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }
}

class _ExpensesDataTable extends StatelessWidget {
  const _ExpensesDataTable({
    required this.rows,
    required this.fmtDate,
    required this.onDelete,
  });

  final List<ExpenseRow> rows;
  final String Function(DateTime) fmtDate;
  final void Function(ExpenseRow) onDelete;

  Color _categoryColor(String type) {
    switch (type) {
      case 'Rrogë':
        return const Color(0xFF2E7D32);
      case 'Bonus':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.lightGreenText,
      letterSpacing: 0.6,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(color: AppColors.lightGreenBg),
            child: const Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text('DATA', style: headerStyle),
                ),
                SizedBox(
                  width: 130,
                  child: Text('KATEGORIA', style: headerStyle),
                ),
                Expanded(
                  child: Text('PËRSHKRIMI', style: headerStyle),
                ),
                SizedBox(
                  width: 140,
                  child: Text('MËNYRA E PAGESËS', style: headerStyle),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'SHUMA',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(width: 52),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.lightGreenBorder,
            ),
            itemBuilder: (context, i) {
              final e = rows[i];
              final catColor = _categoryColor(e.type);
              return Material(
                color: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          fmtDate(e.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: catColor.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            e.type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: catColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            e.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.darkGreenText,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          '—',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${e.amount.toStringAsFixed(2)}€',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.negativeText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: IconButton(
                          tooltip: 'Fshi rreshtin',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.negativeText.withValues(alpha: 0.7),
                          ),
                          onPressed: () => onDelete(e),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

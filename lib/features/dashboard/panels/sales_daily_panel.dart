import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/dashboard/app_empty_states.dart';
import '../../../widgets/dashboard/data_table_card.dart';
import '../widgets/stat_card.dart';

class _TableRowKind {
  const _TableRowKind.data(this.shift) : day = null, total = null;
  const _TableRowKind.dayTotal(this.day, this.total) : shift = null;

  final ShiftRecord? shift;
  final DateTime? day;
  final double? total;

  bool get isDayTotal => day != null;
}

class SalesDailyPanel extends StatefulWidget {
  const SalesDailyPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<SalesDailyPanel> createState() => _SalesDailyPanelState();
}

class _SalesDailyPanelState extends State<SalesDailyPanel> {
  bool _loading = true;
  List<ShiftRecord> _closedShifts = const [];

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
    _load();
  }

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  void _onM() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await DatabaseService.instance.fetchClosedShifts();
      if (!mounted) return;
      setState(() {
        _closedShifts = rows.map(ShiftRecord.fromMap).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closedShifts = const [];
        _loading = false;
      });
    }
  }

  static String _formatDate(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year}';
  }

  static String _formatTime(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.hour)}:${p(d.minute)}';
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_TableRowKind> _buildTableRows() {
    final byDay = <String, List<ShiftRecord>>{};
    for (final s in _closedShifts) {
      final closed = s.closedAt;
      if (closed == null) continue;
      final key = _dayKey(closed);
      (byDay[key] ??= []).add(s);
    }

    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    final out = <_TableRowKind>[];
    for (final key in dayKeys) {
      final dayShifts = byDay[key]!
        ..sort((a, b) => a.closedAt!.compareTo(b.closedAt!));
      var dayTotal = 0.0;
      for (final s in dayShifts) {
        out.add(_TableRowKind.data(s));
        dayTotal += s.totalSales;
      }
      final day = dayShifts.first.closedAt!;
      out.add(
        _TableRowKind.dayTotal(
          DateTime(day.year, day.month, day.day),
          dayTotal,
        ),
      );
    }
    return out;
  }

  String _periodLabel(ShiftRecord s) {
    final closed = s.closedAt!;
    final opened = s.openedAt;
    return '${_formatTime(opened)} – ${_formatTime(closed)}';
  }

  @override
  Widget build(BuildContext context) {
    final tableRows = _buildTableRows();
    final closeCount = _closedShifts.length;
    final grandTotal = _closedShifts.fold<double>(
      0,
      (sum, s) => sum + s.totalSales,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelHeader(
          icon: Icons.point_of_sale_outlined,
          title: 'Shitjet',
          subtitle: 'Çdo rresht = një mbyllje gjendje. Totali është shitja e atij intervali ' '(nga hapja deri në mbylljen e gjendjes).',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final cards = [
              StatCard(
                title: 'Mbyllje gjendje',
                value: '$closeCount',
                icon: Icons.schedule_outlined,
              ),
              StatCard(
                title: 'Totali (të gjitha)',
                value: '${grandTotal.toStringAsFixed(2)}€',
                icon: Icons.payments_outlined,
                accentColor: AppColors.warmGold,
              ),
            ];
            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
              );
            }
            return Column(
              children: [cards[0], const SizedBox(height: 12), cards[1]],
            );
          },
        ),
        const SizedBox(height: 24),
        if (_loading)
          Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (tableRows.isEmpty)
          DashboardEmptyState(
            title: 'Nuk ka mbyllje gjendje',
            message:
                'Kur mbyllni gjendjen nga paneli Gjendja, shitjet e atij intervali '
                'shfaqen këtu me datën dhe orën.',
            icon: Icons.receipt_long_outlined,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  constraints.maxWidth - AppTokens.cardPadding * 2;
              return DataTableCard(
                title: 'Shitjet sipas mbylljes së gjendjes',
                subtitle:
                    'Data · ora e mbylljes · intervali · totali për atë gjendje',
                table: SizedBox(
                  width: tableWidth > 0 ? tableWidth : constraints.maxWidth,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.lightGreenBg,
                    ),
                    columnSpacing: 24,
                    horizontalMargin: 18,
                    columns: [
                      DataColumn(
                        label: Text(
                          'Data',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Ora e mbylljes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Periudha',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Text(
                          'Totali',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                    ],
                    rows: [
                      for (final row in tableRows)
                        if (row.isDayTotal)
                          DataRow(
                            color: WidgetStateProperty.all(
                              AppColors.lightGreenBg.withValues(alpha: 0.65),
                            ),
                            cells: [
                              DataCell(
                                Text(
                                  'Totali ditor · ${_formatDate(row.day!)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreenText,
                                  ),
                                ),
                              ),
                              const DataCell(SizedBox.shrink()),
                              const DataCell(SizedBox.shrink()),
                              DataCell(
                                Text(
                                  '${row.total!.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  _formatDate(row.shift!.closedAt!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.darkGreenText,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatTime(row.shift!.closedAt!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.darkGreenText,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _periodLabel(row.shift!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.mediumGreenText,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${row.shift!.totalSales.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

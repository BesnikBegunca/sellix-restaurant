import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/stat_card.dart';

class TablesConfigPanel extends StatefulWidget {
  const TablesConfigPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<TablesConfigPanel> createState() => _TablesConfigPanelState();
}

class _TablesConfigPanelState extends State<TablesConfigPanel> {
  late double _count;
  late double _perRow;

  String? _tableViewWaiter;
  List<TableInfo>? _waiterTablesSnapshot;

  List<TableInfo> _displayTables(ManagerData m) {
    if (_tableViewWaiter == null) return m.cashierTables;
    return _waiterTablesSnapshot ?? m.cashierTables;
  }

  Future<void> _syncWaiterTables() async {
    final w = _tableViewWaiter;
    if (w == null) {
      if (mounted) setState(() => _waiterTablesSnapshot = null);
      return;
    }
    final list = await widget.m.tablesForWaiter(w);
    if (!mounted || _tableViewWaiter != w) return;
    setState(() => _waiterTablesSnapshot = list);
  }

  @override
  void initState() {
    super.initState();
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
    widget.m.addListener(_onM);
  }

  void _onM() {
    setState(() {});
    if (_tableViewWaiter != null) {
      _syncWaiterTables();
    }
  }

  @override
  void didUpdateWidget(covariant TablesConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.m.removeListener(_onM);
    widget.m.addListener(_onM);
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
  }

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final n = _count.round();
    final pr = _perRow.round();
    final occupied = m.cashierTables.where((t) => t.occupied).length;
    final free = m.cashierTables.length - occupied;
    final total = m.cashierTables.length;
    final occupancyPct = total > 0 ? (occupied / total * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Menaxhimi i Tavolinave'),
        const SizedBox(height: 6),
        const Text(
          'Monitoro dhe menaxho tavolinat e restorantit',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.table_restaurant_outlined,
                  title: 'Tavolina Gjithsej',
                  value: '$total',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.people_outline,
                  title: 'Tavolina të Lira',
                  value: '$free',
                  accentColor: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.schedule_outlined,
                  title: 'Të Zëna',
                  value: '$occupied',
                  accentColor: AppColors.softRed,
                  badge: '$occupancyPct%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.event_available_outlined,
                  title: 'Të Rezervuara',
                  value: '0',
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
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
              Row(
                children: [
                  const Text(
                    'Planimetria',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const Spacer(),
                  _TableLegendDot(
                    color: AppColors.primaryGreen,
                    label: 'Lirë',
                  ),
                  const SizedBox(width: 16),
                  _TableLegendDot(
                    color: AppColors.softRed,
                    label: 'Zënë',
                  ),
                  const SizedBox(width: 16),
                  _TableLegendDot(
                    color: AppColors.warmGold,
                    label: 'Rezervuar',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: pr.clamp(2, 12),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemCount: n,
                itemBuilder: (context, i) {
                  final id = i + 1;
                  TableInfo? info;
                  try {
                    info = m.cashierTables.firstWhere((t) => t.id == id);
                  } catch (_) {}
                  final occ = info?.occupied ?? false;

                  const freeBg = Color(0xFFECF5EC);
                  const freeBorder = Color(0xFFB8DEB8);
                  const occBg = Color(0xFFFFF0F0);
                  const occBorder = Color(0xFFFFCDD2);
                  const freeGreen = Color(0xFF4CAF50);
                  const occRed = Color(0xFFEF5350);

                  final bg = occ ? occBg : freeBg;
                  final border = occ ? occBorder : freeBorder;
                  final dot = occ ? occRed : freeGreen;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$id',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkGreenText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: occ
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (info?.assignedWaiterName != null)
                                      Text(
                                        info!.assignedWaiterName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkGreenText,
                                        ),
                                      ),
                                    if ((info?.currentTotal ?? 0) > 0)
                                      Text(
                                        '${info!.currentTotal!.toStringAsFixed(0)}€',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mediumGreenText,
                                        ),
                                      ),
                                  ],
                                )
                              : const Text(
                                  'Lirë',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: freeGreen,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Konfigurimi i Planimetrisë',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Numri i tavolinave',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_count.round()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryGreen,
                  inactiveTrackColor: AppColors.lightGreenBorder,
                  thumbColor: AppColors.primaryGreen,
                  overlayColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _count,
                  min: 1,
                  max: 48,
                  divisions: 47,
                  label: '${_count.round()}',
                  onChanged: (v) => setState(() => _count = v),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Tavolina për rresht',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_perRow.round()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primaryGreen,
                  inactiveTrackColor: AppColors.lightGreenBorder,
                  thumbColor: AppColors.primaryGreen,
                  overlayColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: _perRow,
                  min: 2,
                  max: 12,
                  divisions: 10,
                  label: '${_perRow.round()}',
                  onChanged: (v) => setState(() => _perRow = v),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () {
                    m.setTableLayout(
                      count: _count.round(),
                      perRow: _perRow.round(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Table layout saved.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Ruaj Planimetrinë'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableLegendDot extends StatelessWidget {
  const _TableLegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mediumGreenText,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/pos_grid.dart';
import '../widgets/gg_header.dart';
import '../widgets/hover_interaction.dart';
import 'pos_order_screen.dart';

class TableSelectionScreen extends StatefulWidget {
  const TableSelectionScreen({super.key, required this.waiterName});

  final String waiterName;

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  final ManagerData _m = ManagerData.instance;
  List<TableInfo> _tables = const [];

  @override
  void initState() {
    super.initState();
    _m.addListener(_onManager);
    _reloadTables();
  }

  void _onManager() {
    _reloadTables();
  }

  Future<void> _reloadTables() async {
    final tables = await _m.tablesForWaiter(widget.waiterName);
    if (!mounted) return;
    setState(() {
      _tables = tables;
    });
  }

  @override
  void dispose() {
    _m.removeListener(_onManager);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tables = _tables;
    final occupied = tables.where((t) => t.occupied).length;
    final total = tables.fold<double>(0, (s, t) => s + (t.currentTotal ?? 0));

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Column(
        children: [
          GgAppHeader(
            showBack: true,
            title: 'Tavolinat',
            userName: widget.waiterName,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TableScreenHeaderRow(
                    total: total,
                    occupied: occupied,
                    waiterName: widget.waiterName,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = PosGrid.spacing;
                        const ratio = PosGrid.childAspectRatio;
                        final itemCount = tables.length + 1;
                        final W = constraints.maxWidth;
                        final H = constraints.maxHeight;

                        // Start from 4 columns and increase until all rows
                        // fit in the available height (proportional shrink).
                        int columns = PosGrid.crossAxisCount;
                        while (columns < itemCount) {
                          final rows = (itemCount / columns).ceil();
                          final cellW = (W - (columns - 1) * spacing) / columns;
                          final cellH = cellW / ratio;
                          final needed = rows * cellH + (rows - 1) * spacing;
                          if (needed <= H) break;
                          columns++;
                        }

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                childAspectRatio: ratio,
                              ),
                          itemCount: itemCount,
                          itemBuilder: (context, i) {
                            if (i == tables.length) {
                              return _AddTableCard(onTap: _m.addCashierTable);
                            }
                            final t = tables[i];
                            return _TableCard(
                              table: t,
                              onTap: () {
                                final orderNo = t.occupied
                                    ? (t.currentOrderNumber ?? 1)
                                    : 0;
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PosOrderScreen(
                                      tableNumber: t.id,
                                      orderNumber: orderNo,
                                      waiterName: widget.waiterName,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rreshti i sipërm: totali + badge i tavolinave të zëna.
class _TableScreenHeaderRow extends StatelessWidget {
  const _TableScreenHeaderRow({
    required this.total,
    required this.occupied,
    required this.waiterName,
  });

  final double total;
  final int occupied;
  final String waiterName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Totali i të gjitha tavolinave',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${total.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkGreenText,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _OccupiedCountBadge(occupied: occupied),
            ],
          ),
        ),
      ],
    );
  }
}

class _OccupiedCountBadge extends StatelessWidget {
  const _OccupiedCountBadge({required this.occupied});

  final int occupied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        occupied == 0
            ? 'Të gjitha të lira'
            : occupied == 1
                ? '1 e zënë'
                : '$occupied të zëna',
        style: const TextStyle(fontSize: 14, color: AppColors.primaryGreen),
      ),
    );
  }
}

/// Kartë me të njëjtën madhësi si tavolinat: bardhë, qoshe 20px, “+” në qendër.
class _AddTableCard extends StatefulWidget {
  const _AddTableCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddTableCard> createState() => _AddTableCardState();
}

class _AddTableCardState extends State<_AddTableCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return HoverLiftCard(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderSubtle(_hover ? 0.3 : 0.1),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _hover
                    ? AppColors.lightGreenBg
                    : AppColors.lightGreenBg.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 32,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableCard extends StatefulWidget {
  const _TableCard({required this.table, required this.onTap});

  final TableInfo table;
  final VoidCallback onTap;

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.table.occupied;
    return HoverLiftCard(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: o ? AppColors.lightGreenBg : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: o
                  ? AppColors.borderEmphasized(0.3)
                  : AppColors.borderSubtle(_hover ? 0.3 : 0.1),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Tavolina ${widget.table.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusPill(occupied: o),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: AppColors.borderSubtle(0.1)),
                    const SizedBox(height: 8),
                    if (o && widget.table.currentTotal != null) ...[
                      const Text(
                        'Totali aktual',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${widget.table.currentTotal!.toStringAsFixed(2)}€',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                    ] else
                      const Text(
                        'Nuk ka porosi aktive',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.occupied});

  final bool occupied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: occupied
            ? AppColors.primaryGreen.withValues(alpha: 0.1)
            : AppColors.lightGreenText.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        occupied ? 'E zënë' : 'E lirë',
        style: TextStyle(
          fontSize: 11,
          color: occupied ? AppColors.primaryGreen : AppColors.lightGreenText,
        ),
      ),
    );
  }
}

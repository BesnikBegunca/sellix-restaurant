import 'dart:async';

import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/pos_grid.dart';
import '../widgets/gg_header.dart';
import '../widgets/hover_interaction.dart';
import 'pos_order_screen.dart';
import '../services/app_language_service.dart';

class TableSelectionScreen extends StatefulWidget {
  const TableSelectionScreen({super.key, required this.waiterName});

  final String waiterName;

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  final ManagerData _m = ManagerData.instance;
  final _language = AppLanguageService.instance;
  List<TableInfo> _tables = const [];
  bool _loadingTables = true;
  int _reloadGen = 0;
  Timer? _refreshDebounce;
  Timer? _backgroundRetry;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onManager);
    _language.addListener(_onLanguageChanged);
    if (!_m.isLoading) {
      _showCachedTables();
    } else {
      _m.addListener(_onInitReady);
    }
    _refreshTablesFromDb();
  }

  void _onInitReady() {
    if (_m.isLoading) return;
    _m.removeListener(_onInitReady);
    _showCachedTables();
    _refreshTablesFromDb();
  }

  void _showCachedTables() {
    if (!mounted) return;
    setState(() {
      _tables = _m.cachedTablesForWaiter(widget.waiterName);
      _loadingTables = _tables.isEmpty;
    });
  }

  void _onManager() {
    if (_m.isLoading) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refreshTablesLight();
    });
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshTablesLight() async {
    final gen = ++_reloadGen;
    try {
      final tables = await _m.tablesForWaiter(
        widget.waiterName,
        ensureLoaded: false,
      );
      if (!mounted || gen != _reloadGen) return;
      setState(() {
        _tables = tables;
        _loadingTables = false;
      });
      _backgroundRetry?.cancel();
      _backgroundRetry = null;
    } catch (e, st) {
      debugPrint('TableSelectionScreen._refreshTablesLight: $e\n$st');
      _scheduleBackgroundRetry();
    }
  }

  Future<void> _refreshTablesFromDb() async {
    if (!mounted) return;
    final gen = ++_reloadGen;
    if (_tables.isEmpty) {
      setState(() => _loadingTables = true);
    }

    while (_m.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted || gen != _reloadGen) return;
    }

    try {
      if (_m.cashierTables.isEmpty) {
        await _m.ensureTablesLoaded();
      }
      final tables = await _m.tablesForWaiter(
        widget.waiterName,
        ensureLoaded: false,
      );
      if (!mounted || gen != _reloadGen) return;
      setState(() {
        _tables = tables;
        _loadingTables = false;
      });
      _backgroundRetry?.cancel();
      _backgroundRetry = null;
    } catch (e, st) {
      debugPrint('TableSelectionScreen._refreshTablesFromDb: $e\n$st');
      if (!mounted || gen != _reloadGen) return;
      if (_tables.isEmpty) {
        setState(() {
          _tables = _m.cachedTablesForWaiter(widget.waiterName);
          _loadingTables = false;
        });
      }
      _scheduleBackgroundRetry();
    }
  }

  void _scheduleBackgroundRetry() {
    _backgroundRetry ??= Timer(const Duration(seconds: 2), () {
      _backgroundRetry = null;
      if (mounted) _refreshTablesLight();
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _backgroundRetry?.cancel();
    _language.removeListener(_onLanguageChanged);
    _m.removeListener(_onInitReady);
    _m.removeListener(_onManager);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loadingTables) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Column(
          children: [
            GgAppHeader(
              showBack: true,
              title: 'Tavolinat',
              userName: widget.waiterName,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            ),
          ],
        ),
      );
    }

    final tables = _tables;
    final occupied = tables.where((t) => t.occupied).length;
    final total = tables.fold<double>(0, (s, t) => s + (t.currentTotal ?? 0));

    return Scaffold(
      backgroundColor: scheme.surface,
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
                        final itemCount = tables.length + 1;
                        final columns = PosGrid.resolveCrossAxisCount(
                          itemCount: itemCount,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        );

                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: PosGrid.tableDelegateFor(columns),
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
                    Text(
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
                        style: TextStyle(
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
        style: TextStyle(fontSize: 14, color: AppColors.primaryGreen),
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
              child: Icon(
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
                            style: TextStyle(
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
                      Text(
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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                    ] else
                      Text(
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

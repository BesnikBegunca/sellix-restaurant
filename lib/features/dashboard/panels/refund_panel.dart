import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../models/pos_models.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../theme/app_colors.dart';
import '../../sales_history/models/sales_models.dart';
import '../../sales_history/widgets/sale_card.dart';
import '../widgets/stat_card.dart';

/// Çdo shtypje **PRINTO** = një rresht i veçantë (jo totali i bashkuar i tavolinës).
class RefundPanel extends StatefulWidget {
  const RefundPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<RefundPanel> createState() => _RefundPanelState();
}

class _RefundPanelState extends State<RefundPanel> {
  String? _selectedWaiter;
  final Set<int> _expandedPrintIds = {};
  bool _loading = false;
  List<SaleWithLines> _orders = [];

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onDataChanged);
    if (widget.m.waiters.isNotEmpty) {
      _selectedWaiter = widget.m.waiters.first.name;
    }
    _loadOrders();
  }

  @override
  void dispose() {
    widget.m.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    final waiters = widget.m.waiters;
    if (waiters.isEmpty) {
      setState(() {
        _selectedWaiter = null;
        _orders = [];
      });
      return;
    }
    if (_selectedWaiter == null ||
        !waiters.any((w) => w.name == _selectedWaiter)) {
      _selectedWaiter = waiters.first.name;
    }
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final waiter = _selectedWaiter;
    if (waiter == null) {
      setState(() => _orders = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final prints = await DatabaseService.instance.fetchKitchenPrintsForWaiter(
        waiter,
        shiftId: widget.m.currentShiftId,
      );

      final orders = <SaleWithLines>[];
      for (final meta in prints) {
        final printId = (meta['id'] as num).toInt();
        final orderNumber = (meta['orderNumber'] as num).toInt();
        final tableId = (meta['tableId'] as num).toInt();
        final total = (meta['total'] as num).toDouble();
        final printedAt =
            DateTime.tryParse(meta['printedAt'] as String? ?? '') ??
            DateTime.now();

        final rawLines = await DatabaseService.instance.fetchKitchenPrintLines(
          printId,
        );
        if (rawLines.isEmpty) continue;

        final lineRows = rawLines.map((r) {
          return SaleLineRow(
            saleId: printId,
            productId: r['productId'] as String,
            productName: r['productName'] as String,
            productEmoji: r['productEmoji'] as String? ?? '☕',
            productImagePath: r['imagePath'] as String?,
            productPrice: (r['productPrice'] as num).toDouble(),
            quantity: (r['qty'] as num).toInt(),
            lineTotal: (r['lineTotal'] as num).toDouble(),
            waiterName: waiter,
            createdAt: printedAt,
          );
        }).toList();

        orders.add(
          SaleWithLines(
            sale: SaleRow(
              dbId: orderNumber,
              waiterName: waiter,
              tableId: tableId,
              total: total,
              timestamp: printedAt,
              shiftId: meta['shiftId'] as int?,
            ),
            lines: lineRows,
            kitchenPrintId: printId,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
          _expandedPrintIds.removeWhere(
            (id) => !orders.any((o) => o.kitchenPrintId == id),
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _printsTotal =>
      _orders.fold<double>(0, (s, o) => s + o.sale.total);

  Future<void> _confirmDelete(SaleWithLines order) async {
    final printId = order.kitchenPrintId;
    if (printId == null) return;
    final orderNo = order.sale.dbId ?? 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fshi këtë printim?'),
        content: SizedBox(
          width: 400,
          child: Text(
            'Order #${orderNo.toString().padLeft(3, '0')} · '
            'Tavolina ${order.sale.tableId} · '
            '${order.sale.total.toStringAsFixed(2)}€\n\n'
            'Fshihet vetëm ky PRINTO (${order.sale.total.toStringAsFixed(2)}€), '
            'jo printimet e tjera të së njëjtës tavolinë.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negativeText,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await widget.m.voidKitchenPrint(printId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Printimi ${order.sale.total.toStringAsFixed(2)}€ u fshi.',
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fshirja dështoi: $e'),
            backgroundColor: AppColors.negativeText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waiters = widget.m.waiters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Refund — Porositë e Printuara'),
        const SizedBox(height: 6),
        Text(
          'Çdo shtypje PRINTO shfaqet veçmas (p.sh. 3€, pastaj 4€, pastaj 5€). '
          'Fshirja heq vetëm atë printim nga tavolina, jo të gjitha së bashku.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.print_outlined,
                  title: 'Printime (turni aktual)',
                  value: '${_orders.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.euro_outlined,
                  title: 'Shuma e printimeve',
                  value: '${_printsTotal.toStringAsFixed(2)}€',
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 22,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 12),
              Text(
                'Kamarieri',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: waiters.isEmpty
                    ? Text(
                        'Nuk ka kamarierë të regjistruar.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.lightGreenText,
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              _selectedWaiter != null &&
                                  waiters.any((w) => w.name == _selectedWaiter)
                              ? _selectedWaiter
                              : null,
                          isExpanded: true,
                          hint: const Text('Zgjidh kamarierin'),
                          borderRadius: BorderRadius.circular(12),
                          items: waiters
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.name,
                                  child: Text(w.name),
                                ),
                              )
                              .toList(),
                          onChanged: waiters.isEmpty
                              ? null
                              : (v) {
                                  setState(() => _selectedWaiter = v);
                                  _loadOrders();
                                },
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _selectedWaiter == null
                    ? 'Printimet'
                    : 'PRINTO — $_selectedWaiter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedWaiter == null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Zgjidh një kamarier.',
                      style: TextStyle(color: AppColors.lightGreenText),
                    ),
                  ),
                )
              else if (_orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Nuk ka printime për $_selectedWaiter në këtë turn.\n'
                      'Çdo shtypje PRINTO krijon një rresht të ri këtu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.lightGreenText),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final order = _orders[i];
                    final printId = order.kitchenPrintId!;
                    final orderNo = order.sale.dbId ?? 0;
                    final expanded = _expandedPrintIds.contains(printId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warmGold.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Order #${orderNo.toString().padLeft(3, '0')} · '
                                  '${order.sale.total.toStringAsFixed(2)}€ · T${order.sale.tableId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warmGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SaleCard(
                          data: order,
                          expanded: expanded,
                          onToggle: () {
                            setState(() {
                              if (expanded) {
                                _expandedPrintIds.remove(printId);
                              } else {
                                _expandedPrintIds.add(printId);
                              }
                            });
                          },
                          onDelete: () => _confirmDelete(order),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

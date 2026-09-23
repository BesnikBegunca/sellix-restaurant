import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../models/pos_models.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../../../theme/app_colors.dart';
import '../../sales_history/models/sales_models.dart';
import '../../sales_history/widgets/sale_card.dart';
import '../widgets/stat_card.dart';
import '../../../l10n/tr.dart';

/// Të gjitha porositë e turnit: PRINTO dhe PAGUAJ direkte (jo vetëm tavolina e hapur).
class RefundPanel extends StatefulWidget {
  const RefundPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<RefundPanel> createState() => _RefundPanelState();
}

class _RefundPanelState extends State<RefundPanel> {
  String? _selectedWaiter;
  final Set<String> _expandedKeys = {};
  bool _loading = false;
  List<SaleWithLines> _orders = [];

  String _rowKey(SaleWithLines order) {
    final printId = order.kitchenPrintId;
    if (printId != null) return 'p:$printId';
    return 's:${order.sale.dbId ?? 0}';
  }

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

      final coveredSaleUids = <String>{};
      final orders = <SaleWithLines>[];
      for (final meta in prints) {
        final printId = (meta['id'] as num).toInt();
        final orderNumber = (meta['orderNumber'] as num).toInt();
        final tableId = (meta['tableId'] as num).toInt();
        final total = (meta['total'] as num).toDouble();
        final printedAt =
            DateTime.tryParse(meta['printedAt'] as String? ?? '') ??
            DateTime.now();
        final portalUid = (meta['portalSaleUid'] as String?)?.trim();
        final printUuid = (meta['uuid'] as String?)?.trim();
        if (portalUid != null && portalUid.isNotEmpty) {
          coveredSaleUids.add(portalUid);
        }
        if (printUuid != null && printUuid.isNotEmpty) {
          coveredSaleUids.add(printUuid);
        }

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

      // PAGUAJ direkte pa rresht PRINTO — shtohet si porosi e veçantë.
      final allSales = await DatabaseService.instance.fetchSales();
      final shiftId = widget.m.currentShiftId;
      final extraSales = <Map<String, dynamic>>[];
      for (final row in allSales) {
        final name = (row['waiterName'] as String?)?.trim() ?? '';
        if (name != waiter) continue;
        if (shiftId != null && (row['shiftId'] as num?)?.toInt() != shiftId) {
          continue;
        }
        final uuid = (row['uuid'] as String?)?.trim() ?? '';
        if (uuid.isNotEmpty && coveredSaleUids.contains(uuid)) continue;
        extraSales.add(row);
      }

      if (extraSales.isNotEmpty) {
        final extraIds = extraSales
            .map((row) => (row['id'] as num?)?.toInt())
            .whereType<int>()
            .toList();
        final rawExtraLines = extraIds.isEmpty
            ? const <Map<String, dynamic>>[]
            : await DatabaseService.instance.fetchSaleLinesForSales(extraIds);
        final linesBySale = <int, List<SaleLineRow>>{};
        for (final row in rawExtraLines) {
          final line = SaleLineRow.fromMap(row);
          (linesBySale[line.saleId] ??= []).add(line);
        }
        for (final row in extraSales) {
          final sale = SaleRow.fromMap(row);
          final saleId = sale.dbId;
          if (saleId == null) continue;
          orders.add(
            SaleWithLines(
              sale: sale,
              lines: linesBySale[saleId] ?? const [],
            ),
          );
        }
      }

      orders.sort((a, b) => b.sale.timestamp.compareTo(a.sale.timestamp));

      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
          _expandedKeys.removeWhere(
            (key) => !orders.any((o) => _rowKey(o) == key),
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
    final saleId = order.sale.dbId;
    if (printId == null && saleId == null) return;
    final orderNo = order.sale.orderNumber ?? order.sale.dbId ?? 0;
    final isPrint = printId != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPrint ? tr.fshiKetePrintim : tr.fshiPorosine),
        content: SizedBox(
          width: 400,
          child: Text(
            'Order #${orderNo.toString().padLeft(3, '0')} · '
            'Tavolina ${order.sale.tableId} · '
            '${order.sale.total.toStringAsFixed(2)}€\n\n' +
            (isPrint
                ? trf.deleteOnlyThisPrint(order.sale.total.toStringAsFixed(2)) +
                    tr.deleteOnlyThisPrintExplainer
                : 'Fshihet kjo pagesë direkte PAGUAJ nga refund-i dhe totali.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.anulo),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negativeText,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr.fshi),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      if (printId != null) {
        await widget.m.voidKitchenPrint(printId);
      } else if (saleId != null) {
        await widget.m.voidSale(saleId: saleId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPrint
                  ? 'Printimi ${order.sale.total.toStringAsFixed(2)}€ u fshi.'
                  : 'Pagesa ${order.sale.total.toStringAsFixed(2)}€ u fshi.',
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
            content: Text(trf.deleteFailed(e)),
            backgroundColor: AppColors.negativeText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiters = widget.m.waiters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.undo_outlined,
          title: tr.refundPorositePrintuara,
          subtitle:
              'PRINTO dhe PAGUAJ direkte. Çdo porosi e turnit shfaqet këtu.',
        ),
        PanelStatRow(
          cards: [
            StatCard(
              icon: Icons.print_outlined,
              title: tr.printimeTurniAktual,
              value: '${_orders.length}',
            ),
            StatCard(
              icon: Icons.euro_outlined,
              title: tr.shumaPrintimeve,
              value: '${_printsTotal.toStringAsFixed(2)}€',
              accentColor: AppColors.warmGold,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PanelCard(
          icon: Icons.person_outline,
          title: 'Kamarieri',
          subtitle: 'Filtro porositë e turnit aktual.',
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: waiters.isEmpty
              ? Text(
                  tr.nukKaKamariereRegjistruar,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.lightGreenText,
                  ),
                )
              : DropdownButtonFormField<String>(
                  key: ValueKey(_selectedWaiter),
                  initialValue:
                      _selectedWaiter != null &&
                          waiters.any((w) => w.name == _selectedWaiter)
                      ? _selectedWaiter
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'Zgjidh kamarierin',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: AppColors.primaryGreen,
                    ),
                  ),
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
        const SizedBox(height: 20),
        PanelCard(
          icon: Icons.print_outlined,
          title: _selectedWaiter == null
              ? 'Porositë'
              : 'Porositë — $_selectedWaiter',
          subtitle: 'PRINTO dhe PAGUAJ direkte, edhe pasi tavolina lirohet.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      tr.zgjidhKamarier,
                      style: TextStyle(color: AppColors.lightGreenText),
                    ),
                  ),
                )
              else if (_orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Nuk ka porosi për ${_selectedWaiter ?? ''} në këtë turn.',
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
                    final key = _rowKey(order);
                    final orderNo =
                        order.sale.orderNumber ?? order.sale.dbId ?? 0;
                    final expanded = _expandedKeys.contains(key);
                    final isDirectPay = order.kitchenPrintId == null;
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
                                  '${isDirectPay ? 'PAGUAJ' : 'PRINTO'} · '
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
                                _expandedKeys.remove(key);
                              } else {
                                _expandedKeys.add(key);
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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/pos_order/widgets/cart_line.dart';
import '../features/pos_order/widgets/category_tile.dart';
import '../features/pos_order/widgets/order_panel.dart';
import '../features/pos_order/widgets/product_tile.dart';
import '../manager/manager_data.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/pos_grid.dart';
import '../widgets/gg_header.dart';
import '../services/escpos/escpos_printer_service.dart';
import '../services/printer_settings_store.dart';
import '../services/receipt_printer.dart';
import '../services/receipt_text.dart';

class PosOrderScreen extends StatefulWidget {
  const PosOrderScreen({
    super.key,
    required this.tableNumber,
    required this.orderNumber,
    required this.waiterName,
  });

  final int tableNumber;
  final int orderNumber;
  final String waiterName;

  @override
  State<PosOrderScreen> createState() => _PosOrderScreenState();
}
class _PosOrderScreenState extends State<PosOrderScreen> {
  int _categoryIndex = 0;
  late int _activeOrderNumber;
  final List<CartLine> _lines = [];
  bool _hydrated = false;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _activeOrderNumber = widget.orderNumber;
    ManagerData.instance.addListener(_onMenuChanged);
    _loadPersistedOrder();
  }

  void _onMenuChanged() {
    final cats = ManagerData.instance.categories;
    if (cats.isNotEmpty && _categoryIndex >= cats.length) {
      setState(() => _categoryIndex = cats.length - 1);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onMenuChanged);
    super.dispose();
  }

  double get _total => _lines.fold(0, (s, l) => s + l.product.price * l.qty);

  Future<void> _loadPersistedOrder() async {
    if (!mounted) return;
    setState(() {
      // Current order UI must always start empty (no autofill).
      _lines.clear();
      _hydrated = true;
    });
  }

  List<CurrentOrderLine> _toCurrentLines(List<CartLine> lines) {
    return lines
        .map((l) => CurrentOrderLine(product: l.product, qty: l.qty))
        .toList();
  }

  List<CurrentOrderLine> _mergeLines(
    List<CurrentOrderLine> base,
    List<CurrentOrderLine> add,
  ) {
    final map = <String, CurrentOrderLine>{};
    for (final l in base) {
      map[l.product.id] = CurrentOrderLine(product: l.product, qty: l.qty);
    }
    for (final l in add) {
      final existing = map[l.product.id];
      if (existing == null) {
        map[l.product.id] = CurrentOrderLine(product: l.product, qty: l.qty);
      } else {
        map[l.product.id] = CurrentOrderLine(
          product: existing.product,
          qty: existing.qty + l.qty,
        );
      }
    }
    return map.values.toList();
  }

  double _sumCurrentLines(List<CurrentOrderLine> lines) {
    return lines.fold<double>(0, (s, l) => s + (l.product.price * l.qty));
  }

  void _addProduct(ProductItem p) {
    setState(() {
      final i = _lines.indexWhere((l) => l.product.id == p.id);
      if (i >= 0) {
        _lines[i].qty++;
      } else {
        _lines.add(CartLine(product: p));
      }
    });
  }

  void _deltaQty(ProductItem p, int delta) {
    setState(() {
      final i = _lines.indexWhere((l) => l.product.id == p.id);
      if (i < 0) return;
      _lines[i].qty += delta;
      if (_lines[i].qty <= 0) _lines.removeAt(i);
    });
  }

  Future<void> _payTable() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);

    try {
      final data = ManagerData.instance;
      final persisted = await data.loadCurrentOrderLines(
        widget.tableNumber,
        widget.waiterName,
      );
      final combined = _mergeLines(persisted, _toCurrentLines(_lines));
      final tableTotal = _sumCurrentLines(combined);

      // Print payment receipt (non-fatal if printer is unavailable).
      try {
        if (combined.isNotEmpty) {
          await ReceiptPrinter.printKitchenOrder(
            companyName: data.companyName ?? 'POS System',
            waiterName: widget.waiterName,
            tableNumber: widget.tableNumber,
            orderNumber: _activeOrderNumber,
            lines: combined
                .map((l) => ReceiptLine(product: l.product, qty: l.qty))
                .toList(),
            total: tableTotal,
            paymentReceipt: true,
          );
          // Auto-kick cash drawer if enabled.
          if (data.cashDrawerEnabled) {
            final printer = await PrinterSettingsStore.loadSelectedPrinterName();
            if (printer.isNotEmpty) {
              EscPosPrinterService.instance.openCashDrawer(printer);
            }
          }
        }
      } catch (_) {}

      // Regjistro shitjen me linjat e produkteve në një transaksion atomik.
      if (tableTotal > 0 && widget.waiterName.isNotEmpty) {
        await data.recordSaleWithLines(
          waiterName: widget.waiterName,
          total: tableTotal,
          tableId: widget.tableNumber,
          tableName: 'Tavolina ${widget.tableNumber}',
          lines: combined,
        );
      }

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, anim, sec) {
          final nav = Navigator.of(ctx);
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (nav.canPop()) nav.pop();
          });
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.lightGreenBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.primaryGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pagesa u krye!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tavolina ${widget.tableNumber} u lirua',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                    if (tableTotal > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${tableTotal.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim, sec, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
      await data.clearTable(widget.tableNumber, widget.waiterName);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pagesa dështoi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _sendOrder() async {
    if (_lines.isEmpty) return;
    if (_activeOrderNumber == 0) {
      _activeOrderNumber = await ManagerData.instance.nextGlobalOrderNumber();
    }
    final persisted = await ManagerData.instance.loadCurrentOrderLines(
      widget.tableNumber,
      widget.waiterName,
    );
    final merged = _mergeLines(persisted, _toCurrentLines(_lines));
    final mergedTotal = _sumCurrentLines(merged);

    ManagerData.instance.updateTableTotal(
      widget.tableNumber,
      mergedTotal,
      widget.waiterName,
    );
    await ManagerData.instance.saveCurrentOrder(
      tableId: widget.tableNumber,
      orderNumber: _activeOrderNumber,
      waiterName: widget.waiterName,
      lines: merged,
    );

    // Historik: çdo shtypje Printo = një batch i veçantë (p.sh. 3€, 4€, 5€).
    await ManagerData.instance.recordKitchenPrint(
      tableId: widget.tableNumber,
      waiterName: widget.waiterName,
      orderNumber: _activeOrderNumber,
      lines: _toCurrentLines(_lines),
    );

    // Printo kuponin termik / POS80 (tekst i formatum per POS80).
    try {
      await ReceiptPrinter.printKitchenOrder(
        companyName: ManagerData.instance.companyName ?? 'POS System',
        waiterName: widget.waiterName,
        tableNumber: widget.tableNumber,
        orderNumber: _activeOrderNumber,
        lines: _lines
            .map((l) => ReceiptLine(product: l.product, qty: l.qty))
            .toList(),
        total: _total,
      );
    } catch (_) {
      // mos e prish flow-in nese printeri dështon (p.sh. pa driver).
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, sec) {
        final nav = Navigator.of(ctx);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (nav.canPop()) nav.pop();
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.lightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.primaryGreen,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Order Sent!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #$_activeOrderNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ManagerData.instance,
      builder: (context, _) {
        final cats = ManagerData.instance.categories;
        if (cats.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.beige,
            body: Column(
              children: [
                GgAppHeader(
                  showBack: true,
                  showLogo: false,
                  title: 'Porosia',
                  userName: widget.waiterName,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Nuk ka kategori në menu.\nMenaxheri duhet të shtojë kategori.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mediumGreenText),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final ix = _categoryIndex.clamp(0, cats.length - 1);
        final products = cats[ix].products;

        return Scaffold(
          backgroundColor: AppColors.beige,
          body: Column(
            children: [
              GgAppHeader(
                showBack: true,
                showLogo: false,
                title: 'Porosia',
                userName: widget.waiterName,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cellW = PosGrid.cellWidth(
                              constraints.maxWidth,
                            );
                            final cellH = PosGrid.cellHeight(
                              constraints.maxWidth,
                            );
                            final categoryWidth = math.min(
                              cellW,
                              (constraints.maxWidth -
                                      (cats.length - 1) * PosGrid.spacing) /
                                  cats.length,
                            );
                            final categoryHeight =
                                categoryWidth / PosGrid.childAspectRatio;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _categoryRow(
                                  cats,
                                  categoryWidth,
                                  categoryHeight,
                                  ix,
                                ),
                                const SizedBox(height: PosGrid.spacing),
                                Expanded(
                                  child: GridView.builder(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    gridDelegate: PosGrid.delegate,
                                    itemCount: products.length,
                                    itemBuilder: (context, i) {
                                      return ProductTile(
                                        product: products[i],
                                        onAdd: () => _addProduct(products[i]),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 380,
                        child: OrderPanel(
                          tableNumber: widget.tableNumber,
                          orderNumber: _activeOrderNumber,
                          lines: _lines,
                          total: _total,
                          onDelta: _deltaQty,
                          onSend: _sendOrder,
                          onPay: _payTable,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryRow(
    List<CategoryData> cats,
    double cellW,
    double cellH,
    int selectedIndex,
  ) {
    return SizedBox(
      height: cellH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cats.length; i++) ...[
            if (i > 0) const SizedBox(width: PosGrid.spacing),
            SizedBox(
              width: cellW,
              child: CategoryTile(
                data: cats[i],
                active: i == selectedIndex,
                onTap: () => setState(() => _categoryIndex = i),
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

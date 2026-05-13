import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';
import '../utils/image_utils.dart';
import '../theme/pos_grid.dart';
import '../widgets/gg_header.dart';
import '../widgets/hover_interaction.dart';
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

class _CartLine {
  _CartLine({required this.product});

  final ProductItem product;
  int qty = 1;
}

class _PosOrderScreenState extends State<PosOrderScreen> {
  int _categoryIndex = 0;
  late int _activeOrderNumber;
  final List<_CartLine> _lines = [];
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

  List<CurrentOrderLine> _toCurrentLines(List<_CartLine> lines) {
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
        _lines.add(_CartLine(product: p));
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
                        '\$${tableTotal.toStringAsFixed(2)}',
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
                                      return _ProductTile(
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
                        child: _OrderPanel(
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
              child: _CategoryTile(
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

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final CategoryData data;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return SizedBox.expand(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: a ? AppColors.lightGreenBg : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: a
                    ? AppColors.borderEmphasized(0.3)
                    : AppColors.borderSubtle(_hover ? 0.2 : 0.1),
              ),
              boxShadow: a
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: a
                              ? AppColors.darkGreenText
                              : AppColors.mediumGreenText,
                        ),
                      ),
                    ),
                    Icon(
                      widget.data.icon,
                      size: 20,
                      color: a
                          ? AppColors.primaryGreen
                          : AppColors.lightGreenText,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.data.products.length} items',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatefulWidget {
  const _ProductTile({required this.product, required this.onAdd});

  final ProductItem product;
  final VoidCallback onAdd;

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onAdd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderSubtle(_hover ? 0.3 : 0.1),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: widget.product.imagePath != null
                      ? productImage(
                          widget.product.imagePath,
                          fit: BoxFit.contain,
                        )
                      : FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            widget.product.emoji,
                            style: const TextStyle(fontSize: 96),
                          ),
                        ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${widget.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.lightGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HoverScaleButton(
                    onPressed: widget.onAdd,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: _AddCircle(hover: _hover),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCircle extends StatefulWidget {
  const _AddCircle({required this.hover});

  final bool hover;

  @override
  State<_AddCircle> createState() => _AddCircleState();
}

class _AddCircleState extends State<_AddCircle> {
  bool _innerHover = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.hover || _innerHover;
    return MouseRegion(
      onEnter: (_) => setState(() => _innerHover = true),
      onExit: (_) => setState(() => _innerHover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: h ? AppColors.darkerGreenHover : AppColors.primaryGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.white, size: 20),
      ),
    );
  }
}

class _OrderPanel extends StatelessWidget {
  const _OrderPanel({
    required this.tableNumber,
    required this.orderNumber,
    required this.lines,
    required this.total,
    required this.onDelta,
    required this.onSend,
    required this.onPay,
  });

  final int tableNumber;
  final int orderNumber;
  final List<_CartLine> lines;
  final double total;
  final void Function(ProductItem p, int delta) onDelta;
  final VoidCallback onSend;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final empty = lines.isEmpty;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Porosia aktuale',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '#${orderNumber.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.lightGreenText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.table_restaurant_outlined,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tavolina $tableNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: empty
                ? const Center(
                    child: Text(
                      'Ende pa artikuj',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final l = lines[i];
                      return _OrderLineRow(
                        line: l,
                        onMinus: () => onDelta(l.product, -1),
                        onPlus: () => onDelta(l.product, 1),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle(0.1)),
              ),
            ),
            child: _moneyRow('Totali', total, large: true),
          ),
          const SizedBox(height: 24),
          _SendOrderButton(enabled: !empty, onSend: onSend),
          const SizedBox(height: 10),
          _PayButton(onPay: onPay),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount, {required bool large}) {
    final style = TextStyle(
      fontSize: large ? 24 : 16,
      fontWeight: large ? FontWeight.w500 : FontWeight.w400,
      color: large ? AppColors.darkGreenText : AppColors.mediumGreenText,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text('\$${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({
    required this.line,
    required this.onMinus,
    required this.onPlus,
  });

  final _CartLine line;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: line.product.imagePath != null
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: productImage(
                      line.product.imagePath,
                      fit: BoxFit.contain,
                    ),
                  )
                : Text(
                    line.product.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreenText,
                  ),
                ),
                Text(
                  '\$${line.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _QtyButton(label: '−', onPressed: onMinus),
              SizedBox(
                width: 24,
                child: Text(
                  '${line.qty}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ),
              _QtyButton(label: '+', onPressed: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatefulWidget {
  const _QtyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_QtyButton> createState() => _QtyButtonState();
}

class _QtyButtonState extends State<_QtyButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? AppColors.lightGreenBg : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderVisible(0.2)),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 20,
              color: AppColors.primaryGreen,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendOrderButton extends StatefulWidget {
  const _SendOrderButton({required this.enabled, required this.onSend});

  final bool enabled;
  final VoidCallback onSend;

  @override
  State<_SendOrderButton> createState() => _SendOrderButtonState();
}

class _SendOrderButtonState extends State<_SendOrderButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = !widget.enabled
        ? AppColors.lightGreenText
        : (_hover ? AppColors.darkerGreenHover : AppColors.primaryGreen);
    final scale = widget.enabled
        ? (_pressed ? 0.95 : (_hover ? 1.05 : 1.0))
        : 1.0;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.enabled ? widget.onSend : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PRINTO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatefulWidget {
  const _PayButton({required this.onPay});

  final VoidCallback onPay;

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPay,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hover ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? AppColors.lightGreenBg : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hover
                    ? AppColors.primaryGreen
                    : AppColors.borderVisible(0.25),
                width: _hover ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: _hover
                      ? AppColors.primaryGreen
                      : AppColors.mediumGreenText,
                ),
                const SizedBox(width: 8),
                Text(
                  'PAGUAJ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: _hover
                        ? AppColors.primaryGreen
                        : AppColors.mediumGreenText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

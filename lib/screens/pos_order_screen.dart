import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/pos_order/pay_print_total_rule.dart';
import '../features/pos_order/widgets/cart_line.dart';
import '../features/pos_order/widgets/category_tile.dart';
import '../features/pos_order/widgets/order_panel.dart';
import '../features/pos_order/widgets/product_tile.dart';
import '../manager/manager_data.dart';
import '../models/mock_data.dart';
import '../models/sale_insert_result.dart';
import '../services/audit_log_service.dart';
import '../theme/app_colors.dart';
import '../theme/pos_grid.dart';
import '../widgets/gg_header.dart';
import '../services/escpos/escpos_printer_service.dart';
import '../services/printer_settings_store.dart';
import '../services/receipt_printer.dart';
import '../services/receipt_text.dart';
import '../services/app_language_service.dart';
import '../services/portal_sales_sync_service.dart';
import '../services/waiter_always_open.dart';
import '../l10n/tr.dart';

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
  final _language = AppLanguageService.instance;
  int _categoryIndex = 0;
  late int _activeOrderNumber;
  final List<CartLine> _lines = [];
  bool _hydrated = false;
  bool _isPaying = false;
  bool _isSendingOrder = false;

  @override
  void initState() {
    super.initState();
    _activeOrderNumber = widget.orderNumber;
    ManagerData.instance.addListener(_onMenuChanged);
    _language.addListener(_onLanguageChanged);
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

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onMenuChanged);
    _language.removeListener(_onLanguageChanged);
    super.dispose();
  }

  /// Pas PRINTO / pagesës: "Always open" → te tavolinat; përndryshe → login.
  void _returnAfterFinish() {
    final nav = Navigator.of(context);
    if (WaiterAlwaysOpen.instance.isEnabled(widget.waiterName)) {
      nav.pop();
    } else {
      nav.popUntil((route) => route.isFirst);
    }
  }

  double get _total => _lines.fold(0, (s, l) => s + l.product.price * l.qty);

  TableInfo? get _tableInfo {
    for (final t in ManagerData.instance.cashierTables) {
      if (t.id == widget.tableNumber) return t;
    }
    return null;
  }

  /// Paguaj: tavolinë e zënë (pas PRINTO) ose artikuj të rinj në listë.
  bool get _canPay {
    final table = _tableInfo;
    return (table?.occupied ?? false) || _lines.isNotEmpty;
  }

  double get _displayTotal {
    if (_lines.isNotEmpty) return _total;
    return _tableInfo?.currentTotal ?? 0;
  }

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
    if (!_canPay || _isSendingOrder) return;
    if (_isPaying) {
      AuditLogService.instance.logDuplicatePaymentBlocked(
        tableId: widget.tableNumber,
      );
      return;
    }
    setState(() => _isPaying = true);

    try {
      final data = ManagerData.instance;
      final persisted = await data.loadCurrentOrderLines(
        widget.tableNumber,
        widget.waiterName,
      );
      final combined = _mergeLines(persisted, _toCurrentLines(_lines));
      final tableTotal = _sumCurrentLines(combined);
      final shouldRecordSale = tableTotal > 0 && widget.waiterName.isNotEmpty;

      // TEMP [SyncDiag] — log payment totals to verify total vs lineTotal sum.
      // ignore: avoid_print
      print(
        '[SyncDiag] _payTable tableId=${widget.tableNumber} '
        'waiter=${widget.waiterName} items=${combined.length} '
        'tableTotal=$tableTotal',
      );
      if (shouldRecordSale) {
        final sumRounded = combined.fold<double>(0, (s, l) {
          return s + double.parse((l.product.price * l.qty).toStringAsFixed(2));
        });
        final delta = (tableTotal - sumRounded).abs();
        // ignore: avoid_print
        print(
          '[SyncDiag] totalVsLineTotals tableTotal=$tableTotal '
          'sumRoundedLineTotals=$sumRounded delta=${delta.toStringAsFixed(6)} '
          'wouldFailValidation=${delta > 0.02}',
        );
      }

      // 1) Save sale first (DB idempotency on stable sale UUID).
      var printAfterSave = false;
      SaleInsertResult? payResult;
      if (shouldRecordSale) {
        final saleUuid = await data.resolvePaymentSaleUuid(
          tableId: widget.tableNumber,
          waiterName: widget.waiterName,
        );
        // ignore: avoid_print
        print('[SyncDiag] resolvedSaleUuid=$saleUuid');

        // Porosi e re + PAGUAJ → total. Tavolinë e hapur (e printuar) → jo.
        if (shouldAddPaymentToPrintTotal(
          tableOccupied: _tableInfo?.occupied ?? false,
          hasPrintedOrderLines: persisted.isNotEmpty,
          hasUnprintedCartLines: _lines.isNotEmpty,
        )) {
          final printOrderNumber = await data.nextWaiterOrderNumber(
            widget.waiterName,
          );
          _activeOrderNumber = printOrderNumber;
          await data.recordKitchenPrint(
            tableId: widget.tableNumber,
            waiterName: widget.waiterName,
            orderNumber: printOrderNumber,
            lines: _toCurrentLines(_lines),
          );
        }

        payResult = await data.recordSaleWithLines(
          saleUuid: saleUuid,
          waiterName: widget.waiterName,
          total: tableTotal,
          tableId: widget.tableNumber,
          tableName: 'Tavolina ${widget.tableNumber}',
          lines: combined,
          orderNumber: _activeOrderNumber > 0 ? _activeOrderNumber : null,
        );
        unawaited(PortalSalesSyncService.instance.triggerNow());
        // ignore: avoid_print
        print(
          '[SyncDiag] recordSaleWithLines saleId=${payResult.saleId} '
          'wasExisting=${payResult.wasExisting}',
        );
        printAfterSave = combined.isNotEmpty && !payResult.wasExisting;
      }

      // 2) Print receipt after commit (sale valid even if print fails).
      var printOk = true;
      if (printAfterSave) {
        try {
          printOk = await ReceiptPrinter.printKitchenOrder(
            companyName: data.companyName ?? tr.posSystem,
            waiterName: widget.waiterName,
            tableNumber: widget.tableNumber,
            orderNumber: _activeOrderNumber,
            lines: combined
                .map((l) => ReceiptLine(product: l.product, qty: l.qty))
                .toList(),
            total: tableTotal,
            paymentReceipt: true,
          );
          if (printOk && data.cashDrawerEnabled) {
            final printer =
                await PrinterSettingsStore.loadSelectedPrinterName();
            if (printer.isNotEmpty) {
              EscPosPrinterService.instance.openCashDrawer(printer);
            }
          }
        } catch (_) {
          printOk = false;
        }
      }

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
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
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        color: AppColors.primaryGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
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
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                    if (tableTotal > 0 &&
                        !data.hideWaiterTableTotals) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${tableTotal.toStringAsFixed(2)}€',
                        style: TextStyle(
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
      unawaited(PortalSalesSyncService.instance.triggerNow());
      if (mounted) {
        _returnAfterFinish();
        if (shouldRecordSale && !printOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr.shitjaURuajtPorPrintimiDeshtoi + tr.ridergojeniHistorikuShitjeve,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf.paymentFailed(e)),
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
    if (_lines.isEmpty || _isSendingOrder || _isPaying) return;
    _isSendingOrder = true;
    if (mounted) setState(() {});
    try {
      await _sendOrderImpl();
    } finally {
      _isSendingOrder = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _sendOrderImpl() async {
    // Çdo PRINTO: numër i ri për këtë kamarier (riniset nga 1 pas mbylljes së gjendjes).
    final printOrderNumber = await ManagerData.instance.nextWaiterOrderNumber(
      widget.waiterName,
    );
    setState(() => _activeOrderNumber = printOrderNumber);
    final persisted = await ManagerData.instance.loadCurrentOrderLines(
      widget.tableNumber,
      widget.waiterName,
    );
    final merged = _mergeLines(persisted, _toCurrentLines(_lines));
    final mergedTotal = _sumCurrentLines(merged);

    await ManagerData.instance.updateTableTotal(
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
    unawaited(PortalSalesSyncService.instance.triggerNow());

    // Printo kuponin termik / POS80 (tekst i formatum per POS80).
    try {
      await ReceiptPrinter.printKitchenOrder(
        companyName: ManagerData.instance.companyName ?? tr.posSystem,
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
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppColors.primaryGreen,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Porosia u Dergua!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Porosia #$_activeOrderNumber',
                    style: TextStyle(
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
      _returnAfterFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: ManagerData.instance,
      builder: (context, _) {
        final cats = ManagerData.instance.categories;
        if (cats.isEmpty) {
          return Scaffold(
            backgroundColor: scheme.surface,
            body: Column(
              children: [
                GgAppHeader(
                  showBack: true,
                  title: tr.porosia,
                  userName: widget.waiterName,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      tr.nukKaKategoriMenuNmenaxheriDuhet,
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
          backgroundColor: scheme.surface,
          body: Column(
            children: [
              GgAppHeader(
                showBack: true,
                title: tr.porosia,
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
                                  child: LayoutBuilder(
                                    builder: (context, gridConstraints) {
                                      final tileScale = ManagerData
                                          .instance
                                          .productTileScale;
                                      final columns =
                                          PosGrid.resolveProductCrossAxisCount(
                                            itemCount: products.length,
                                            width: gridConstraints.maxWidth,
                                            height: gridConstraints.maxHeight,
                                            nameScale: tileScale,
                                          );
                                      return GridView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        gridDelegate:
                                            PosGrid.productDelegateFor(
                                          columns,
                                          nameScale: tileScale,
                                        ),
                                        itemCount: products.length,
                                        itemBuilder: (context, i) {
                                          return ProductTile(
                                            product: products[i],
                                            onAdd: () =>
                                                _addProduct(products[i]),
                                          );
                                        },
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
                          total: _displayTotal,
                          canPay: _canPay,
                          onDelta: _deltaQty,
                          onSend: _sendOrder,
                          onPay: _payTable,
                          isPaying: _isPaying,
                          isSendingOrder: _isSendingOrder,
                          // Me totalet e fshehura, kamarieri sheh vetëm shumën
                          // e artikujve që po i shënon tani, jo totalin e tavolinës.
                          showTotal:
                              !ManagerData.instance.hideWaiterTableTotals ||
                              _lines.isNotEmpty,
                          totalLabel:
                              ManagerData.instance.hideWaiterTableTotals
                              ? 'Porosia aktuale'
                              : 'Totali',
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

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../features/sales_history/models/sales_models.dart';
import '../features/sales_history/widgets/sale_card.dart';
import '../features/sales_history/widgets/sh_kpi_row.dart';
import '../features/sales_history/widgets/sh_refund_dialog.dart';
import '../features/sales_history/widgets/sh_filters_card.dart';
import '../manager/manager_data.dart';
import '../services/database_service.dart';
import '../services/sale_receipt_service.dart';
import '../services/sales_history_pdf.dart';
import '../shared/widgets/panel_layout.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

// ─────────────────────────── main panel widget ───────────────────────────────

/// Full sales history panel. Designed to be embedded inside the manager
/// dashboard's section switcher — the outer [SingleChildScrollView] handles
/// scrolling, so this widget renders a plain [Column].
class SalesHistoryPanel extends StatefulWidget {
  const SalesHistoryPanel({super.key});

  @override
  State<SalesHistoryPanel> createState() => _SalesHistoryPanelState();
}

class _SalesHistoryPanelState extends State<SalesHistoryPanel> {
  // ── filters ────────────────────────────────────────────────────────────────
  SHDateFilter _dateFilter = SHDateFilter.allTime;
  DateTimeRange? _customRange;
  String? _selectedWaiter;
  int? _selectedTable;
  final _searchCtrl = TextEditingController();

  // ── data ───────────────────────────────────────────────────────────────────
  List<SaleWithLines> _sales = [];
  SalesAnalytics? _analytics;
  bool _loading = true;
  String? _error;

  // ── UI state ───────────────────────────────────────────────────────────────
  final Set<int> _expandedIds = {};
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onDataChanged);
    _loadData();
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() => _loadData();

  // ── date range helpers ─────────────────────────────────────────────────────

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange? get _effectiveRange {
    final now = DateTime.now();
    switch (_dateFilter) {
      case SHDateFilter.today:
        // «Sot» = gjendja e hapur (vazhdon pas 00:00 deri sa mbyllet).
        return null;
      case SHDateFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: _startOfDay(monday), end: _endOfDay(now));
      case SHDateFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _endOfDay(now),
        );
      case SHDateFilter.allTime:
        return null;
      case SHDateFilter.custom:
        return _customRange;
    }
  }

  String get _dateRangeLabel {
    switch (_dateFilter) {
      case SHDateFilter.today:
        return 'Sot';
      case SHDateFilter.thisWeek:
        return tr.kjoJave;
      case SHDateFilter.thisMonth:
        return 'Ky muaj';
      case SHDateFilter.allTime:
        return tr.gjitha;
      case SHDateFilter.custom:
        if (_customRange == null) return 'Personalizuar';
        final s = _customRange!.start;
        final e = _customRange!.end;
        return '${s.day}/${s.month}/${s.year} – ${e.day}/${e.month}/${e.year}';
    }
  }

  Future<void> _reprintSaleReceipt(SaleWithLines data) async {
    final ok = await SaleReceiptService.reprintPaymentReceipt(
      sale: data.sale,
      lines: data.lines,
      companyName: ManagerData.instance.companyName ?? tr.posSystem,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? tr.kuponiUDerguaPrinter
              : tr.printimiDeshtoiKontrolloniPrinterin,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final range = _effectiveRange;
      final searchText = _searchCtrl.text.trim();
      final searchId = searchText.isNotEmpty ? int.tryParse(searchText) : null;

      // Filter the in-memory sales history first (fast, no DB round-trip).
      final allSales = ManagerData.instance.salesHistory;
      final filtered = allSales.where((s) {
        if (_dateFilter == SHDateFilter.today) {
          if (!ManagerData.instance.isInOpenShift(
            at: s.timestamp,
            shiftId: s.shiftId,
          )) {
            return false;
          }
        } else if (range != null &&
            (s.timestamp.isBefore(range.start) ||
                s.timestamp.isAfter(range.end))) {
          return false;
        }
        if (_selectedWaiter != null && s.waiterName != _selectedWaiter) {
          return false;
        }
        if (_selectedTable != null && s.tableId != _selectedTable) {
          return false;
        }
        if (searchText.isNotEmpty) {
          // Search by exact sale ID number.
          if (searchId != null) {
            return s.dbId == searchId;
          }
          return false;
        }
        return true;
      }).toList();

      // Batch-fetch lines + adjustments for matched sales (two queries, no N+1).
      final saleIds =
          filtered.map((s) => s.dbId).whereType<int>().toList();
      final rawLines =
          await DatabaseService.instance.fetchSaleLinesForSales(saleIds);
      final rawAdj =
          await DatabaseService.instance.fetchAdjustmentsForSales(saleIds);

      // Group lines by saleId.
      final linesBySaleId = <int, List<SaleLineRow>>{};
      for (final m in rawLines) {
        final row = SaleLineRow.fromMap(m);
        linesBySaleId.putIfAbsent(row.saleId, () => []).add(row);
      }

      // Group adjustments by saleId.
      final adjBySaleId = <int, List<SaleAdjustmentRow>>{};
      for (final m in rawAdj) {
        final row = SaleAdjustmentRow.fromMap(m);
        adjBySaleId.putIfAbsent(row.saleId, () => []).add(row);
      }

      final salesWithLines = filtered
          .map(
            (s) => SaleWithLines(
              sale: s,
              lines: linesBySaleId[s.dbId] ?? [],
              adjustments: adjBySaleId[s.dbId] ?? [],
            ),
          )
          .toList();

      final analytics = SalesAnalytics.compute(salesWithLines);

      if (mounted) {
        setState(() {
          _sales = salesWithLines;
          _analytics = analytics;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── available waiters / tables for filter dropdowns ────────────────────────

  List<String> get _allWaiters {
    final names = ManagerData.instance.salesHistory
        .map((s) => s.waiterName)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  List<int> get _allTables {
    final ids = ManagerData.instance.salesHistory
        .map((s) => s.tableId)
        .toSet()
        .toList()
      ..sort();
    return ids;
  }

  void _clearFilters() {
    setState(() {
      _dateFilter = SHDateFilter.allTime;
      _customRange = null;
      _selectedWaiter = null;
      _selectedTable = null;
      _searchCtrl.clear();
    });
    _loadData();
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final a = _analytics;
      if (a == null) return;

      final reportData = SalesHistoryReportData(
        dateRangeLabel: _dateRangeLabel,
        companyName: ManagerData.instance.companyName ?? tr.posSystem,
        sales: _sales
            .map(
              (s) => SaleWithLinesData(
                sale: s.sale,
                lines: s.lines,
                adjustments: s.adjustments,
              ),
            )
            .toList(),
        analytics: SalesAnalyticsData(
          totalSales: a.totalSales,
          grossRevenue: a.grossRevenue,
          totalRefunded: a.totalRefunded,
          avgOrderValue: a.avgOrderValue,
          totalItemsSold: a.totalItemsSold,
          topProducts: a.topProducts,
          topCategories: a.topCategories,
          topWaiterName: a.topWaiterName,
          topWaiterRevenue: a.topWaiterRevenue,
        ),
      );

      final bytes = await buildSalesHistoryPdfBytes(reportData);
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf.pdfExportFailed(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        if (_loading)
          Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (_error != null)
          _buildError()
        else ...[
          if (_analytics != null) ...[
            SHKpiRow(analytics: _analytics!),
            const SizedBox(height: 20),
          ],
          SHFiltersCard(
            analytics: _analytics,
            searchCtrl: _searchCtrl,
            dateFilter: _dateFilter,
            onDateFilterChanged: (f) {
              setState(() => _dateFilter = f);
              _loadData();
            },
            selectedWaiter: _selectedWaiter,
            allWaiters: _allWaiters,
            onWaiterChanged: (v) {
              setState(() => _selectedWaiter = v);
              _loadData();
            },
            selectedTable: _selectedTable,
            allTables: _allTables,
            onTableChanged: (v) {
              setState(() => _selectedTable = v);
              _loadData();
            },
            onClearFilters: _clearFilters,
            onSearch: _loadData,
          ),
          const SizedBox(height: 20),
          _buildOrderHistoryCard(),
        ],
      ],
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return PanelHeader(
      icon: Icons.history_outlined,
      title: 'Historiku i shitjeve',
      subtitle: 'Analitika e detajuar e shitjeve dhe historiku i porosive.',
      actions: [
        OutlinedButton.icon(
          onPressed: _exportingPdf ? null : _exportPdf,
          icon: _exportingPdf
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                )
              : const Icon(Icons.download_outlined, size: 16),
          label: const Text('Eksporto PDF'),
        ),
      ],
    );
  }
  // ── order history card ─────────────────────────────────────────────────────

  Widget _buildOrderHistoryCard() {
    return Container(
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
              Text(
                'Historiku i Porosive',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              if (_sales.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_sales.length} porosi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (_sales.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_expandedIds.length == _sales.length) {
                        _expandedIds.clear();
                      } else {
                        _expandedIds.addAll(
                          _sales.map((s) => s.sale.dbId).whereType<int>(),
                        );
                      }
                    });
                  },
                  icon: Icon(
                    _expandedIds.length == _sales.length
                        ? Icons.unfold_less
                        : Icons.unfold_more,
                    size: 16,
                  ),
                  label: Text(
                    _expandedIds.length == _sales.length
                        ? tr.mbyllGjitha
                        : tr.hapGjitha,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_sales.isEmpty)
            _buildEmptyOrders()
          else
            for (final s in _sales)
              SaleCard(
                data: s,
                expanded: s.sale.dbId != null &&
                    _expandedIds.contains(s.sale.dbId),
                onToggle: () {
                  final id = s.sale.dbId;
                  if (id == null) return;
                  setState(() {
                    if (_expandedIds.contains(id)) {
                      _expandedIds.remove(id);
                    } else {
                      _expandedIds.add(id);
                    }
                  });
                },
                onRefund: s.sale.dbId != null
                    ? () => showSHRefundDialog(context, s, onSuccess: _loadData)
                    : null,
                onReprint: s.lines.isNotEmpty
                    ? () => _reprintSaleReceipt(s)
                    : null,
              ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.lightGreenText.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Nuk ka porosi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGreenText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr.ndryshoFiltratOsePeriudhen,
            style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
          ),
        ],
      ),
    );
  }

  // ── error state ────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.negativeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.negativeText.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.negativeText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trf.loadFailed(_error),
              style: TextStyle(color: AppColors.negativeText),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            child: const Text('Riprovo'),
          ),
        ],
      ),
    );
  }
}


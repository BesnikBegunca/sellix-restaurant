import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../manager/manager_data.dart';
import '../services/database_service.dart';
import '../services/sales_history_pdf.dart';
import '../theme/app_colors.dart';

// ─────────────────────────── enums & local models ────────────────────────────

enum _DateFilter { today, thisWeek, thisMonth, allTime, custom }

class SaleWithLines {
  const SaleWithLines({
    required this.sale,
    required this.lines,
    this.adjustments = const [],
  });
  final SaleRow sale;
  final List<SaleLineRow> lines;
  final List<SaleAdjustmentRow> adjustments;

  double get totalAdjusted =>
      adjustments.fold<double>(0, (s, a) => s + a.amount);
  double get netTotal => sale.total - totalAdjusted;
}

class SalesAnalytics {
  const SalesAnalytics({
    required this.totalSales,
    required this.grossRevenue,
    required this.totalRefunded,
    required this.avgOrderValue,
    required this.totalItemsSold,
    required this.topProducts,
    required this.topCategories,
    required this.topWaiterName,
    required this.topWaiterRevenue,
  });

  final int totalSales;
  final double grossRevenue;
  final double totalRefunded;
  final double avgOrderValue;
  final int totalItemsSold;
  final List<({String name, double revenue, int qty})> topProducts;
  final List<({String name, double revenue})> topCategories;
  final String topWaiterName;
  final double topWaiterRevenue;

  double get netRevenue => grossRevenue - totalRefunded;

  static SalesAnalytics compute(List<SaleWithLines> sales) {
    int totalItems = 0;
    final productRevenue = <String, double>{};
    final productQty = <String, int>{};
    final categoryRevenue = <String, double>{};
    final waiterRevenue = <String, double>{};

    for (final s in sales) {
      waiterRevenue[s.sale.waiterName] =
          (waiterRevenue[s.sale.waiterName] ?? 0) + s.sale.total;
      for (final l in s.lines) {
        totalItems += l.quantity;
        productRevenue[l.productName] =
            (productRevenue[l.productName] ?? 0) + l.lineTotal;
        productQty[l.productName] =
            (productQty[l.productName] ?? 0) + l.quantity;
        final cat = l.categoryName;
        if (cat != null && cat.isNotEmpty) {
          categoryRevenue[cat] = (categoryRevenue[cat] ?? 0) + l.lineTotal;
        }
      }
    }

    final grossRevenue = sales.fold<double>(0, (s, e) => s + e.sale.total);
    final totalRefunded = sales.fold<double>(0, (s, e) => s + e.totalAdjusted);
    final avgOrder = sales.isEmpty ? 0.0 : grossRevenue / sales.length;

    final topProducts = productRevenue.entries
        .map((e) => (
              name: e.key,
              revenue: e.value,
              qty: productQty[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final topCategories = categoryRevenue.entries
        .map((e) => (name: e.key, revenue: e.value))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    String topWaiterName = '—';
    double topWaiterRevenue = 0;
    for (final e in waiterRevenue.entries) {
      if (e.value > topWaiterRevenue) {
        topWaiterRevenue = e.value;
        topWaiterName = e.key;
      }
    }

    return SalesAnalytics(
      totalSales: sales.length,
      grossRevenue: grossRevenue,
      totalRefunded: totalRefunded,
      avgOrderValue: avgOrder,
      totalItemsSold: totalItems,
      topProducts: topProducts.take(5).toList(),
      topCategories: topCategories.take(5).toList(),
      topWaiterName: topWaiterName,
      topWaiterRevenue: topWaiterRevenue,
    );
  }
}

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
  _DateFilter _dateFilter = _DateFilter.allTime;
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
      case _DateFilter.today:
        return DateTimeRange(
          start: _startOfDay(now),
          end: _endOfDay(now),
        );
      case _DateFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: _startOfDay(monday), end: _endOfDay(now));
      case _DateFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _endOfDay(now),
        );
      case _DateFilter.allTime:
        return null;
      case _DateFilter.custom:
        return _customRange;
    }
  }

  String get _dateRangeLabel {
    switch (_dateFilter) {
      case _DateFilter.today:
        return 'Sot';
      case _DateFilter.thisWeek:
        return 'Kjo javë';
      case _DateFilter.thisMonth:
        return 'Ky muaj';
      case _DateFilter.allTime:
        return 'Të gjitha';
      case _DateFilter.custom:
        if (_customRange == null) return 'Personalizuar';
        final s = _customRange!.start;
        final e = _customRange!.end;
        return '${s.day}/${s.month}/${s.year} – ${e.day}/${e.month}/${e.year}';
    }
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
        if (range != null &&
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

  // ── PDF export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final a = _analytics;
      if (a == null) return;

      final reportData = SalesHistoryReportData(
        dateRangeLabel: _dateRangeLabel,
        companyName: ManagerData.instance.companyName ?? 'POS System',
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
            content: Text('PDF export dështoi: $e'),
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (_error != null)
          _buildError()
        else ...[
          if (_analytics != null) ...[
            _buildKpiRow(_analytics!),
            const SizedBox(height: 20),
          ],
          _buildFiltersAndInsightsCard(),
          const SizedBox(height: 20),
          _buildOrderHistoryCard(),
        ],
      ],
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historiku i Shitjeve',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreenText,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Analitika e detajuar e shitjeve dhe historiku',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.lightGreenText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _exportingPdf ? null : _exportPdf,
          icon: _exportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                )
              : const Icon(Icons.download_outlined, size: 16),
          label: const Text('Eksporto PDF'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkGreenText,
            side: const BorderSide(color: AppColors.lightGreenBorder),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── KPI row ────────────────────────────────────────────────────────────────

  Widget _buildKpiRow(SalesAnalytics a) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SHKpiCard(
              icon: Icons.attach_money_outlined,
              label: 'Të Ardhurat Totale',
              value: '${a.grossRevenue.toStringAsFixed(2)}€',
              badge: a.totalSales > 0 ? '+${a.totalSales} orders' : null,
              accentColor: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SHKpiCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Porosi Gjithsej',
              value: '${a.totalSales}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SHKpiCard(
              icon: Icons.trending_up_outlined,
              label: 'Vlera Mesatare',
              value: '${a.avgOrderValue.toStringAsFixed(2)}€',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SHKpiCard(
              icon: Icons.inventory_2_outlined,
              label: 'Artikuj të Shitur',
              value: '${a.totalItemsSold}',
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters & Search + insights card ───────────────────────────────────────

  Widget _buildFiltersAndInsightsCard() {
    final a = _analytics;
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
          const Text(
            'Filtrat & Kërkim',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),

          // Search + period tabs row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Kërko porosi, artikuj ose kamarierë...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.lightGreenText,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.lightGreenBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.lightGreenBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: const TextStyle(
                      color: AppColors.lightGreenText,
                      fontSize: 14,
                    ),
                  ),
                  onChanged: (_) => _loadData(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGreenBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _periodTab(_DateFilter.today, 'Sot'),
                    _periodTab(_DateFilter.thisWeek, 'Javë'),
                    _periodTab(_DateFilter.thisMonth, 'Muaj'),
                    _periodTab(_DateFilter.allTime, 'Të gjitha'),
                  ],
                ),
              ),
            ],
          ),

          // Analytics insights below search
          if (a != null &&
              (a.topProducts.isNotEmpty ||
                  a.topCategories.isNotEmpty)) ...[
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.topProducts.isNotEmpty)
                    Expanded(
                      child: _buildTopProductsCard(a.topProducts),
                    ),
                  if (a.topProducts.isNotEmpty &&
                      a.topCategories.isNotEmpty)
                    const SizedBox(width: 20),
                  if (a.topCategories.isNotEmpty)
                    Expanded(
                      child: _buildCategoryChart(a.topCategories),
                    ),
                ],
              ),
            ),
          ],

          // Secondary filters: waiter + table
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(width: 200, child: _waiterDropdown()),
              const SizedBox(width: 12),
              SizedBox(width: 160, child: _tableDropdown()),
              const Spacer(),
              if (_selectedWaiter != null ||
                  _selectedTable != null ||
                  _searchCtrl.text.isNotEmpty ||
                  _dateFilter != _DateFilter.allTime)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Pastro filtrat'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mediumGreenText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodTab(_DateFilter f, String label) {
    final sel = _dateFilter == f;
    return GestureDetector(
      onTap: () {
        setState(() => _dateFilter = f);
        _loadData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? Colors.white : AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(
    List<({String name, double revenue, int qty})> products,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produktet Kryesore',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          for (final p in products.take(4)) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                      Text(
                        '${p.qty} shitur',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${p.revenue.toStringAsFixed(0)}€',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChart(
    List<({String name, double revenue})> categories,
  ) {
    final maxRev = categories.fold<double>(
      0,
      (m, c) => math.max(m, c.revenue),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Të Ardhura sipas Kategorisë',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          for (final cat in categories.take(5)) ...[
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            maxRev > 0 ? (cat.revenue / maxRev) : 0,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${cat.revenue.toStringAsFixed(0)}€',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _waiterDropdown() {
    final waiters = _allWaiters;
    return DropdownButtonFormField<String?>(
      value: _selectedWaiter,
      decoration: _filterDeco('Të gjithë kamarierët'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Të gjithë kamarierët'),
        ),
        for (final w in waiters)
          DropdownMenuItem<String?>(value: w, child: Text(w)),
      ],
      onChanged: (v) {
        setState(() => _selectedWaiter = v);
        _loadData();
      },
    );
  }

  Widget _tableDropdown() {
    final tables = _allTables;
    return DropdownButtonFormField<int?>(
      value: _selectedTable,
      decoration: _filterDeco('Të gjitha tavolinat'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Të gjitha tavolinat'),
        ),
        for (final t in tables)
          DropdownMenuItem<int?>(value: t, child: Text('Tavolina $t')),
      ],
      onChanged: (v) {
        setState(() => _selectedTable = v);
        _loadData();
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _dateFilter = _DateFilter.allTime;
      _customRange = null;
      _selectedWaiter = null;
      _selectedTable = null;
      _searchCtrl.clear();
    });
    _loadData();
  }

  InputDecoration _filterDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.lightGreenText,
        ),
        filled: true,
        fillColor: AppColors.beige,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightGreenBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightGreenBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  // ── refund dialog ──────────────────────────────────────────────────────────

  Future<void> _showRefundDialog(SaleWithLines swl) async {
    final formKey = GlobalKey<FormState>();
    String adjustmentType = 'refund';
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Regjistro rimbursim / anulim'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shitja #${swl.sale.dbId}  ·  Totali: ${swl.sale.total.toStringAsFixed(2)}€',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'refund', label: Text('Rimbursim')),
                      ButtonSegment(value: 'void', label: Text('Anulim')),
                      ButtonSegment(value: 'discount', label: Text('Zbritje')),
                    ],
                    selected: {adjustmentType},
                    onSelectionChanged: (s) =>
                        setDlg(() => adjustmentType = s.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Shuma (€)',
                      border: OutlineInputBorder(),
                      suffixText: '€',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Shuma duhet të jetë > 0';
                      if (n > swl.sale.total) return 'Kalon totalin e shitjes';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Arsyeja (opsionale)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Konfirmo'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount = double.parse(amountCtrl.text);
    final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();

    try {
      await ManagerData.instance.recordAdjustment(
        saleId: swl.sale.dbId!,
        adjustmentType: adjustmentType,
        amount: amount,
        reason: reason,
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rimbursimi dështoi: $e'),
            backgroundColor: AppColors.negativeText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
              const Text(
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
                    style: const TextStyle(
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
                        ? 'Mbyll të gjitha'
                        : 'Hap të gjitha',
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
              _SaleCard(
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
                    ? () => _showRefundDialog(s)
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
          const Text(
            'Nuk ka porosi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGreenText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ndrysho filtrat ose periudhën.',
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
          const Icon(
            Icons.error_outline,
            color: AppColors.negativeText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Gabim gjatë ngarkimit: $_error',
              style: const TextStyle(color: AppColors.negativeText),
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

// ─────────────────────────── sale card widget ─────────────────────────────────

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.data,
    required this.expanded,
    required this.onToggle,
    this.onRefund,
  });

  final SaleWithLines data;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context) {
    final sale = data.sale;
    final lines = data.lines;

    final ts = sale.timestamp;
    final dateStr =
        '${ts.day.toString().padLeft(2, '0')}.${ts.month.toString().padLeft(2, '0')}.${ts.year}';
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    final orderId =
        'ORD-${(sale.dbId ?? 0).toString().padLeft(3, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded
              ? AppColors.primaryGreen.withValues(alpha: 0.25)
              : AppColors.lightGreenBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── header row ─────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(expanded ? 0 : 14),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Table number badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'T${sale.tableId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Order ID + date/waiter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderId,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$dateStr at $timeStr  •  ${sale.waiterName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sale.total.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: expanded
                          ? AppColors.primaryGreen
                          : AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── expanded line items ────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildLineItems(lines, data.adjustments, onRefund),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItems(
    List<SaleLineRow> lines,
    List<SaleAdjustmentRow> adjustments,
    VoidCallback? onRefund,
  ) {
    final linesTotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final adjTotal = adjustments.fold(0.0, (s, a) => s + a.amount);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F8F4),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1),
          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Artikujt e Porosisë',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${lines.length} artikull${lines.length == 1 ? '' : 'ë'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGreenText,
                  ),
                ),
              ],
            ),
          ),
          // Line items
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  // Quantity circle
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${line.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Emoji
                  Text(line.productEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  // Product name
                  Expanded(
                    child: Text(
                      line.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ),
                  // Unit price (small)
                  Text(
                    '${line.productPrice.toStringAsFixed(2)}€ × ${line.quantity}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Line total
                  Text(
                    '${line.lineTotal.toStringAsFixed(2)}€',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ],
              ),
            ),
          // Adjustment rows
          if (adjustments.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            for (final adj in adjustments) _AdjustmentRow(adj: adj),
          ],
          // Footer
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                if (onRefund != null)
                  OutlinedButton.icon(
                    onPressed: onRefund,
                    icon: const Icon(Icons.undo_outlined, size: 14),
                    label: const Text('Rimburso'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negativeText,
                      side: BorderSide(
                        color: AppColors.negativeText.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                const Spacer(),
                if (adjTotal > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Nëntotali  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                          Text(
                            '${linesTotal.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Refund  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.negativeText,
                            ),
                          ),
                          Text(
                            '-${adjTotal.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.negativeText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Totali Neto  ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          Text(
                            '${(linesTotal - adjTotal).toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      const Text(
                        'Totali  ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                      Text(
                        '${linesTotal.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── adjustment row widget ───────────────────────────

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({required this.adj});
  final SaleAdjustmentRow adj;

  String get _typeLabel {
    switch (adj.adjustmentType) {
      case 'refund':
        return 'Rimbursim';
      case 'void':
        return 'Anulim';
      case 'discount':
        return 'Zbritje';
      default:
        return adj.adjustmentType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = adj.createdAt;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.negativeText.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _typeLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.negativeText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              adj.reason ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.lightGreenText,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '-${adj.amount.toStringAsFixed(2)}€',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.negativeText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── KPI card widget ─────────────────────────────────

class _SHKpiCard extends StatelessWidget {
  const _SHKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? badge;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primaryGreen;
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGreenText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
          if (badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildFiltersCard(),
        const SizedBox(height: 20),
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
            _buildAnalyticsGrid(_analytics!),
            const SizedBox(height: 20),
          ],
          if (_analytics != null &&
              (_analytics!.topProducts.isNotEmpty ||
                  _analytics!.topCategories.isNotEmpty)) ...[
            _buildTopInsights(_analytics!),
            const SizedBox(height: 20),
          ],
          _buildSalesList(),
        ],
      ],
    );
  }

  // ── header row ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historiku i Shitjeve',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _analytics == null
                    ? 'Duke ngarkuar…'
                    : '${_analytics!.totalSales} shitje · $_dateRangeLabel',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.lightGreenText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _exportingPdf ? null : _exportPdf,
          icon: _exportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Eksporto PDF'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ── filters card ───────────────────────────────────────────────────────────

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _DateFilter.values) _dateChip(f),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Waiter + table dropdowns + search
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 200, child: _waiterDropdown()),
              SizedBox(width: 160, child: _tableDropdown()),
              SizedBox(width: 220, child: _searchField()),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Pastro filtrat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mediumGreenText,
                  side: BorderSide(color: AppColors.borderVisible(0.2)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateChip(_DateFilter f) {
    final labels = {
      _DateFilter.today: 'Sot',
      _DateFilter.thisWeek: 'Kjo javë',
      _DateFilter.thisMonth: 'Ky muaj',
      _DateFilter.allTime: 'Të gjitha',
      _DateFilter.custom: 'Personalizuar',
    };
    final sel = _dateFilter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () async {
          if (f == _DateFilter.custom) {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: _customRange,
              builder: (ctx, child) => Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primaryGreen,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked == null) return;
            setState(() {
              _dateFilter = _DateFilter.custom;
              _customRange = picked;
            });
          } else {
            setState(() => _dateFilter = f);
          }
          _loadData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryGreen : AppColors.beige,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel
                  ? AppColors.primaryGreen
                  : AppColors.borderVisible(0.15),
            ),
          ),
          child: Text(
            labels[f] ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? Colors.white : AppColors.mediumGreenText,
            ),
          ),
        ),
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
          DropdownMenuItem<int?>(value: t, child: Text('Table $t')),
      ],
      onChanged: (v) {
        setState(() => _selectedTable = v);
        _loadData();
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: _filterDeco('Kërko me numër shitjeje'),
      keyboardType: TextInputType.number,
      onChanged: (_) => _loadData(),
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
          borderSide: BorderSide(color: AppColors.borderVisible(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderVisible(0.15)),
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

  // ── analytics KPI grid ─────────────────────────────────────────────────────

  Widget _buildAnalyticsGrid(SalesAnalytics a) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          icon: Icons.receipt_long_outlined,
          label: 'Shitje gjithsej',
          value: '${a.totalSales}',
        ),
        _kpiCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Të ardhura bruto',
          value: '€${a.grossRevenue.toStringAsFixed(2)}',
          highlight: true,
        ),
        if (a.totalRefunded > 0)
          _kpiCard(
            icon: Icons.undo_outlined,
            label: 'Rimbursime',
            value: '-€${a.totalRefunded.toStringAsFixed(2)}',
            negative: true,
          ),
        if (a.totalRefunded > 0)
          _kpiCard(
            icon: Icons.trending_up_outlined,
            label: 'Të ardhura neto',
            value: '€${a.netRevenue.toStringAsFixed(2)}',
            highlight: true,
          ),
        _kpiCard(
          icon: Icons.calculate_outlined,
          label: 'Mesatare/porosi',
          value: '€${a.avgOrderValue.toStringAsFixed(2)}',
        ),
        _kpiCard(
          icon: Icons.inventory_2_outlined,
          label: 'Artikuj të shitur',
          value: '${a.totalItemsSold}',
        ),
        _kpiCard(
          icon: Icons.emoji_events_outlined,
          label: 'Top kamarier',
          value: a.topWaiterName,
          sub: a.topWaiterName == '—'
              ? null
              : '€${a.topWaiterRevenue.toStringAsFixed(2)}',
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    String? sub,
    bool highlight = false,
    bool negative = false,
  }) {
    final Color fgColor = negative
        ? AppColors.negativeText
        : highlight
            ? AppColors.primaryGreen
            : AppColors.darkGreenText;
    final Color bgColor = negative
        ? AppColors.negativeBg
        : highlight
            ? AppColors.lightGreenBg
            : AppColors.white;
    final Color iconBg = negative
        ? AppColors.negativeText.withValues(alpha: 0.1)
        : highlight
            ? AppColors.primaryGreen.withValues(alpha: 0.12)
            : AppColors.beige;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: negative
              ? AppColors.negativeText.withValues(alpha: 0.2)
              : highlight
                  ? AppColors.borderEmphasized(0.25)
                  : AppColors.borderSubtle(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: fgColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.lightGreenText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.lightGreenText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── top products / categories ──────────────────────────────────────────────

  Widget _buildTopInsights(SalesAnalytics a) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.topProducts.isNotEmpty)
          Expanded(child: _insightCard('Produktet kryesore', a.topProducts)),
        if (a.topProducts.isNotEmpty && a.topCategories.isNotEmpty)
          const SizedBox(width: 16),
        if (a.topCategories.isNotEmpty)
          Expanded(
            child: _categoryCard('Të ardhura sipas kategorisë', a.topCategories),
          ),
      ],
    );
  }

  Widget _insightCard(
    String title,
    List<({String name, double revenue, int qty})> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _insightRow(
              rank: i + 1,
              name: items[i].name,
              revenue: items[i].revenue,
              badge: '×${items[i].qty}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryCard(
    String title,
    List<({String name, double revenue})> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _insightRow(
              rank: i + 1,
              name: items[i].name,
              revenue: items[i].revenue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightRow({
    required int rank,
    required String name,
    required double revenue,
    String? badge,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank == 1
                ? AppColors.primaryGreen
                : AppColors.lightGreenBg,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  rank == 1 ? Colors.white : AppColors.mediumGreenText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkGreenText,
            ),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          '€${revenue.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }

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
                    'Shitja #${swl.sale.dbId}  ·  Totali: €${swl.sale.total.toStringAsFixed(2)}',
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
                      prefixText: '€',
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

  // ── sales list ─────────────────────────────────────────────────────────────

  Widget _buildSalesList() {
    if (_sales.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.lightGreenText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nuk ka shitje për filtrat e zgjedhur',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ndrysho filtrat ose bëj pagesa të reja.',
              style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // List header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_sales.length} shitje',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_expandedIds.length == _sales.length) {
                      _expandedIds.clear();
                    } else {
                      _expandedIds.addAll(
                        _sales
                            .map((s) => s.sale.dbId)
                            .whereType<int>(),
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
        ),
        for (final s in _sales) _SaleCard(
          data: s,
          expanded: s.sale.dbId != null && _expandedIds.contains(s.sale.dbId),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded
              ? AppColors.borderEmphasized(0.2)
              : AppColors.borderSubtle(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Sale ID badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${sale.dbId ?? '?'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Waiter + Table
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.waiterName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        Text(
                          'Table ${sale.tableId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.lightGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date + time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Total
                  Text(
                    '€${sale.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.mediumGreenText,
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
    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: const Divider(height: 1),
      );
    }

    final linesTotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final adjTotal = adjustments.fold(0.0, (s, a) => s + a.amount);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Produkti',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Kategoria',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Sasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'Çmimi',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    'Totali',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Line rows
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                thickness: 0.5,
              ),
            _LineRow(line: lines[i]),
          ],
          // Adjustment rows (refunds/voids)
          if (adjustments.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            for (final adj in adjustments) _AdjustmentRow(adj: adj),
          ],
          // Footer: totals + refund button
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Bruto  ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                        Text(
                          '€${linesTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ],
                    ),
                    if (adjTotal > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Rimbursim  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.negativeText,
                            ),
                          ),
                          Text(
                            '-€${adjTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
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
                            'Neto  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                          Text(
                            '€${(linesTotal - adjTotal).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          const Text(
                            'Total  ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          Text(
                            '€${linesTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
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
            '-€${adj.amount.toStringAsFixed(2)}',
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

// ─────────────────────────── line row widget ──────────────────────────────────

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final SaleLineRow line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Emoji thumbnail
          Text(line.productEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          // Product name (historical snapshot)
          Expanded(
            flex: 3,
            child: Text(
              line.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.darkGreenText,
              ),
            ),
          ),
          // Category snapshot
          Expanded(
            flex: 2,
            child: Text(
              line.categoryName ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.lightGreenText,
              ),
            ),
          ),
          // Quantity
          SizedBox(
            width: 40,
            child: Text(
              '×${line.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
          // Historical unit price (immutable snapshot)
          SizedBox(
            width: 64,
            child: Text(
              '€${line.productPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
          // Line total
          SizedBox(
            width: 72,
            child: Text(
              '€${line.lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../services/database_service.dart';

// ─────────────────────────────── models ───────────────────────────────────────

/// Expense / salary row persisted in the [expenses] SQLite table.
class ExpenseRow {
  ExpenseRow({
    this.dbId,
    required this.type,
    required this.description,
    required this.amount,
    DateTime? date,
    this.shiftId,
  }) : date = date ?? DateTime.now();

  /// Primary key from SQLite — null until after first DB insert.
  final int? dbId;

  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final int? shiftId;

  factory ExpenseRow.fromMap(Map<String, dynamic> m) => ExpenseRow(
    dbId: m['id'] as int?,
    type: m['type'] as String,
    description: m['description'] as String,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.parse(m['timestamp'] as String),
    shiftId: m['shiftId'] as int?,
  );
}

/// Archived shift record from the [shifts] SQLite table.
class ShiftRecord {
  const ShiftRecord({
    required this.id,
    required this.openedAt,
    this.closedAt,
    this.openedBy,
    this.closedBy,
    this.openingCash = 0,
    this.closingCash,
    required this.totalSales,
    required this.totalExpenses,
    required this.netProfit,
    required this.status,
  });

  final int id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? openedBy;
  final String? closedBy;
  final double openingCash;
  final double? closingCash;
  final double totalSales;
  final double totalExpenses;
  final double netProfit;
  final String status;

  bool get isOpen => status == 'open';

  factory ShiftRecord.fromMap(Map<String, dynamic> m) => ShiftRecord(
    id: (m['id'] as num).toInt(),
    openedAt: DateTime.parse(m['openedAt'] as String),
    closedAt: m['closedAt'] != null
        ? DateTime.tryParse(m['closedAt'] as String)
        : null,
    openedBy: m['openedBy'] as String?,
    closedBy: m['closedBy'] as String?,
    openingCash: (m['openingCash'] as num?)?.toDouble() ?? 0,
    closingCash: (m['closingCash'] as num?)?.toDouble(),
    totalSales: (m['totalSales'] as num?)?.toDouble() ?? 0,
    totalExpenses: (m['totalExpenses'] as num?)?.toDouble() ?? 0,
    netProfit: (m['netProfit'] as num?)?.toDouble() ?? 0,
    status: m['status'] as String? ?? 'open',
  );
}

/// A refund, void, or discount recorded against a sale, in [sale_adjustments].
class SaleAdjustmentRow {
  const SaleAdjustmentRow({
    required this.id,
    required this.saleId,
    this.saleLineId,
    required this.adjustmentType,
    this.productName,
    this.quantity,
    required this.amount,
    this.reason,
    this.createdBy,
    required this.createdAt,
  });

  final int id;
  final int saleId;
  final int? saleLineId;
  final String adjustmentType;
  final String? productName;
  final int? quantity;
  final double amount;
  final String? reason;
  final String? createdBy;
  final DateTime createdAt;

  factory SaleAdjustmentRow.fromMap(Map<String, dynamic> m) =>
      SaleAdjustmentRow(
        id: (m['id'] as num).toInt(),
        saleId: (m['saleId'] as num).toInt(),
        saleLineId: m['saleLineId'] != null
            ? (m['saleLineId'] as num).toInt()
            : null,
        adjustmentType: m['adjustmentType'] as String,
        productName: m['productName'] as String?,
        quantity: m['quantity'] != null ? (m['quantity'] as num).toInt() : null,
        amount: (m['amount'] as num).toDouble(),
        reason: m['reason'] as String?,
        createdBy: m['createdBy'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

/// Immutable snapshot of one ordered product, persisted in [sale_lines].
///
/// All fields are copied at payment time — future edits to the product
/// catalogue never alter historical records.
class SaleLineRow {
  const SaleLineRow({
    this.dbId,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.productEmoji,
    this.productImagePath,
    required this.productPrice,
    required this.quantity,
    required this.lineTotal,
    this.categoryName,
    this.tableName,
    this.waiterName,
    required this.createdAt,
  });

  final int? dbId;
  final int saleId;
  final String? productId;
  final String productName;
  final String productEmoji;
  final String? productImagePath;
  final double productPrice;
  final int quantity;
  final double lineTotal;
  final String? categoryName;
  final String? tableName;
  final String? waiterName;
  final DateTime createdAt;

  factory SaleLineRow.fromMap(Map<String, dynamic> m) => SaleLineRow(
    dbId: m['id'] as int?,
    saleId: (m['saleId'] as num).toInt(),
    productId: m['productId'] as String?,
    productName: m['productName'] as String,
    productEmoji: m['productEmoji'] as String? ?? '☕',
    productImagePath: m['productImagePath'] as String?,
    productPrice: (m['productPrice'] as num).toDouble(),
    quantity: (m['quantity'] as num).toInt(),
    lineTotal: (m['lineTotal'] as num).toDouble(),
    categoryName: m['categoryName'] as String?,
    tableName: m['tableName'] as String?,
    waiterName: m['waiterName'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}

/// Single completed sale, persisted in the [sales] SQLite table.
class SaleRow {
  const SaleRow({
    this.dbId,
    required this.waiterName,
    required this.tableId,
    required this.total,
    required this.timestamp,
    this.shiftId,
  });

  final int? dbId;
  final String waiterName;
  final int tableId;
  final double total;
  final DateTime timestamp;
  final int? shiftId;

  factory SaleRow.fromMap(Map<String, dynamic> m) => SaleRow(
    dbId: m['id'] as int?,
    waiterName: m['waiterName'] as String,
    tableId: m['tableId'] as int,
    total: (m['total'] as num).toDouble(),
    timestamp: DateTime.parse(m['timestamp'] as String),
    shiftId: m['shiftId'] as int?,
  );
}

/// Advance (avans) given to a waiter, persisted in the [advances] SQLite table.
class AdvanceRow {
  AdvanceRow({
    this.dbId,
    required this.waiterName,
    required this.amount,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final int? dbId;
  final String waiterName;
  final double amount;
  final String note;
  final DateTime date;

  factory AdvanceRow.fromMap(Map<String, dynamic> m) => AdvanceRow(
    dbId: m['id'] as int?,
    waiterName: m['waiterName'] as String,
    amount: (m['amount'] as num).toDouble(),
    note: m['note'] as String? ?? '',
    date: DateTime.parse(m['timestamp'] as String),
  );
}

/// Waiter with name and PIN, persisted in the [waiters] SQLite table.
class WaiterInfo {
  WaiterInfo({this.dbId, required this.name, required this.pin});

  /// Primary key from SQLite — null until after first DB insert.
  final int? dbId;

  final String name;
  final String pin;

  factory WaiterInfo.fromMap(Map<String, dynamic> m) => WaiterInfo(
    dbId: m['id'] as int?,
    name: m['name'] as String,
    pin: m['pin'] as String,
  );
}

class CurrentOrderLine {
  const CurrentOrderLine({required this.product, required this.qty});

  final ProductItem product;
  final int qty;
}

// ───────────────────────────── ManagerData ────────────────────────────────────

/// Global state singleton backed entirely by SQLite.
///
/// In-memory lists are caches only — [DatabaseService] is always the source of
/// truth. Every mutation writes to the DB first, then updates the cache, then
/// calls [notifyListeners].
class ManagerData extends ChangeNotifier {
  ManagerData._() {
    _init();
  }

  static final ManagerData instance = ManagerData._();

  // ── loading guard ──────────────────────────────────────────────────────────

  bool isLoading = true;

  // ── company ────────────────────────────────────────────────────────────────

  String? companyName;
  Uint8List? companyLogoBytes;
  String loginMode = 'PINMODE'; // 'PINMODE' or 'NAMEMODE'

  /// Emri i printerit (Windows) ku printohen receipt-et (POS80).
  String? selectedPrinterName;

  // ── shift ──────────────────────────────────────────────────────────────────

  bool shiftOpen = false;
  DateTime? shiftOpenedAt;
  DateTime? shiftClosedAt;

  /// Primary key of the currently open shift in the [shifts] table.
  /// Null only during the brief window before [_init] completes.
  int? _currentShiftId;
  int? get currentShiftId => _currentShiftId;

  // ── cached lists (always in sync with SQLite) ──────────────────────────────

  List<TableInfo> _cashierTables = [];
  List<CategoryData> _categories = [];
  List<WaiterInfo> _waiters = [];
  List<ExpenseRow> _expenses = [];
  List<SaleRow> _salesHistory = [];
  List<AdvanceRow> _advances = [];

  /// Daily rate per waiter (waiterName → €/day).
  Map<String, double> _salaries = {};

  /// Worked days per waiter (waiterName → set of "YYYY-MM-DD" strings).
  Map<String, Set<String>> _workedDays = {};

  /// Sales per waiter accumulated since last shift close (waiterName → total).
  Map<String, double> waiterSales = {};

  int tableCount = 15;
  int tablesPerRow = 6;

  // ── public read-only accessors ─────────────────────────────────────────────

  List<TableInfo> get cashierTables => List.unmodifiable(_cashierTables);
  List<CategoryData> get categories => List.unmodifiable(_categories);
  List<WaiterInfo> get waiters => List.unmodifiable(_waiters);
  List<ExpenseRow> get expenses => List.unmodifiable(_expenses);
  List<SaleRow> get salesHistory => List.unmodifiable(_salesHistory);
  List<AdvanceRow> get advances => List.unmodifiable(_advances);
  Map<String, double> get salaries => Map.unmodifiable(_salaries);
  Map<String, Set<String>> get workedDays => Map.unmodifiable(_workedDays);

  // ─────────────────────────────── init ─────────────────────────────────────

  Future<void> _init() async {
    final db = DatabaseService.instance;

    // Company
    final company = await db.fetchCompany();
    if (company != null) {
      companyName = company['companyName'] as String?;
      final blob = company['companyLogo'];
      companyLogoBytes = blob != null
          ? Uint8List.fromList(blob as List<int>)
          : null;
      loginMode = (company['loginMode'] as String?) ?? 'PINMODE';
      selectedPrinterName = company['printerName'] as String?;
    }

    // Shift — ensure a permanent shift record exists in [shifts] table.
    shiftOpen = true;
    await _ensureOpenShift(db);

    // Waiters
    final waiterRows = await db.fetchWaiters();
    _waiters = waiterRows.map(WaiterInfo.fromMap).toList();

    // Categories + products
    await _reloadMenu(db);

    // Tables
    final tableRows = await db.fetchTables();
    _cashierTables = tableRows.map(TableInfo.fromMap).toList();
    tableCount = _cashierTables.length;

    // Expenses
    final expenseRows = await db.fetchExpenses();
    _expenses = expenseRows.map(ExpenseRow.fromMap).toList();

    // Sales → rebuild waiterSales map (current shift only)
    await _reloadSales(db);

    // Salaries + advances
    _salaries = await db.fetchAllSalaries();
    final advanceRows = await db.fetchAdvances();
    _advances = advanceRows.map(AdvanceRow.fromMap).toList();

    // Worked days
    final workedRows = await db.fetchWorkedDays();
    _workedDays = {};
    for (final r in workedRows) {
      final name = r['waiterName'] as String;
      final date = r['workDate'] as String;
      (_workedDays[name] ??= {}).add(date);
    }

    isLoading = false;
    notifyListeners();
  }

  /// Re-fetches all data from the database and notifies listeners.
  ///
  /// Call this after a database restore to bring in-memory state in sync with
  /// the newly installed database file.
  Future<void> reload() async {
    await _init();
  }

  /// Reloads categories and their products from the DB.
  Future<void> _reloadMenu(DatabaseService db) async {
    final catRows = await db.fetchCategories();
    final prodRows = await db.fetchProducts();

    // Group products by categoryId
    final byCategory = <String, List<ProductItem>>{};
    for (final row in prodRows) {
      final catId = row['categoryId'] as String;
      byCategory.putIfAbsent(catId, () => []).add(ProductItem.fromMap(row));
    }

    _categories = catRows
        .map((r) => CategoryData.fromMap(r, byCategory[r['id']] ?? []))
        .toList();
  }

  /// Rebuilds [_salesHistory] (all-time) and [waiterSales] (current shift only).
  Future<void> _reloadSales(DatabaseService db) async {
    final rows = await db.fetchSales();
    _salesHistory = rows.map(SaleRow.fromMap).toList();
    waiterSales = {};
    for (final s in _salesHistory) {
      if (s.shiftId != null && s.shiftId == _currentShiftId) {
        waiterSales[s.waiterName] = (waiterSales[s.waiterName] ?? 0) + s.total;
      }
    }
  }

  /// Loads or auto-creates the open shift record in the [shifts] table.
  /// Sets [_currentShiftId] so every subsequent sale is linked to this shift.
  Future<void> _ensureOpenShift(DatabaseService db) async {
    final open = await db.fetchOpenShift();
    if (open != null) {
      _currentShiftId = (open['id'] as num).toInt();
      final oa = open['openedAt'] as String?;
      shiftOpenedAt = oa != null ? DateTime.tryParse(oa) : null;
    } else {
      // Auto-create a shift so the system is always in a valid state.
      final now = DateTime.now();
      _currentShiftId = await db.insertShiftRecord(openedAt: now);
      shiftOpenedAt = now;
    }
  }

  // ─────────────────────────── company ──────────────────────────────────────

  Future<void> saveCompanyName(String name) async {
    if (name.trim().isEmpty) return;
    companyName = name.trim();
    await DatabaseService.instance.updateCompanyName(companyName!);
    notifyListeners();
  }

  Future<void> saveCompanyLogo(Uint8List bytes) async {
    companyLogoBytes = bytes;
    await DatabaseService.instance.updateCompanyLogo(bytes);
    notifyListeners();
  }

  Future<void> clearCompanyLogo() async {
    companyLogoBytes = null;
    await DatabaseService.instance.updateCompanyLogo(null);
    notifyListeners();
  }

  Future<void> setLoginMode(String mode) async {
    if (mode != 'PINMODE' && mode != 'NAMEMODE') return;
    loginMode = mode;
    await DatabaseService.instance.updateLoginMode(mode);
    notifyListeners();
  }

  // ─────────────────────────────── shift ────────────────────────────────────

  Future<void> openShift() async {
    shiftOpen = true;
    shiftOpenedAt = DateTime.now();
    shiftClosedAt = null;
    // Legacy singleton shift record (kept for backward compat with older UI).
    await DatabaseService.instance.updateShift(
      openedAt: shiftOpenedAt!.toIso8601String(),
      closedAt: null,
      status: 'open',
    );
    // Permanent shift archive — open a new record in [shifts] table.
    _currentShiftId = await DatabaseService.instance.insertShiftRecord(
      openedAt: shiftOpenedAt!,
    );
    waiterSales = {};
    notifyListeners();
  }

  /// Archives the current shift, resets waiter totals, and keeps the system
  /// active. Historical sales and line items are NEVER deleted.
  Future<void> closeShift() async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    shiftClosedAt = now;

    // Compute totals from the current shift's in-memory data.
    final shiftSalesTotal = _salesHistory
        .where((s) => s.shiftId == _currentShiftId)
        .fold<double>(0, (sum, s) => sum + s.total);
    final shiftExpensesTotal = _expenses
        .where((e) => e.shiftId == _currentShiftId)
        .fold<double>(0, (sum, e) => sum + e.amount);

    // Archive the shift — no data deleted.
    if (_currentShiftId != null) {
      await db.closeShiftRecord(
        shiftId: _currentShiftId!,
        closedAt: now,
        totalSales: shiftSalesTotal,
        totalExpenses: shiftExpensesTotal,
        netProfit: shiftSalesTotal - shiftExpensesTotal,
      );
    }

    // Update legacy singleton shift record.
    await db.updateShift(
      openedAt: null,
      closedAt: now.toIso8601String(),
      status: 'open',
    );

    // Open the next shift immediately so sales are never orphaned.
    _currentShiftId = await db.insertShiftRecord(openedAt: now);
    shiftOpenedAt = now;

    // Reset tables (clear active orders) but do NOT delete historical sales.
    await db.clearAllCurrentOrdersAndResetTables();
    waiterSales = {};
    _cashierTables = _cashierTables
        .map(
          (t) => TableInfo(
            id: t.id,
            occupied: false,
            currentTotal: null,
            assignedWaiterName: null,
            currentOrderNumber: 0,
          ),
        )
        .toList();
    notifyListeners();
  }

  // ─────────────────────────── waiters ──────────────────────────────────────

  Future<void> addWaiter(String name, String pin) async {
    final n = name.trim();
    final p = pin.trim();
    if (n.isEmpty || p.length < 4) return;
    // Guard against duplicate PINs (cache check is instant)
    if (_waiters.any((w) => w.pin == p) || p == '9999') return;

    final newId = await DatabaseService.instance.insertWaiter(n, p);
    _waiters.add(WaiterInfo(dbId: newId, name: n, pin: p));
    notifyListeners();
  }

  Future<void> removeWaiterAt(int index) async {
    if (index < 0 || index >= _waiters.length) return;
    final w = _waiters[index];
    if (w.dbId != null) {
      await DatabaseService.instance.deleteWaiterById(w.dbId!);
    }
    _waiters.removeAt(index);
    notifyListeners();
  }

  WaiterInfo? findWaiterByPin(String pin) {
    try {
      return _waiters.firstWhere((w) => w.pin == pin);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────── expenses ─────────────────────────────────────

  Future<void> addExpense(ExpenseRow row) async {
    final newId = await DatabaseService.instance.insertExpense(
      type: row.type,
      description: row.description,
      amount: row.amount,
      date: row.date,
      shiftId: _currentShiftId,
    );
    _expenses.insert(
      0,
      ExpenseRow(
        dbId: newId,
        type: row.type,
        description: row.description,
        amount: row.amount,
        date: row.date,
        shiftId: _currentShiftId,
      ),
    );
    notifyListeners();
  }

  Future<void> removeExpenseAt(int index) async {
    if (index < 0 || index >= _expenses.length) return;
    final e = _expenses[index];
    if (e.dbId != null) {
      await DatabaseService.instance.deleteExpenseById(e.dbId!);
    }
    _expenses.removeAt(index);
    notifyListeners();
  }

  double get totalExpenses => _expenses.fold<double>(0, (s, e) => s + e.amount);

  // ─────────────────────────── salaries ─────────────────────────────────────

  double getSalary(String waiterName) => _salaries[waiterName] ?? 0.0;

  Future<void> setSalary(String waiterName, double dailyRate) async {
    await DatabaseService.instance.upsertWaiterSalary(waiterName, dailyRate);
    _salaries = {..._salaries, waiterName: dailyRate};
    notifyListeners();
  }

  // ─────────────────────────── advances ─────────────────────────────────────

  List<AdvanceRow> advancesFor(String waiterName, DateTime from, DateTime to) =>
      _advances
          .where(
            (a) =>
                a.waiterName == waiterName &&
                !a.date.isBefore(from) &&
                !a.date.isAfter(to),
          )
          .toList();

  double totalAdvancesFor(String waiterName, DateTime from, DateTime to) =>
      advancesFor(waiterName, from, to).fold(0.0, (s, a) => s + a.amount);

  Future<void> addAdvance(AdvanceRow row) async {
    final newId = await DatabaseService.instance.insertAdvance(
      waiterName: row.waiterName,
      amount: row.amount,
      note: row.note,
      date: row.date,
    );
    _advances.insert(
      0,
      AdvanceRow(
        dbId: newId,
        waiterName: row.waiterName,
        amount: row.amount,
        note: row.note,
        date: row.date,
      ),
    );
    notifyListeners();
  }

  Future<void> deleteAdvance(int id) async {
    await DatabaseService.instance.deleteAdvanceById(id);
    _advances.removeWhere((a) => a.dbId == id);
    notifyListeners();
  }

  // ─────────────────────── worked days ──────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isDayWorked(String waiterName, DateTime date) =>
      _workedDays[waiterName]?.contains(_dateKey(date)) ?? false;

  int workedDaysInMonth(String waiterName, int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    return (_workedDays[waiterName] ?? {})
        .where((d) => d.startsWith(prefix))
        .length;
  }

  Future<void> toggleWorkedDay(String waiterName, DateTime date) async {
    final key = _dateKey(date);
    final currentSet = Set<String>.from(_workedDays[waiterName] ?? {});
    final nowWorked = !currentSet.contains(key);
    await DatabaseService.instance.setWorkedDay(waiterName, key, nowWorked);
    if (nowWorked) {
      currentSet.add(key);
    } else {
      currentSet.remove(key);
    }
    _workedDays = {..._workedDays, waiterName: currentSet};
    notifyListeners();
  }

  // ─────────────────────────── profits (real DB data) ───────────────────────

  /// Total revenue from [_salesHistory] whose timestamp falls within [from]..[to].
  double revenueInRange(DateTime from, DateTime to) => _salesHistory
      .where((s) => !s.timestamp.isBefore(from) && !s.timestamp.isAfter(to))
      .fold(0.0, (sum, s) => sum + s.total);

  /// Total expenses from [_expenses] whose date falls within [from]..[to].
  double expensesInRange(DateTime from, DateTime to) => _expenses
      .where((e) => !e.date.isBefore(from) && !e.date.isAfter(to))
      .fold(0.0, (sum, e) => sum + e.amount);

  /// Profit = revenue − expenses for a given range.
  double profitInRange(DateTime from, DateTime to) =>
      revenueInRange(from, to) - expensesInRange(from, to);

  // Convenience helpers for the three standard periods.

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  double get revenueToday {
    final now = DateTime.now();
    return revenueInRange(_startOfDay(now), _endOfDay(now));
  }

  double get revenueThisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return revenueInRange(_startOfDay(monday), _endOfDay(now));
  }

  double get revenueThisMonth {
    final now = DateTime.now();
    return revenueInRange(DateTime(now.year, now.month, 1), _endOfDay(now));
  }

  double get expensesToday {
    final now = DateTime.now();
    return expensesInRange(_startOfDay(now), _endOfDay(now));
  }

  double get expensesThisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return expensesInRange(_startOfDay(monday), _endOfDay(now));
  }

  double get expensesThisMonth {
    final now = DateTime.now();
    return expensesInRange(DateTime(now.year, now.month, 1), _endOfDay(now));
  }

  double get profitToday => revenueToday - expensesToday;
  double get profitThisWeek => revenueThisWeek - expensesThisWeek;
  double get profitThisMonth => revenueThisMonth - expensesThisMonth;

  double profitDaily() => profitToday;
  double profitWeekly() => profitThisWeek;
  double profitMonthly() => profitThisMonth;

  // ─────────────────────────── sales / top employee ─────────────────────────

  Future<void> recordSale(
    String waiterName,
    double amount, {
    int tableId = 0,
  }) async {
    if (waiterName.trim().isEmpty) return;
    final now = DateTime.now();
    await DatabaseService.instance.insertSale(
      waiterName: waiterName,
      tableId: tableId,
      total: amount,
    );
    final sale = SaleRow(
      waiterName: waiterName,
      tableId: tableId,
      total: amount,
      timestamp: now,
    );
    _salesHistory.insert(0, sale);
    waiterSales[waiterName] = (waiterSales[waiterName] ?? 0) + amount;
    notifyListeners();
  }

  /// Records a sale together with its per-product line items in one atomic
  /// transaction.  If the DB write fails the exception propagates to the caller
  /// (the payment UI) and neither the sale header nor any line row is written.
  ///
  /// All product fields (name, price, emoji, category) are snapshotted at call
  /// time, so future catalogue edits never alter historical records.
  Future<void> recordSaleWithLines({
    required String waiterName,
    required double total,
    required int tableId,
    required String tableName,
    required List<CurrentOrderLine> lines,
  }) async {
    if (waiterName.trim().isEmpty) return;

    // Build categoryName snapshot from the current in-memory menu.
    final categoryByProductId = <String, String>{};
    for (final cat in _categories) {
      for (final p in cat.products) {
        categoryByProductId[p.id] = cat.name;
      }
    }

    final lineMaps = lines.map((l) {
      final lineTotal = double.parse(
        (l.product.price * l.qty).toStringAsFixed(2),
      );
      return <String, dynamic>{
        'productId': l.product.id,
        'productName': l.product.name,
        'productEmoji': l.product.emoji,
        'productImagePath': l.product.imagePath,
        'productPrice': l.product.price,
        'quantity': l.qty,
        'lineTotal': lineTotal,
        'categoryName': categoryByProductId[l.product.id],
        'tableName': tableName,
        'waiterName': waiterName,
      };
    }).toList();

    final now = DateTime.now();
    final saleId = await DatabaseService.instance.insertSaleWithLines(
      waiterName: waiterName,
      tableId: tableId,
      total: total,
      lines: lineMaps,
      shiftId: _currentShiftId,
    );

    final sale = SaleRow(
      dbId: saleId,
      waiterName: waiterName,
      tableId: tableId,
      total: total,
      timestamp: now,
      shiftId: _currentShiftId,
    );
    _salesHistory.insert(0, sale);
    waiterSales[waiterName] = (waiterSales[waiterName] ?? 0) + total;
    notifyListeners();
  }

  /// Resets waiter totals for the current view without deleting any DB records.
  /// Historical sales are permanently preserved in [_salesHistory].
  Future<void> clearWaiterSales() async {
    waiterSales = {};
    notifyListeners();
  }

  /// Records a refund, void, or discount against an existing sale.
  /// The original sale and its line items are never modified.
  Future<SaleAdjustmentRow> recordAdjustment({
    required int saleId,
    int? saleLineId,
    required String adjustmentType,
    String? productName,
    int? quantity,
    required double amount,
    String? reason,
    String? createdBy,
  }) async {
    final newId = await DatabaseService.instance.insertSaleAdjustment(
      saleId: saleId,
      saleLineId: saleLineId,
      adjustmentType: adjustmentType,
      productName: productName,
      quantity: quantity,
      amount: amount,
      reason: reason,
      createdBy: createdBy,
    );
    return SaleAdjustmentRow(
      id: newId,
      saleId: saleId,
      saleLineId: saleLineId,
      adjustmentType: adjustmentType,
      productName: productName,
      quantity: quantity,
      amount: amount,
      reason: reason,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  List<MapEntry<String, double>> get employeeSalesSorted {
    final entries = waiterSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  MapEntry<String, double> get topEmployee {
    if (waiterSales.isEmpty) return const MapEntry('—', 0.0);
    return waiterSales.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  // ─────────────────────────────── menu ─────────────────────────────────────

  Future<void> addCategoryWithIcon({
    required String name,
    required int iconCodePoint,
  }) async {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final sortOrder = _categories.length;

    await DatabaseService.instance.insertCategory(
      id: id,
      name: name.trim(),
      iconCodePoint: iconCodePoint,
      sortOrder: sortOrder,
    );

    final icon = IconData(iconCodePoint, fontFamily: 'MaterialIcons');

    _categories = [
      ..._categories,
      CategoryData(id: id, name: name.trim(), icon: icon, products: const []),
    ];
    notifyListeners();
  }

  // Backward compatible helper (keeps older code compiling if present).
  Future<void> addCategory(String name) async {
    await addCategoryWithIcon(
      name: name,
      iconCodePoint: Icons.restaurant_menu_outlined.codePoint,
    );
  }

  Future<void> removeCategory(String categoryId) async {
    await DatabaseService.instance.deleteCategory(categoryId);
    _categories = _categories.where((c) => c.id != categoryId).toList();
    notifyListeners();
  }

  Future<void> addProduct({
    required String categoryId,
    required String name,
    required double price,
    String emoji = '☕',
    String? imagePath,
  }) async {
    final pid = 'p_${DateTime.now().microsecondsSinceEpoch}';
    await DatabaseService.instance.insertProduct(
      id: pid,
      name: name.trim(),
      price: price,
      emoji: emoji,
      imagePath: imagePath,
      categoryId: categoryId,
    );
    final product = ProductItem(
      id: pid,
      name: name.trim(),
      price: price,
      emoji: emoji,
      imagePath: imagePath,
    );
    _categories = _categories.map((c) {
      if (c.id != categoryId) return c;
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: [...c.products, product],
      );
    }).toList();
    notifyListeners();
  }

  Future<void> removeProduct(String categoryId, String productId) async {
    await DatabaseService.instance.deleteProduct(productId);
    _categories = _categories.map((c) {
      if (c.id != categoryId) return c;
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: c.products.where((p) => p.id != productId).toList(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> editProduct(
    String categoryId,
    String productId, {
    String? name,
    double? price,
    String? imagePath,
    bool clearImage = false,
  }) async {
    final fields = <String, dynamic>{};
    if (name != null) fields['name'] = name;
    if (price != null) fields['price'] = price;
    if (clearImage) {
      fields['imagePath'] = null;
    } else if (imagePath != null) {
      fields['imagePath'] = imagePath;
    }
    if (fields.isNotEmpty) {
      await DatabaseService.instance.updateProduct(productId, fields);
    }

    _categories = _categories.map((c) {
      if (c.id != categoryId) return c;
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: c.products.map((p) {
          if (p.id != productId) return p;
          return ProductItem(
            id: p.id,
            name: name ?? p.name,
            price: price ?? p.price,
            emoji: p.emoji,
            imagePath: clearImage ? null : (imagePath ?? p.imagePath),
          );
        }).toList(),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> moveProduct(
    String fromCategoryId,
    String productId,
    String toCategoryId,
  ) async {
    if (fromCategoryId == toCategoryId) return;

    // Find the product in the cache
    ProductItem? product;
    for (final c in _categories) {
      if (c.id == fromCategoryId) {
        try {
          product = c.products.firstWhere((p) => p.id == productId);
        } catch (_) {}
        break;
      }
    }
    if (product == null) return;
    final prod = product;

    await DatabaseService.instance.moveProductCategory(productId, toCategoryId);

    _categories = _categories.map((c) {
      if (c.id == fromCategoryId) {
        return CategoryData(
          id: c.id,
          name: c.name,
          icon: c.icon,
          products: c.products.where((p) => p.id != productId).toList(),
        );
      }
      if (c.id == toCategoryId) {
        return CategoryData(
          id: c.id,
          name: c.name,
          icon: c.icon,
          products: [...c.products, prod],
        );
      }
      return c;
    }).toList();
    notifyListeners();
  }

  // ─────────────────────────── tables ───────────────────────────────────────

  Future<void> setTableLayout({required int count, required int perRow}) async {
    tableCount = count.clamp(1, 48);
    tablesPerRow = perRow.clamp(2, 12);

    // Sync DB: insert missing tables, remove extras
    final existing = {for (final t in _cashierTables) t.id: t};
    final db = DatabaseService.instance;

    for (var i = 1; i <= tableCount; i++) {
      if (!existing.containsKey(i)) {
        await db.insertTable(i);
      }
    }
    for (final t in _cashierTables) {
      if (t.id > tableCount) {
        await db.deleteTable(t.id);
      }
    }

    // Rebuild cache from DB to reflect exact state
    final rows = await db.fetchTables();
    _cashierTables = rows.map(TableInfo.fromMap).toList();
    notifyListeners();
  }

  Future<void> updateTableTotal(int tableId, double total, String waiterName) async {
    final current = _cashierTables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableInfo(id: tableId, occupied: false),
    );
    await DatabaseService.instance.updateTable(
      tableId,
      occupied: true,
      currentTotal: total,
      assignedWaiterName: waiterName,
      currentOrderNumber: current.currentOrderNumber,
    );
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(
        id: t.id,
        occupied: true,
        currentTotal: total,
        assignedWaiterName: waiterName,
        currentOrderNumber: t.currentOrderNumber,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> clearTable(int tableId, String waiterName) async {
    final current = _cashierTables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableInfo(id: tableId, occupied: false),
    );
    await DatabaseService.instance.updateTable(
      tableId,
      occupied: false,
      currentTotal: null,
      assignedWaiterName: null,
      currentOrderNumber: current.currentOrderNumber ?? 0,
    );
    await DatabaseService.instance.clearCurrentOrder(tableId, waiterName);
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(
        id: t.id,
        occupied: false,
        currentTotal: null,
        assignedWaiterName: null,
        currentOrderNumber: t.currentOrderNumber ?? 0,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addCashierTable() async {
    final nextId = _cashierTables.isEmpty
        ? 1
        : _cashierTables.map((e) => e.id).reduce(math.max) + 1;
    await DatabaseService.instance.insertTable(nextId);
    _cashierTables = [
      ..._cashierTables,
      TableInfo(id: nextId, occupied: false),
    ];
    tableCount = _cashierTables.length;
    notifyListeners();
  }

  Future<void> saveCurrentOrder({
    required int tableId,
    required int orderNumber,
    required String waiterName,
    required List<CurrentOrderLine> lines,
  }) async {
    final currentTotal = lines.fold<double>(
      0,
      (sum, l) => sum + (l.product.price * l.qty),
    );
    final db = DatabaseService.instance;
    await db.upsertCurrentOrderMeta(
      tableId: tableId,
      waiterName: waiterName,
      orderNumber: orderNumber,
      currentTotal: currentTotal,
    );
    await db.replaceCurrentOrderLines(
      tableId,
      waiterName,
      lines
          .map(
            (l) => {
              'productId': l.product.id,
              'productName': l.product.name,
              'productPrice': l.product.price,
              'productEmoji': l.product.emoji,
              'imagePath': l.product.imagePath,
              'qty': l.qty,
            },
          )
          .toList(),
    );

    final current = _cashierTables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableInfo(id: tableId, occupied: false),
    );
    await db.updateTable(
      tableId,
      occupied: lines.isNotEmpty,
      currentTotal: currentTotal == 0 ? null : currentTotal,
      assignedWaiterName: waiterName,
      currentOrderNumber: orderNumber,
    );
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(
        id: t.id,
        occupied: lines.isNotEmpty,
        currentTotal: currentTotal == 0 ? null : currentTotal,
        assignedWaiterName: waiterName,
        currentOrderNumber: orderNumber,
      );
    }).toList();
    notifyListeners();
  }

  Future<List<CurrentOrderLine>> loadCurrentOrderLines(
    int tableId,
    String waiterName,
  ) async {
    final rows = await DatabaseService.instance.fetchCurrentOrderLines(
      tableId,
      waiterName,
    );
    return rows
        .map(
          (r) => CurrentOrderLine(
            product: ProductItem(
              id: r['productId'] as String,
              name: r['productName'] as String,
              price: (r['productPrice'] as num).toDouble(),
              emoji: r['productEmoji'] as String? ?? '☕',
              imagePath: r['imagePath'] as String?,
            ),
            qty: (r['qty'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<TableInfo>> tablesForWaiter(String waiterName) async {
    final rows = await DatabaseService.instance.fetchCurrentOrderMetasForWaiter(
      waiterName,
    );
    final byTable = <int, Map<String, dynamic>>{
      for (final r in rows) (r['tableId'] as num).toInt(): r,
    };
    return _cashierTables.map((t) {
      final m = byTable[t.id];
      if (m == null) {
        return TableInfo(
          id: t.id,
          occupied: false,
          currentTotal: null,
          currentOrderNumber: t.currentOrderNumber ?? 0,
        );
      }
      return TableInfo(
        id: t.id,
        occupied: true,
        currentTotal: (m['currentTotal'] as num).toDouble(),
        assignedWaiterName: waiterName,
        currentOrderNumber: (m['orderNumber'] as num).toInt(),
      );
    }).toList();
  }

  Future<int> nextGlobalOrderNumber() async {
    return DatabaseService.instance.consumeNextGlobalOrderNumber();
  }
}

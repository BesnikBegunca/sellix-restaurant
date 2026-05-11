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
  }) : date = date ?? DateTime.now();

  /// Primary key from SQLite — null until after first DB insert.
  final int? dbId;

  final String type;
  final String description;
  final double amount;
  final DateTime date;

  factory ExpenseRow.fromMap(Map<String, dynamic> m) => ExpenseRow(
    dbId: m['id'] as int?,
    type: m['type'] as String,
    description: m['description'] as String,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.parse(m['timestamp'] as String),
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
  });

  final int? dbId;
  final String waiterName;
  final int tableId;
  final double total;
  final DateTime timestamp;

  factory SaleRow.fromMap(Map<String, dynamic> m) => SaleRow(
    dbId: m['id'] as int?,
    waiterName: m['waiterName'] as String,
    tableId: m['tableId'] as int,
    total: (m['total'] as num).toDouble(),
    timestamp: DateTime.parse(m['timestamp'] as String),
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

    // Shift — system is always active; only load last-closed timestamp for display.
    shiftOpen = true;
    final shift = await db.fetchShift();
    if (shift != null) {
      final ca = shift['closedAt'] as String?;
      shiftClosedAt = ca != null ? DateTime.tryParse(ca) : null;
    }

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

    // Sales → rebuild waiterSales map
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

  /// Rebuilds [_salesHistory] and [waiterSales] from every row in the sales table.
  Future<void> _reloadSales(DatabaseService db) async {
    final rows = await db.fetchSales();
    _salesHistory = rows.map(SaleRow.fromMap).toList();
    waiterSales = {};
    for (final s in _salesHistory) {
      waiterSales[s.waiterName] = (waiterSales[s.waiterName] ?? 0) + s.total;
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
    await DatabaseService.instance.updateShift(
      openedAt: shiftOpenedAt!.toIso8601String(),
      closedAt: null,
      status: 'open',
    );
    notifyListeners();
  }

  /// Finalises the current period: records the close timestamp, resets all
  /// waiter totals to zero, and keeps the system active for the next period.
  Future<void> closeShift() async {
    shiftClosedAt = DateTime.now();
    await DatabaseService.instance.updateShift(
      openedAt: null,
      closedAt: shiftClosedAt!.toIso8601String(),
      status: 'open',
    );
    // Clear all sales so totals start fresh from zero.
    await DatabaseService.instance.clearSales();
    waiterSales.clear();
    _salesHistory.clear();
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
    );
    _expenses.insert(
      0,
      ExpenseRow(
        dbId: newId,
        type: row.type,
        description: row.description,
        amount: row.amount,
        date: row.date,
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

  Future<void> clearWaiterSales() async {
    await DatabaseService.instance.clearSales();
    waiterSales.clear();
    _salesHistory.clear();
    notifyListeners();
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

  Future<void> updateTableTotal(int tableId, double total) async {
    await DatabaseService.instance.updateTable(
      tableId,
      occupied: true,
      currentTotal: total,
    );
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(id: t.id, occupied: true, currentTotal: total);
    }).toList();
    notifyListeners();
  }

  Future<void> clearTable(int tableId) async {
    await DatabaseService.instance.updateTable(
      tableId,
      occupied: false,
      currentTotal: null,
    );
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(id: t.id, occupied: false);
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
}

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

  // ── shift ──────────────────────────────────────────────────────────────────

  bool shiftOpen = false;
  DateTime? shiftOpenedAt;
  DateTime? shiftClosedAt;

  // ── cached lists (always in sync with SQLite) ──────────────────────────────

  List<TableInfo> _cashierTables = [];
  List<CategoryData> _categories = [];
  List<WaiterInfo> _waiters = [];
  List<ExpenseRow> _expenses = [];

  /// Sales per waiter for the current session (waiterName → total).
  Map<String, double> waiterSales = {};

  int tableCount = 15;
  int tablesPerRow = 6;

  // ── public read-only accessors ─────────────────────────────────────────────

  List<TableInfo> get cashierTables => List.unmodifiable(_cashierTables);
  List<CategoryData> get categories => List.unmodifiable(_categories);
  List<WaiterInfo> get waiters => List.unmodifiable(_waiters);
  List<ExpenseRow> get expenses => List.unmodifiable(_expenses);

  // ─────────────────────────────── init ─────────────────────────────────────

  Future<void> _init() async {
    final db = DatabaseService.instance;

    // Company
    final company = await db.fetchCompany();
    if (company != null) {
      companyName = company['companyName'] as String?;
      final blob = company['companyLogo'];
      companyLogoBytes = blob != null ? Uint8List.fromList(blob as List<int>) : null;
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

  /// Rebuilds the [waiterSales] map from every row in the sales table.
  Future<void> _reloadSales(DatabaseService db) async {
    final rows = await db.fetchSales();
    waiterSales = {};
    for (final row in rows) {
      final name = row['waiterName'] as String;
      waiterSales[name] = (waiterSales[name] ?? 0) +
          (row['total'] as num).toDouble();
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

  double get totalExpenses =>
      _expenses.fold<double>(0, (s, e) => s + e.amount);

  // ─────────────────────────── profits ──────────────────────────────────────

  static const double _baseDaily = 1850;
  static const double _baseWeekly = 11200;
  static const double _baseMonthly = 46800;

  double profitDaily() => _baseDaily - totalExpenses * 0.15;
  double profitWeekly() => _baseWeekly - totalExpenses;
  double profitMonthly() => _baseMonthly - totalExpenses * 2.2;

  // ─────────────────────────── sales / top employee ─────────────────────────

  Future<void> recordSale(String waiterName, double amount) async {
    if (waiterName.trim().isEmpty) return;
    // Determine which table the sale came from (best-effort — tableId = 0 when unknown)
    await DatabaseService.instance.insertSale(
      waiterName: waiterName,
      tableId: 0,
      total: amount,
    );
    waiterSales[waiterName] = (waiterSales[waiterName] ?? 0) + amount;
    notifyListeners();
  }

  Future<void> clearWaiterSales() async {
    await DatabaseService.instance.clearSales();
    waiterSales.clear();
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

  Future<void> addCategory(String name) async {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final sortOrder = _categories.length;
    await DatabaseService.instance.insertCategory(
      id: id,
      name: name.trim(),
      iconCodePoint: Icons.restaurant_menu_outlined.codePoint,
      sortOrder: sortOrder,
    );
    _categories = [
      ..._categories,
      CategoryData(
        id: id,
        name: name.trim(),
        icon: Icons.restaurant_menu_outlined,
        products: const [],
      ),
    ];
    notifyListeners();
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

  Future<void> setTableLayout({
    required int count,
    required int perRow,
  }) async {
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

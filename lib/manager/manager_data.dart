import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mock_data.dart';

/// Rresht në tabelën e shpenzimeve / rrogave.
class ExpenseRow {
  ExpenseRow({
    required this.type,
    required this.description,
    required this.amount,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final String type;
  final String description;
  final double amount;
  final DateTime date;
}

/// Kamarieri me emër dhe PIN.
class WaiterInfo {
  const WaiterInfo({required this.name, required this.pin});
  final String name;
  final String pin;
}

/// Gjendja globale për menaxherin, tavolinat e kasierit dhe menunë dinamike.
class ManagerData extends ChangeNotifier {
  ManagerData._() {
    _categories = List<CategoryData>.from(mockCategories);
    _syncTablesFromSettings();
  }

  static final ManagerData instance = ManagerData._();

  // —— Gjendja (shift) ——
  bool shiftOpen = false;
  DateTime? shiftOpenedAt;
  DateTime? shiftClosedAt;

  void openShift() {
    shiftOpen = true;
    shiftOpenedAt = DateTime.now();
    shiftClosedAt = null;
    notifyListeners();
  }

  void closeShift() {
    shiftOpen = false;
    shiftClosedAt = DateTime.now();
    notifyListeners();
  }

  // —— Kamarierët ——
  final List<WaiterInfo> waiters = <WaiterInfo>[];

  void addWaiter(String name, String pin) {
    final n = name.trim();
    final p = pin.trim();
    if (n.isEmpty || p.length < 4) return;
    // Kontrollo nëse PIN ekziston
    if (waiters.any((w) => w.pin == p) || p == '9999') return;
    waiters.add(WaiterInfo(name: n, pin: p));
    notifyListeners();
  }

  void removeWaiterAt(int index) {
    if (index < 0 || index >= waiters.length) {
      return;
    }
    waiters.removeAt(index);
    notifyListeners();
  }

  WaiterInfo? findWaiterByPin(String pin) {
    try {
      return waiters.firstWhere((w) => w.pin == pin);
    } catch (_) {
      return null;
    }
  }

  // —— Shpenzime / rroga ——
  final List<ExpenseRow> expenses = <ExpenseRow>[];

  void addExpense(ExpenseRow row) {
    expenses.add(row);
    notifyListeners();
  }

  void removeExpenseAt(int index) {
    if (index < 0 || index >= expenses.length) {
      return;
    }
    expenses.removeAt(index);
    notifyListeners();
  }

  double get totalExpenses =>
      expenses.fold<double>(0, (s, e) => s + e.amount);

  // —— Fitime (demo + shpenzime) ——
  static const double _baseDaily = 1850;
  static const double _baseWeekly = 11200;
  static const double _baseMonthly = 46800;

  double profitDaily() => _baseDaily - totalExpenses * 0.15;

  double profitWeekly() => _baseWeekly - totalExpenses;

  double profitMonthly() => _baseMonthly - totalExpenses * 2.2;

  // —— Top puntor (dinamik) ——
  final Map<String, double> waiterSales = {};

  void recordSale(String waiterName, double amount) {
    if (waiterName.trim().isEmpty) return;
    waiterSales[waiterName] = (waiterSales[waiterName] ?? 0) + amount;
    notifyListeners();
  }

  void clearWaiterSales() {
    waiterSales.clear();
    notifyListeners();
  }

  List<MapEntry<String, double>> get employeeSalesSorted {
    final entries = waiterSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  MapEntry<String, double> get topEmployee {
    if (waiterSales.isEmpty) {
      return const MapEntry('—', 0.0);
    }
    return waiterSales.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
  }

  // —— Menu / kategori ——
  List<CategoryData> _categories = [];

  List<CategoryData> get categories => List.unmodifiable(_categories);

  void addCategory(String name) {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
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

  void addProduct({
    required String categoryId,
    required String name,
    required double price,
    String emoji = '☕',
    String? imagePath,
  }) {
    final pid = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final product = ProductItem(
      id: pid,
      name: name.trim(),
      price: price,
      emoji: emoji,
      imagePath: imagePath,
    );
    _categories = _categories.map((c) {
      if (c.id != categoryId) {
        return c;
      }
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: [...c.products, product],
      );
    }).toList();
    notifyListeners();
  }

  void removeCategory(String categoryId) {
    _categories = _categories.where((c) => c.id != categoryId).toList();
    notifyListeners();
  }

  void removeProduct(String categoryId, String productId) {
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

  void editProduct(
    String categoryId,
    String productId, {
    String? name,
    double? price,
    String? imagePath,
    bool clearImage = false,
  }) {
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

  // —— Tavolina ——
  int tableCount = 15;
  int tablesPerRow = 6;

  List<TableInfo> _cashierTables = [];

  List<TableInfo> get cashierTables => List.unmodifiable(_cashierTables);

  void _syncTablesFromSettings() {
    final mockById = {for (final t in mockTables) t.id: t};
    _cashierTables = [
      for (var i = 1; i <= tableCount; i++)
        mockById[i] ?? TableInfo(id: i, occupied: false),
    ];
    notifyListeners();
  }

  void setTableLayout({required int count, required int perRow}) {
    tableCount = count.clamp(1, 48);
    tablesPerRow = perRow.clamp(2, 12);
    _syncTablesFromSettings();
  }

  void updateTableTotal(int tableId, double total) {
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(id: t.id, occupied: true, currentTotal: total);
    }).toList();
    notifyListeners();
  }

  void clearTable(int tableId) {
    _cashierTables = _cashierTables.map((t) {
      if (t.id != tableId) return t;
      return TableInfo(id: t.id, occupied: false);
    }).toList();
    notifyListeners();
  }

  void moveProduct(String fromCategoryId, String productId, String toCategoryId) {
    if (fromCategoryId == toCategoryId) return;
    ProductItem? product;
    for (final c in _categories) {
      if (c.id == fromCategoryId) {
        for (final p in c.products) {
          if (p.id == productId) {
            product = p;
            break;
          }
        }
        break;
      }
    }
    if (product == null) return;
    final prod = product;
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

  void addCashierTable() {
    final nextId = _cashierTables.isEmpty
        ? 1
        : _cashierTables.map((e) => e.id).reduce(math.max) + 1;
    _cashierTables = [
      ..._cashierTables,
      TableInfo(id: nextId, occupied: false),
    ];
    notifyListeners();
  }
}

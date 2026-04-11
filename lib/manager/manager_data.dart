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
  final List<String> waiters = <String>[];

  void addWaiter(String name) {
    final n = name.trim();
    if (n.isEmpty) {
      return;
    }
    waiters.add(n);
    notifyListeners();
  }

  void removeWaiterAt(int index) {
    if (index < 0 || index >= waiters.length) {
      return;
    }
    waiters.removeAt(index);
    notifyListeners();
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

  // —— Top puntor (demo) ——
  final List<MapEntry<String, double>> employeeSales = [
    const MapEntry('Ana M.', 2840),
    const MapEntry('Driton K.', 2310),
    const MapEntry('Elona S.', 1980),
    const MapEntry('Blerim H.', 1650),
  ];

  MapEntry<String, double> get topEmployee {
    if (employeeSales.isEmpty) {
      return const MapEntry('—', 0.0);
    }
    return employeeSales.reduce(
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
  }) {
    final pid = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final product = ProductItem(
      id: pid,
      name: name.trim(),
      price: price,
      emoji: emoji,
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

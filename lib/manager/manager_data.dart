import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../models/pos_models.dart';
import '../services/audit_log_service.dart';
import '../services/database_service.dart';

export '../models/pos_models.dart';

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

  // ── ESC/POS + receipt settings ─────────────────────────────────────────────

  bool useEscPos          = true;
  bool cashDrawerEnabled  = false;
  int  paperWidthMm       = 80;
  String receiptFooter    = 'Ju Faleminderit!';
  String? businessAddress;
  String? businessPhone;

  // ── shift ──────────────────────────────────────────────────────────────────

  bool shiftOpen = false;
  DateTime? shiftOpenedAt;
  DateTime? shiftClosedAt;

  /// Primary key of the currently open shift in the [shifts] table.
  /// Null only during the brief window before [_init] completes.
  int? _currentShiftId;
  int? get currentShiftId => _currentShiftId;

  bool _shiftClosingInProgress = false;
  bool get isShiftClosing => _shiftClosingInProgress;

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
      useEscPos         = ((company['useEscPos']         as int?) ?? 1) == 1;
      cashDrawerEnabled = ((company['cashDrawerEnabled'] as int?) ?? 0) == 1;
      paperWidthMm      = (company['paperWidthMm']       as int?) ?? 80;
      receiptFooter     = (company['receiptFooter']  as String?) ?? 'Ju Faleminderit!';
      businessAddress   = company['businessAddress'] as String?;
      businessPhone     = company['businessPhone']   as String?;
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
    final old = companyName;
    companyName = name.trim();
    await DatabaseService.instance.updateCompanyName(companyName!);
    AuditLogService.instance.logCompanyNameChanged(oldName: old, newName: companyName!);
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

  /// Persist ESC/POS + receipt settings. Pass only the fields you want to change.
  Future<void> saveEscPosSettings({
    bool? useEscPos,
    bool? cashDrawerEnabled,
    int? paperWidthMm,
    String? receiptFooter,
    String? businessAddress,
    String? businessPhone,
  }) async {
    if (useEscPos != null)         this.useEscPos         = useEscPos;
    if (cashDrawerEnabled != null) this.cashDrawerEnabled = cashDrawerEnabled;
    if (paperWidthMm != null)      this.paperWidthMm      = paperWidthMm;
    if (receiptFooter != null)     this.receiptFooter     = receiptFooter;
    if (businessAddress != null)   this.businessAddress   = businessAddress;
    if (businessPhone != null)     this.businessPhone     = businessPhone;
    await DatabaseService.instance.updateEscPosSettings(
      useEscPos:         useEscPos,
      cashDrawerEnabled: cashDrawerEnabled,
      paperWidthMm:      paperWidthMm,
      receiptFooter:     receiptFooter,
      businessAddress:   businessAddress,
      businessPhone:     businessPhone,
    );
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
    AuditLogService.instance.logShiftOpened(shiftId: _currentShiftId!);
    waiterSales = {};
    notifyListeners();
  }

  String _normWaiterName(String raw) {
    final n = raw.trim();
    return n.isEmpty ? 'Panjohur' : n;
  }

  /// Raport i gjallë: shitje të paguara me [shiftId] aktiv + porosi të hapura
  /// nga [current_orders] (jo anuluar — ato nuk janë në këto burime).
  Future<ShiftStatusReport> computeShiftStatusReport() async {
    final sid = _currentShiftId;
    final now = DateTime.now();
    final paidByWaiter = <String, double>{};
    final paidCountByWaiter = <String, int>{};
    final saleIdsInShift = <int>[];

    for (final s in _salesHistory) {
      if (sid == null) break;
      if (s.shiftId != sid) continue;
      final name = _normWaiterName(s.waiterName);
      paidByWaiter[name] = (paidByWaiter[name] ?? 0) + s.total;
      paidCountByWaiter[name] = (paidCountByWaiter[name] ?? 0) + 1;
      if (s.dbId != null) saleIdsInShift.add(s.dbId!);
    }

    if (saleIdsInShift.isNotEmpty) {
      final adjRows =
          await DatabaseService.instance.fetchAdjustmentsForSales(saleIdsInShift);
      final saleById = <int, SaleRow>{};
      for (final s in _salesHistory) {
        if (s.dbId != null) saleById[s.dbId!] = s;
      }
      for (final r in adjRows) {
        final saleId = (r['saleId'] as num).toInt();
        final sale = saleById[saleId];
        if (sale == null || sid == null || sale.shiftId != sid) continue;
        final name = _normWaiterName(sale.waiterName);
        final amt = (r['amount'] as num).toDouble();
        paidByWaiter[name] = (paidByWaiter[name] ?? 0) + amt;
      }
    }

    final openMap =
        await DatabaseService.instance.fetchCurrentOrderTotalsByWaiter();
    final openCountMap =
        await DatabaseService.instance.fetchCurrentOrderCountsByWaiter();

    final names = <String>{
      ..._waiters.map((w) => _normWaiterName(w.name)),
      ...paidByWaiter.keys,
      ...openMap.keys,
    };

    final byWaiter = <String, ShiftWorkerBreakdown>{};
    for (final name in names) {
      byWaiter[name] = ShiftWorkerBreakdown(
        paidTotal: paidByWaiter[name] ?? 0,
        openTotal: openMap[name] ?? 0,
        paidOrderCount: paidCountByWaiter[name] ?? 0,
        openOrderCount: openCountMap[name] ?? 0,
      );
    }

    return ShiftStatusReport(
      shiftId: sid,
      generatedAt: now,
      byWaiter: byWaiter,
    );
  }

  /// Archives the current shift, resets waiter totals, and keeps the system
  /// active. Historical sales and line items are NEVER deleted.
  ///
  /// Para pastrimit ruhet snapshot-i (paguar + hapur) në rreshtin e shift-it.
  /// Nëse ruajtja dështon, shift-i mbetet aktiv dhe porositë e hapura intakte.
  Future<void> closeShift() async {
    if (_shiftClosingInProgress) return;
    final closingShiftId = _currentShiftId;
    if (closingShiftId == null) return;

    final db = DatabaseService.instance;
    final now = DateTime.now();

    _shiftClosingInProgress = true;
    try {
      final report = await computeShiftStatusReport();
      final shiftExpensesTotal = _expenses
          .where((e) => e.shiftId == closingShiftId)
          .fold<double>(0, (sum, e) => sum + e.amount);
      final shiftGrandTotal = report.grandTotal;
      final snapshotJson = jsonEncode(report.toJson());

      await db.closeShiftRecord(
        shiftId: closingShiftId,
        closedAt: now,
        totalSales: shiftGrandTotal,
        totalExpenses: shiftExpensesTotal,
        netProfit: shiftGrandTotal - shiftExpensesTotal,
        snapshotJson: snapshotJson,
      );

      shiftClosedAt = now;

      await db.updateShift(
        openedAt: null,
        closedAt: now.toIso8601String(),
        status: 'open',
      );

      AuditLogService.instance.logShiftClosed(
        shiftId: closingShiftId,
        totalSales: shiftGrandTotal,
        totalExpenses: shiftExpensesTotal,
      );

      _currentShiftId = await db.insertShiftRecord(openedAt: now);
      AuditLogService.instance.logShiftOpened(shiftId: _currentShiftId!);
      shiftOpenedAt = now;

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
      await _reloadSales(db);
      notifyListeners();
    } catch (e, st) {
      debugPrint('closeShift failed: $e\n$st');
      rethrow;
    } finally {
      _shiftClosingInProgress = false;
    }
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
    AuditLogService.instance.logWaiterAdded(waiterName: n);
    notifyListeners();
  }

  Future<void> removeWaiterAt(int index) async {
    if (index < 0 || index >= _waiters.length) return;
    final w = _waiters[index];
    if (w.dbId != null) {
      await DatabaseService.instance.deleteWaiterById(w.dbId!);
    }
    AuditLogService.instance.logWaiterRemoved(waiterName: w.name);
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
    AuditLogService.instance.logExpenseAdded(
      expenseId: newId,
      type:      row.type,
      description: row.description,
      amount:    row.amount,
      shiftId:   _currentShiftId,
    );
    notifyListeners();
  }

  Future<void> removeExpenseAt(int index) async {
    if (index < 0 || index >= _expenses.length) return;
    final e = _expenses[index];
    if (e.dbId != null) {
      await DatabaseService.instance.deleteExpenseById(e.dbId!);
    }
    AuditLogService.instance.logExpenseDeleted(
      expenseId:   e.dbId ?? 0,
      description: e.description,
      amount:      e.amount,
      shiftId:     e.shiftId,
    );
    _expenses.removeAt(index);
    notifyListeners();
  }

  double get totalExpenses => _expenses.fold<double>(0, (s, e) => s + e.amount);

  // ─────────────────────────── salaries ─────────────────────────────────────

  double getSalary(String waiterName) => _salaries[waiterName] ?? 0.0;

  Future<void> setSalary(String waiterName, double dailyRate) async {
    final old = _salaries[waiterName];
    await DatabaseService.instance.upsertWaiterSalary(waiterName, dailyRate);
    _salaries = {..._salaries, waiterName: dailyRate};
    AuditLogService.instance.logSalaryChanged(
      waiterName: waiterName,
      oldRate:    old,
      newRate:    dailyRate,
    );
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
      shiftId: _currentShiftId,
    );
    final sale = SaleRow(
      waiterName: waiterName,
      tableId: tableId,
      total: amount,
      timestamp: now,
      shiftId: _currentShiftId,
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
    AuditLogService.instance.logSale(
      waiterName: waiterName,
      saleId:     saleId,
      tableId:    tableId,
      total:      total,
      itemCount:  lines.length,
      shiftId:    _currentShiftId,
    );
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
    AuditLogService.instance.logAdjustment(
      adjustmentType: adjustmentType,
      saleId:         saleId,
      amount:         amount,
      reason:         reason,
      performedBy:    createdBy,
      shiftId:        _currentShiftId,
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
    AuditLogService.instance.logCategoryCreated(
      categoryId:   id,
      categoryName: name.trim(),
    );
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
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryData(id: categoryId, name: '', icon: Icons.category, products: []),
    );
    await DatabaseService.instance.deleteCategory(categoryId);
    _categories = _categories.where((c) => c.id != categoryId).toList();
    AuditLogService.instance.logCategoryDeleted(
      categoryId:   categoryId,
      categoryName: cat.name,
    );
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
    final catName = _categories
        .firstWhere((c) => c.id == categoryId, orElse: () => CategoryData(id: '', name: '', icon: Icons.category, products: []))
        .name;
    AuditLogService.instance.logProductCreated(
      productId:    pid,
      productName:  name.trim(),
      price:        price,
      categoryName: catName,
    );
    notifyListeners();
  }

  Future<void> removeProduct(String categoryId, String productId) async {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryData(id: '', name: '', icon: Icons.category, products: []),
    );
    final prod = cat.products.firstWhere(
      (p) => p.id == productId,
      orElse: () => ProductItem(id: productId, name: '', price: 0, emoji: ''),
    );
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
    AuditLogService.instance.logProductDeleted(
      productId:    productId,
      productName:  prod.name,
      categoryName: cat.name,
    );
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
    // Capture old values before update for audit snapshot.
    ProductItem? oldProduct;
    for (final c in _categories) {
      if (c.id == categoryId) {
        try { oldProduct = c.products.firstWhere((p) => p.id == productId); } catch (_) {}
        break;
      }
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

    AuditLogService.instance.logProductEdited(
      productId:   productId,
      productName: name ?? oldProduct?.name ?? productId,
      oldValues:   {
        if (oldProduct != null && name  != null) 'name':  oldProduct.name,
        if (oldProduct != null && price != null) 'price': oldProduct.price,
      },
      newValues: {
        if (name  != null) 'name':  name,
        if (price != null) 'price': price,
      },
    );
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

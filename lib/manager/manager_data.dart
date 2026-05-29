import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../models/mock_data.dart';
import '../models/pos_models.dart';
import '../models/sale_insert_result.dart';
import '../repositories/expense_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/salary_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/shift_repository.dart';
import '../services/audit_log_service.dart';
import '../services/database_service.dart';
import '../services/license_gate_service.dart';
export '../models/pos_models.dart';

part 'manager_data_sales.dart';
part 'manager_data_menu.dart';
part 'manager_data_tables.dart';
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

  // ── admin PIN (hashed) ─────────────────────────────────────────────────────

  String? _adminPinHash;
  String? _adminPinSalt;

  // ── company ────────────────────────────────────────────────────────────────

  String? companyName;
  Uint8List? companyLogoBytes;
  String loginMode = 'PINMODE';

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
  List<ManagerInfo> _managers = [];
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
  List<ManagerInfo> get managers => List.unmodifiable(_managers);
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
      final storedMode = (company['loginMode'] as String?) ?? 'PINMODE';
      loginMode = storedMode == 'NAMEMODE' ? 'PINMODE' : storedMode;
      if (storedMode == 'NAMEMODE') {
        await db.updateLoginMode('PINMODE');
      }
      selectedPrinterName = company['printerName'] as String?;
      useEscPos         = ((company['useEscPos']         as int?) ?? 1) == 1;
      cashDrawerEnabled = ((company['cashDrawerEnabled'] as int?) ?? 0) == 1;
      paperWidthMm      = (company['paperWidthMm']       as int?) ?? 80;
      receiptFooter     = (company['receiptFooter']  as String?) ?? 'Ju Faleminderit!';
      businessAddress   = company['businessAddress'] as String?;
      businessPhone     = company['businessPhone']   as String?;
      _adminPinHash     = company['adminPinHash']    as String?;
      _adminPinSalt     = company['adminPinSalt']    as String?;
    }

    // Shift — ensure a permanent shift record exists in [shifts] table.
    shiftOpen = true;
    await _ensureOpenShift();

    // Waiters
    final waiterRows = await db.fetchWaiters();
    _waiters = waiterRows.map(WaiterInfo.fromMap).toList();
    await _migrateWaiterPins();
    await _loadManagers();
    await _backfillMissingPinViews();

    // Categories + products
    await db.ensureDefaultMenuPresent();
    await _reloadMenu();

    // Tables — rikthe nga porosi aktive, pastaj parazgjedhja nëse DB bosh.
    await db.reconcileTablesWithActiveOrders();
    await db.ensureDefaultTables(
      count: tableCount.clamp(1, 48),
    );
    await _reloadTablesFromDb();

    // Expenses
    final expenseRows = await ExpenseRepository.instance.fetchExpenses();
    _expenses = expenseRows.map(ExpenseRow.fromMap).toList();

    // Sales → rebuild waiterSales map (current shift only)
    await _reloadSales();

    // Salaries + advances
    _salaries = await SalaryRepository.instance.fetchAllSalaries();
    final advanceRows = await SalaryRepository.instance.fetchAdvances();
    _advances = advanceRows.map(AdvanceRow.fromMap).toList();

    // Worked days
    final workedRows = await SalaryRepository.instance.fetchWorkedDays();
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
    isLoading = true;
    notifyListeners();
    try {
      await _init();
    } catch (e, st) {
      debugPrint('ManagerData.reload failed: $e\n$st');
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Ngarkon tavolinat nga DB; rikthen nga porositë aktive; nuk fshin fatura.
  Future<void> ensureTablesLoaded() async {
    final db = DatabaseService.instance;
    await db.reconcileTablesWithActiveOrders();
    await db.ensureDefaultTables(
      count: tableCount.clamp(1, 48),
    );
    await _reloadTablesFromDb();
  }

  Future<void> _reloadTablesFromDb() async {
    final tableRows = await DatabaseService.instance.fetchTables();
    _cashierTables = tableRows.map(TableInfo.fromMap).toList();
    tableCount = _cashierTables.isNotEmpty
        ? _cashierTables.length
        : DatabaseService.defaultTableCount;
    if (_cashierTables.isEmpty) {
      await DatabaseService.instance.ensureDefaultTables(
        count: tableCount,
      );
      final again = await DatabaseService.instance.fetchTables();
      _cashierTables = again.map(TableInfo.fromMap).toList();
      tableCount = _cashierTables.length;
    }
  }

  /// Reloads categories and their products from the DB.
  Future<void> _reloadMenu() async {
    final catRows = await ProductRepository.instance.fetchCategories();
    final prodRows = await ProductRepository.instance.fetchProducts();

    // Group products by categoryId, sorted by sortOrder.
    final byCategory = <String, List<ProductItem>>{};
    for (final row in prodRows) {
      final catId = row['categoryId'] as String;
      byCategory.putIfAbsent(catId, () => []).add(ProductItem.fromMap(row));
    }
    for (final list in byCategory.values) {
      list.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    }

    _categories = catRows
        .map((r) => CategoryData.fromMap(r, byCategory[r['id']] ?? []))
        .toList();
  }

  /// Rebuilds [_salesHistory] (all-time) and [waiterSales] (current shift only).
  Future<void> _reloadSales() async {
    final rows = await SalesRepository.instance.fetchSales();
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
  Future<void> _ensureOpenShift() async {
    final open = await ShiftRepository.instance.fetchOpenShift();
    if (open != null) {
      _currentShiftId = (open['id'] as num).toInt();
      final oa = open['openedAt'] as String?;
      shiftOpenedAt = oa != null ? DateTime.tryParse(oa) : null;
    } else {
      // Auto-create a shift so the system is always in a valid state.
      final now = DateTime.now();
      _currentShiftId =
          await ShiftRepository.instance.insertShiftRecord(openedAt: now);
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
    if (mode != 'PINMODE') return;
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
    LicenseGateService.instance.enforceOrThrow();
    shiftOpen = true;
    shiftOpenedAt = DateTime.now();
    shiftClosedAt = null;
    // Legacy singleton shift record (kept for backward compat with older UI).
    await ShiftRepository.instance.updateShift(
      openedAt: shiftOpenedAt!.toIso8601String(),
      closedAt: null,
      status: 'open',
    );
    // Permanent shift archive — open a new record in [shifts] table.
    _currentShiftId = await ShiftRepository.instance.insertShiftRecord(
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
      final adjRows = await SalesRepository.instance.fetchAdjustmentsForSales(
        saleIdsInShift,
      );
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
    LicenseGateService.instance.enforceOrThrow();
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

      await ShiftRepository.instance.closeShiftRecord(
        shiftId: closingShiftId,
        closedAt: now,
        totalSales: shiftGrandTotal,
        totalExpenses: shiftExpensesTotal,
        netProfit: shiftGrandTotal - shiftExpensesTotal,
        snapshotJson: snapshotJson,
      );

      shiftClosedAt = now;

      await ShiftRepository.instance.updateShift(
        openedAt: null,
        closedAt: now.toIso8601String(),
        status: 'open',
      );

      AuditLogService.instance.logShiftClosed(
        shiftId: closingShiftId,
        totalSales: shiftGrandTotal,
        totalExpenses: shiftExpensesTotal,
      );

      _currentShiftId =
          await ShiftRepository.instance.insertShiftRecord(openedAt: now);
      AuditLogService.instance.logShiftOpened(shiftId: _currentShiftId!);
      shiftOpenedAt = now;

      await db.clearAllCurrentOrdersAndResetTables();
      await db.resetOrderNumberCountersForNewShift();
      waiterSales = {};
      await _reloadTablesFromDb();
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
      await _reloadSales();
      notifyListeners();
    } catch (e, st) {
      debugPrint('closeShift failed: $e\n$st');
      rethrow;
    } finally {
      _shiftClosingInProgress = false;
    }
  }

  // ─────────────────────────── admin auth ───────────────────────────────────

  /// True when an admin PIN has been set in SQLite.
  bool get hasAdminPin => _adminPinHash != null && _adminPinSalt != null;

  /// Compares [pin] against the stored SHA-256 hash. Returns false if no PIN is set.
  Future<bool> verifyAdminPin(String pin) async {
    if (_adminPinHash == null || _adminPinSalt == null) return false;
    return _hashPin(pin, _adminPinSalt!) == _adminPinHash;
  }

  /// Hashes [pin] with a new random salt and stores both in SQLite.
  Future<void> setAdminPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await DatabaseService.instance.updateAdminPin(hash, salt, pinView: pin);
    _adminPinHash = hash;
    _adminPinSalt = salt;
    notifyListeners();
  }

  static String _generateSalt() {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPin(String pin, String salt) {
    final combined = utf8.encode(pin + salt);
    return sha256.convert(combined).toString();
  }

  // ─────────────────────────── waiters ──────────────────────────────────────

  Future<void> _migrateWaiterPins() async {
    bool migrated = false;
    for (int i = 0; i < _waiters.length; i++) {
      final w = _waiters[i];
      if (w.isHashed || w.dbId == null || w.pin.isEmpty) continue;
      final salt = _generateSalt();
      final hash = _hashPin(w.pin, salt);
      final plainPin = w.pin.trim();
      await DatabaseService.instance.updateWaiterPin(
        w.dbId!,
        hash,
        salt,
        pinView: plainPin,
      );
      _waiters[i] = WaiterInfo(
        dbId: w.dbId,
        name: w.name,
        pin: hash,
        pinHash: hash,
        pinSalt: salt,
        pinUpdatedAt: DateTime.now().toIso8601String(),
        pinView: plainPin,
      );
      migrated = true;
    }
    if (migrated) notifyListeners();
  }

  Future<void> addWaiter(String name, String pin) async {
    final n = name.trim();
    final p = pin.trim();
    if (n.isEmpty || p.length < 4) return;
    if (await staffPinExists(p)) return;

    final salt = _generateSalt();
    final hash = _hashPin(p, salt);
    final now = DateTime.now().toIso8601String();
    final newId = await DatabaseService.instance.insertWaiter(
      n,
      hash,
      salt,
      pinView: p,
    );
    _waiters.add(WaiterInfo(
      dbId: newId,
      name: n,
      pin: hash,
      pinHash: hash,
      pinSalt: salt,
      pinUpdatedAt: now,
      pinView: p,
    ));
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

  Future<bool> _waiterPinExists(String pin) async {
    for (final w in _waiters) {
      if (w.isHashed && _hashPin(pin, w.pinSalt!) == w.pinHash) return true;
    }
    return false;
  }

  /// Returns true if [pin] is already used by staf (kamarier, menaxher, admin).
  Future<bool> waiterPinExists(String pin) => staffPinExists(pin);

  Future<WaiterInfo?> findWaiterByPin(String pin) async {
    for (final w in _waiters) {
      if (w.isHashed && _hashPin(pin, w.pinSalt!) == w.pinHash) return w;
    }
    return null;
  }

  /// Ruaj [pinView] pas hyrjes së suksesshme (staf i vjetër pa pinView).
  Future<void> rememberWaiterPinViewAtLogin(String waiterName, String pin) async {
    final i = _waiters.indexWhere((w) => w.name == waiterName);
    if (i < 0) return;
    await _saveWaiterPinViewIfMissing(i, pin.trim());
  }

  /// Verifikon PIN-in dhe ruan [pinView] që syri të funksionojë.
  Future<bool> revealWaiterPinAt(int index, String pin) =>
      _saveWaiterPinViewIfMissing(index, pin.trim());

  Future<bool> _saveWaiterPinViewIfMissing(int index, String pin) async {
    if (index < 0 || index >= _waiters.length) return false;
    final w = _waiters[index];
    if (w.pinView != null && w.pinView!.trim().isNotEmpty) return true;
    if (w.dbId == null || !w.isHashed || pin.length < 4) return false;
    if (_hashPin(pin, w.pinSalt!) != w.pinHash) return false;
    await DatabaseService.instance.updateWaiterPinViewOnly(w.dbId!, pin);
    _waiters[index] = WaiterInfo(
      dbId: w.dbId,
      name: w.name,
      pin: w.pin,
      pinHash: w.pinHash,
      pinSalt: w.pinSalt,
      pinUpdatedAt: w.pinUpdatedAt,
      pinView: pin,
    );
    notifyListeners();
    return true;
  }

  Future<void> _backfillMissingPinViews() async {
    var changed = false;
    for (int i = 0; i < _waiters.length; i++) {
      final w = _waiters[i];
      if (w.dbId == null) continue;
      if (w.pinView != null && w.pinView!.trim().isNotEmpty) continue;
      final legacy = w.pin.trim();
      if (legacy.length < 4 || !RegExp(r'^\d+$').hasMatch(legacy)) continue;
      if (w.isHashed && legacy == w.pinHash) continue;
      await DatabaseService.instance.updateWaiterPinViewOnly(w.dbId!, legacy);
      _waiters[i] = WaiterInfo(
        dbId: w.dbId,
        name: w.name,
        pin: w.pin,
        pinHash: w.pinHash,
        pinSalt: w.pinSalt,
        pinUpdatedAt: w.pinUpdatedAt,
        pinView: legacy,
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // ─────────────────────────── managers ─────────────────────────────────────

  Future<void> _loadManagers() async {
    final rows = await DatabaseService.instance.fetchManagers();
    _managers = rows.map(ManagerInfo.fromMap).toList();
  }

  Future<void> addManager(String name, String pin) async {
    final n = name.trim();
    final p = pin.trim();
    if (n.isEmpty || p.length < 4) return;
    if (await staffPinExists(p)) return;

    final salt = _generateSalt();
    final hash = _hashPin(p, salt);
    final now = DateTime.now().toIso8601String();
    final newId = await DatabaseService.instance.insertManager(
      n,
      hash,
      salt,
      pinView: p,
    );
    _managers.add(ManagerInfo(
      dbId: newId,
      name: n,
      pin: hash,
      pinHash: hash,
      pinSalt: salt,
      pinUpdatedAt: now,
      pinView: p,
    ));
    AuditLogService.instance.logManagerAdded(managerName: n);
    notifyListeners();
  }

  Future<void> removeManagerAt(int index) async {
    if (index < 0 || index >= _managers.length) return;
    final mgr = _managers[index];
    if (mgr.dbId != null) {
      await DatabaseService.instance.deleteManagerById(mgr.dbId!);
    }
    AuditLogService.instance.logManagerRemoved(managerName: mgr.name);
    _managers.removeAt(index);
    notifyListeners();
  }

  Future<bool> _managerPinExists(String pin) async {
    for (final m in _managers) {
      if (m.isHashed && _hashPin(pin, m.pinSalt!) == m.pinHash) return true;
    }
    return false;
  }

  Future<ManagerInfo?> findManagerByPin(String pin) async {
    for (final m in _managers) {
      if (m.isHashed && _hashPin(pin, m.pinSalt!) == m.pinHash) return m;
    }
    return null;
  }

  Future<bool> staffPinExists(String pin) async {
    if (await _waiterPinExists(pin)) return true;
    if (await _managerPinExists(pin)) return true;
    if (hasAdminPin && await verifyAdminPin(pin)) return true;
    return false;
  }

  bool get hasAnyManagerLogin => hasAdminPin || _managers.isNotEmpty;

  Future<bool> canAccessManagerDashboard(String pin) async {
    if (await verifyAdminPin(pin)) return true;
    return await findManagerByPin(pin) != null;
  }

  /// Ruaj pinView për menaxher ose admin legacy pas hyrjes.
  Future<void> rememberManagerPinViewAtLogin(String pin) async {
    final p = pin.trim();
    if (p.length < 4) return;
    final mgr = await findManagerByPin(p);
    if (mgr != null && mgr.dbId != null) {
      final i = _managers.indexWhere((m) => m.dbId == mgr.dbId);
      if (i >= 0) {
        await _saveManagerPinViewIfMissing(i, p);
      }
      return;
    }
    if (await verifyAdminPin(p)) {
      await DatabaseService.instance.updateAdminPinViewOnly(p);
    }
  }

  Future<bool> revealManagerPinAt(int index, String pin) =>
      _saveManagerPinViewIfMissing(index, pin.trim());

  Future<bool> _saveManagerPinViewIfMissing(int index, String pin) async {
    if (index < 0 || index >= _managers.length) return false;
    final mgr = _managers[index];
    if (mgr.pinView != null && mgr.pinView!.trim().isNotEmpty) return true;
    if (mgr.dbId == null || !mgr.isHashed || pin.length < 4) return false;
    if (_hashPin(pin, mgr.pinSalt!) != mgr.pinHash) return false;
    await DatabaseService.instance.updateManagerPinViewOnly(mgr.dbId!, pin);
    _managers[index] = ManagerInfo(
      dbId: mgr.dbId,
      name: mgr.name,
      pin: mgr.pin,
      pinHash: mgr.pinHash,
      pinSalt: mgr.pinSalt,
      pinUpdatedAt: mgr.pinUpdatedAt,
      pinView: pin,
    );
    notifyListeners();
    return true;
  }

  // ─────────────────────────── expenses ─────────────────────────────────────

  Future<void> addExpense(ExpenseRow row) async {
    final newId = await ExpenseRepository.instance.insertExpense(
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
      await ExpenseRepository.instance.deleteExpenseById(e.dbId!);
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
    await SalaryRepository.instance.upsertWaiterSalary(waiterName, dailyRate);
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
    final newId = await SalaryRepository.instance.insertAdvance(
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
    await SalaryRepository.instance.deleteAdvanceById(id);
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
    await SalaryRepository.instance.setWorkedDay(waiterName, key, nowWorked);
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

  Future<int> nextGlobalOrderNumber() async {
    return DatabaseService.instance.consumeNextGlobalOrderNumber();
  }

  /// Numri i radhës «Porosia #» për kamarierin (riniset kur mbyllhet gjendja).
  Future<int> nextWaiterOrderNumber(String waiterName) async {
    return DatabaseService.instance.consumeNextWaiterOrderNumber(waiterName);
  }

  void _notify() => notifyListeners();
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manager/manager_data.dart';
import '../services/database_service.dart';
import '../screens/audit_log_screen.dart';
import '../screens/sales_history_screen.dart';
import '../services/admin_session_service.dart';
import '../services/audit_log_service.dart';
import '../services/pin_rate_limiter.dart';
import '../services/app_language_service.dart';
import '../features/dashboard/panels/fiscal_settings_panel.dart';
import '../features/dashboard/panels/shift_panel.dart';
import '../features/dashboard/panels/staff_panel.dart';
import '../features/dashboard/panels/expenses_panel.dart';
import '../features/dashboard/panels/profits_panel.dart';
import '../features/dashboard/panels/top_employee_panel.dart';
import '../features/dashboard/panels/menu_panel.dart';
import '../features/dashboard/panels/tables_config_panel.dart';
import '../features/dashboard/panels/staff_payroll_panel.dart';
import '../features/dashboard/panels/overview_panel.dart';
import '../features/dashboard/panels/company_settings_panel.dart';
import '../features/dashboard/panels/permissions_panel.dart';
import '../features/dashboard/panels/refund_panel.dart';
import '../features/dashboard/panels/sales_daily_panel.dart';
import '../features/dashboard/widgets/manager_side_nav.dart';
import '../features/dashboard/widgets/manager_top_bar.dart';
import '../widgets/session_lock_dialog.dart';
import '../l10n/tr.dart';

/// Section headings, resolved per language on every read.
List<String> get _kSectionTitles => [
  tr.permbledhje,
  tr.gjendjaTurnit,
  AppLanguageService.instance.t('Stafi', 'Staff'),
  tr.shpenzime,
  tr.fitime,
  tr.shitjet,
  tr.realizimiSipasPunetoreve,
  tr.menu,
  tr.tavolinat,
  tr.cilesimet,
  AppLanguageService.instance.t('Permissions', 'Permissions'),
  tr.pagatAvans,
  tr.refund,
  tr.historikuShitjeve,
  tr.regjistriAuditit,
  AppLanguageService.instance.t('Fiskalizimi', 'Fiscalisation'),
];

final RegExp _pinDigits = RegExp(r'^\d+$');

/// Dashboard menaxheri.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerData _m = ManagerData.instance;
  final AppLanguageService _language = AppLanguageService.instance;
  final TextEditingController _headerSearchController = TextEditingController();
  late int _railIndex;
  bool _sidebarExpanded = true;
  static bool _desktopRealityDiagRan = false;

  // ── Session timeout ────────────────────────────────────────────────────────
  bool _sessionLocked = false;
  bool _lockDialogVisible = false;
  VoidCallback? _rebuildLockDialog;
  Timer? _activityTimer;
  final TextEditingController _lockPinController = TextEditingController();
  String? _lockErrorMsg;

  @override
  void initState() {
    super.initState();
    _railIndex = widget.initialIndex.clamp(0, _kSectionTitles.length - 1);
    _m.addListener(_onData);
    _language.addListener(_onLanguageChanged);

    AdminSessionService.instance.reset();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _activityTimer = Timer.periodic(
      const Duration(seconds: 1),
      _checkIdleTimeout,
    );
    if (kDebugMode && !_desktopRealityDiagRan) {
      _desktopRealityDiagRan = true;
      unawaited(DatabaseService.instance.runSalesParityDiagnostic());
    }
  }

  void _onData() => setState(() {});
  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _activityTimer?.cancel();
    _headerSearchController.dispose();
    _lockPinController.dispose();
    _m.removeListener(_onData);
    _language.removeListener(_onLanguageChanged);
    super.dispose();
  }

  // ── Activity detection ─────────────────────────────────────────────────────

  bool _onKeyEvent(KeyEvent event) {
    if (mounted && !_sessionLocked) {
      AdminSessionService.instance.recordActivity();
    }
    return false; // never consume — let normal key handling proceed
  }

  void _onPointerActivity() {
    if (_sessionLocked) return;
    AdminSessionService.instance.recordActivity();
  }

  // ── Idle check ─────────────────────────────────────────────────────────────

  void _checkIdleTimeout(Timer _) {
    if (!mounted) return;
    final justLocked = AdminSessionService.instance.checkAndLock();
    if (justLocked && !_sessionLocked) {
      AuditLogService.instance.logAdminSessionTimeout();
      _lockPinController.clear();
      setState(() {
        _sessionLocked = true;
        _lockErrorMsg = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentLockDialog();
      });
    } else if (_sessionLocked) {
      // Refresh lock dialog for PIN-rate-limiter countdown.
      _rebuildLockDialog?.call();
    }
  }

  void _presentLockDialog() {
    if (_lockDialogVisible || !mounted || !_sessionLocked) return;
    _lockDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                _rebuildLockDialog = () => setDialogState(() {});
                return Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: SessionLockDialogContent(
                    pinController: _lockPinController,
                    errorMessage: _lockErrorMsg,
                    rateLimited: PinRateLimiter.instance.isLocked,
                    lockoutSeconds:
                        PinRateLimiter.instance.lockoutSecondsRemaining,
                    onPinChanged: () {
                      if (_lockErrorMsg != null) {
                        setState(() => _lockErrorMsg = null);
                      }
                      _rebuildLockDialog?.call();
                    },
                    onSubmit: _unlockSession,
                    onCancel: () {
                      Navigator.of(dialogContext).pop();
                      _lockDialogVisible = false;
                      _rebuildLockDialog = null;
                      setState(() => _sessionLocked = false);
                      _exitToLogin();
                    },
                  ),
                );
              },
            ),
          );
        },
      ).whenComplete(() {
        _lockDialogVisible = false;
        _rebuildLockDialog = null;
      }),
    );
  }

  void _dismissLockDialog() {
    if (!_lockDialogVisible || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  // ── Re-authentication ──────────────────────────────────────────────────────

  Future<void> _unlockSession() async {
    if (PinRateLimiter.instance.isLocked) return;
    final pin = _lockPinController.text;
    if (pin.length < 4 || !_pinDigits.hasMatch(pin)) return;

    final valid = await ManagerData.instance.canAccessManagerDashboard(pin);
    _lockPinController.clear();

    if (valid) {
      PinRateLimiter.instance.reset();
      AdminSessionService.instance.unlock();
      AuditLogService.instance.logAdminSessionUnlocked();
      if (!mounted) return;
      setState(() {
        _sessionLocked = false;
        _lockErrorMsg = null;
      });
      _dismissLockDialog();
    } else {
      _rebuildLockDialog?.call();
      final lockedOut = PinRateLimiter.instance.recordFailure();
      if (lockedOut) AuditLogService.instance.logPinLockout();
      AuditLogService.instance.logFailedPin();
      if (!mounted) return;
      setState(() {
        _lockErrorMsg = PinRateLimiter.instance.isLocked
            ? trf.tooManyAttemptsRetryIn(PinRateLimiter.instance.lockoutSecondsRemaining)
            : trf.wrongPinAttemptsLeft(PinRateLimiter.instance.remainingAttempts);
      });
      _rebuildLockDialog?.call();
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _exitToLogin() {
    AdminSessionService.instance.reset();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: (_) => _onPointerActivity(),
      onPointerMove: (_) => _onPointerActivity(),
      onPointerSignal: (_) => _onPointerActivity(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: scheme.surfaceContainerLowest,
            body: Row(
              children: [
                ClipRect(
                  child: ManagerSideNav(
                    expanded: _sidebarExpanded,
                    selectedIndex: _railIndex,
                    onToggle: () =>
                        setState(() => _sidebarExpanded = !_sidebarExpanded),
                    onDestinationSelected: (i) =>
                        setState(() => _railIndex = i),
                    onLogout: _exitToLogin,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ManagerTopBar(
                        sectionTitle: _kSectionTitles[_railIndex],
                        m: _m,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1520),
                              child: _buildSection(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (_railIndex) {
      case 0:
        return OverviewPanel(
          m: _m,
          onNavigate: (i) => setState(() => _railIndex = i),
        );
      case 1:
        return ShiftPanel(m: _m);
      case 2:
        return StaffPanel(m: _m);
      case 3:
        return ExpensesPanel(m: _m);
      case 4:
        return ProfitsPanel(m: _m);
      case 5:
        return SalesDailyPanel(m: _m);
      case 6:
        return TopEmployeePanel(m: _m);
      case 7:
        return MenuPanel(m: _m);
      case 8:
        return TablesConfigPanel(m: _m);
      case 9:
        return CompanySettingsPanel(m: _m);
      case 10:
        return PermissionsPanel(m: _m);
      case 11:
        return StaffPayrollPanel(m: _m);
      case 12:
        return RefundPanel(m: _m);
      case 13:
        return const SalesHistoryPanel();
      case 14:
        return const AuditLogPanel();
      case 15:
        return const FiscalSettingsPanel();
      default:
        return const SizedBox.shrink();
    }
  }
}

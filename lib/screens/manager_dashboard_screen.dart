import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manager/manager_data.dart';
import '../screens/audit_log_screen.dart';
import '../screens/sales_history_screen.dart';
import '../services/admin_session_service.dart';
import '../services/audit_log_service.dart';
import '../services/pin_rate_limiter.dart';
import '../theme/app_colors.dart';
import '../features/dashboard/panels/shift_panel.dart';
import '../features/dashboard/panels/waiters_panel.dart';
import '../features/dashboard/panels/expenses_panel.dart';
import '../features/dashboard/panels/profits_panel.dart';
import '../features/dashboard/panels/reports_panel.dart';
import '../features/dashboard/panels/top_employee_panel.dart';
import '../features/dashboard/panels/menu_panel.dart';
import '../features/dashboard/panels/tables_config_panel.dart';
import '../features/dashboard/panels/staff_payroll_panel.dart';
import '../features/dashboard/panels/overview_panel.dart';
import '../features/dashboard/panels/company_settings_panel.dart';
import '../features/dashboard/panels/refund_panel.dart';
import '../features/dashboard/panels/sales_daily_panel.dart';
import '../features/dashboard/widgets/manager_side_nav.dart';
import '../features/dashboard/widgets/manager_top_bar.dart';


const _kSectionTitles = <String>[
  'Overview',
  'Shift',
  'Staff',
  'Expenses',
  'Profits',
  'Shitjet',
  'Reports',
  'Leaderboard',
  'Menu',
  'Tavolinat',
  'Cilësimet e Kompanisë',
  'Pagat & Avans',
  'Refund — Porositë e Printuara',
  'Historiku i Shitjeve',
  'Regjistri i Auditit',
];

final RegExp _pinDigits = RegExp(r'^\d+$');

/// Dashboard menaxheri.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerData _m = ManagerData.instance;
  final TextEditingController _headerSearchController = TextEditingController();
  late int _railIndex;
  bool _sidebarExpanded = true;

  // ── Session timeout ────────────────────────────────────────────────────────
  bool _sessionLocked = false;
  Timer? _activityTimer;
  final TextEditingController _lockPinController = TextEditingController();
  final FocusNode _lockPinFocus = FocusNode();
  String? _lockErrorMsg;

  @override
  void initState() {
    super.initState();
    _railIndex = widget.initialIndex;
    _m.addListener(_onData);

    AdminSessionService.instance.reset();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _activityTimer = Timer.periodic(
      const Duration(seconds: 1),
      _checkIdleTimeout,
    );
    _lockPinController.addListener(() => setState(() {}));
  }

  void _onData() => setState(() {});

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _activityTimer?.cancel();
    _headerSearchController.dispose();
    _lockPinController.dispose();
    _lockPinFocus.dispose();
    _m.removeListener(_onData);
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
        if (mounted) _lockPinFocus.requestFocus();
      });
    } else if (_sessionLocked) {
      // Refresh every second so the PIN-rate-limiter countdown stays current.
      setState(() {});
    }
  }

  // ── Re-authentication ──────────────────────────────────────────────────────

  Future<void> _unlockSession() async {
    if (PinRateLimiter.instance.isLocked) return;
    final pin = _lockPinController.text;
    if (pin.length < 4 || !_pinDigits.hasMatch(pin)) return;

    final valid = await ManagerData.instance.verifyAdminPin(pin);
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
    } else {
      final lockedOut = PinRateLimiter.instance.recordFailure();
      if (lockedOut) AuditLogService.instance.logPinLockout();
      AuditLogService.instance.logFailedPin();
      if (!mounted) return;
      setState(() {
        _lockErrorMsg = PinRateLimiter.instance.isLocked
            ? 'Shumë tentativa. Provo pas ${PinRateLimiter.instance.lockoutSecondsRemaining}s.'
            : 'PIN i gabuar. ${PinRateLimiter.instance.remainingAttempts} tentativa të mbetur.';
      });
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
    return Listener(
      onPointerDown: (_) => _onPointerActivity(),
      onPointerMove: (_) => _onPointerActivity(),
      onPointerSignal: (_) => _onPointerActivity(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.beige,
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
                          padding: const EdgeInsets.all(32),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 1440),
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
          if (_sessionLocked) _buildLockOverlay(),
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
        return WaitersPanel(m: _m);
      case 3:
        return ExpensesPanel(m: _m);
      case 4:
        return ProfitsPanel(m: _m);
      case 5:
        return SalesDailyPanel(m: _m);
      case 6:
        return ReportsPanel(m: _m);
      case 7:
        return TopEmployeePanel(m: _m);
      case 8:
        return MenuPanel(m: _m);
      case 9:
        return TablesConfigPanel(m: _m);
      case 10:
        return CompanySettingsPanel(m: _m);
      case 11:
        return StaffPayrollPanel(m: _m);
      case 12:
        return RefundPanel(m: _m);
      case 13:
        return const SalesHistoryPanel();
      case 14:
        return const AuditLogPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Lock overlay ───────────────────────────────────────────────────────────

  Widget _buildLockOverlay() {
    final rateLimited = PinRateLimiter.instance.isLocked;
    final pinText = _lockPinController.text;
    final canSubmit = !rateLimited &&
        pinText.length >= 4 &&
        _pinDigits.hasMatch(pinText);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.lightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 36,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sesioni u Bllokua',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vendos PIN-in e administratorit për të vazhduar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _lockPinController,
                    focusNode: _lockPinFocus,
                    obscureText: true,
                    obscuringCharacter: '•',
                    keyboardType: TextInputType.number,
                    enabled: !rateLimited,
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() => _lockErrorMsg = null),
                    onSubmitted: (_) => _unlockSession(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      color: AppColors.darkGreenText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'PIN',
                      hintStyle: TextStyle(
                        fontSize: 18,
                        color: AppColors.lightGreenText.withValues(alpha: 0.7),
                      ),
                      filled: true,
                      fillColor: AppColors.beige,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGreenBorderEmpty(),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGreenBorderEmpty(),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.lightGreenBorderEmpty(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (rateLimited) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.negativeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.negativeText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Shumë tentativa. Provo pas ${PinRateLimiter.instance.lockoutSecondsRemaining}s.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.negativeText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_lockErrorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _lockErrorMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF856404),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _unlockSession : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.lightGreenBg,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Shkyç',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _exitToLogin,
                    child: const Text(
                      'Dil nga sistemi',
                      style: TextStyle(color: AppColors.mediumGreenText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

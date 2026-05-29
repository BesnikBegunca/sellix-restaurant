import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manager/manager_data.dart';
import '../services/audit_log_service.dart';
import '../services/pin_rate_limiter.dart';
import '../theme/app_colors.dart';

import 'manager_dashboard_screen.dart';
import 'table_selection_screen.dart';

class _PinInputDialog extends StatefulWidget {
  const _PinInputDialog({
    required this.title,
    required this.hint,
    required this.onSubmit,
  });

  final String title;
  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _enabled => _controller.text.length >= 4;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: widget.hint,
                counterText: '',
              ),
              autofocus: true,
              onSubmitted: (_) {
                if (_enabled) {
                  widget.onSubmit(_controller.text);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_enabled) widget.onSubmit(_controller.text);
                    },
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Waiter Selection Screen
class WaiterSelectionScreen extends StatefulWidget {
  const WaiterSelectionScreen({super.key});

  @override
  State<WaiterSelectionScreen> createState() => _WaiterSelectionScreenState();
}

class _WaiterSelectionScreenState extends State<WaiterSelectionScreen> {
  final ManagerData _m = ManagerData.instance;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _m.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  void _selectWaiter(String waiterName) {
    AuditLogService.instance.logWaiterLogin(waiterName: waiterName);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TableSelectionScreen(waiterName: waiterName),
      ),
    );
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showAdminPinSetupDialog(String pin) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfiguro PIN e Administratorit'),
        content: const Text(
          'Nuk është konfiguruar asnjë PIN i administratorit.\n'
          'Dëshironi ta vendosni këtë PIN si PIN-in e administratorit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () async {
              // Capture navigator before async gap to satisfy lint.
              final nav = Navigator.of(context);
              Navigator.of(ctx).pop();
              await ManagerData.instance.addManager('Administrator', pin);
              await ManagerData.instance.setAdminPin(pin);
              if (!mounted) return;
              AuditLogService.instance.logManagerLogin();
              nav.push(
                MaterialPageRoute(
                  builder: (_) => const ManagerDashboardScreen(),
                ),
              );
            },
            child: const Text('Konfirmo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiters = _m.waiters;

    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: const Text('Select Waiter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToLogin,
        ),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogCtx) {
                  return _PinInputDialog(
                    title: 'Admin PIN',
                    hint: 'Enter admin PIN',
                    onSubmit: (pin) async {
                      // Capture before async gaps to satisfy lint.
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      // Lockout check — close dialog and show message.
                      if (PinRateLimiter.instance.isLocked) {
                        Navigator.of(dialogCtx).pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Shumë tentativa të gabuara. Provo përsëri pas ${PinRateLimiter.instance.lockoutSecondsRemaining}s.',
                            ),
                            backgroundColor: AppColors.negativeText,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.of(dialogCtx).pop();

                      if (!ManagerData.instance.hasAnyManagerLogin) {
                        if (!mounted) return;
                        _showAdminPinSetupDialog(pin);
                        return;
                      }

                      if (await ManagerData.instance.canAccessManagerDashboard(pin)) {
                        PinRateLimiter.instance.reset();
                        AuditLogService.instance.logManagerLogin();
                        if (!mounted) return;
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => const ManagerDashboardScreen(),
                          ),
                        );
                      } else {
                        final lockedOut = PinRateLimiter.instance.recordFailure();
                        if (lockedOut) AuditLogService.instance.logPinLockout();
                        AuditLogService.instance.logFailedPin();
                        if (!mounted) return;
                        final msg = PinRateLimiter.instance.isLocked
                            ? 'Shumë tentativa të gabuara. Provo përsëri pas ${PinRateLimiter.instance.lockoutSecondsRemaining}s.'
                            : 'Admin PIN i gabuar. ${PinRateLimiter.instance.remainingAttempts} tentativa të mbetur.';
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.negativeText,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            const Text(
              'Welcome! Please select your name',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreenText,
              ),
            ),

            const SizedBox(height: 35),

            Expanded(
              child: waiters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.person_outline,
                            size: 70,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No waiters found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 24,
                          runSpacing: 24,
                          children: waiters.map((waiter) {
                            return _buildWaiterButton(
                              name: waiter.name,
                              onTap: () => _selectWaiter(waiter.name),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiterButton({
    required String name,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 230,
      height: 200,
      child: Card(
        elevation: 5,
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.primaryGreen, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 42,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

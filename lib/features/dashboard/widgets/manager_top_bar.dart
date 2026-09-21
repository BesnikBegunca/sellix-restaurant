import 'dart:async';

import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../screens/sync_diagnostics_screen.dart';
import '../../../services/sync_status_service.dart';
import '../../../services/app_language_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/tr.dart';

class ManagerTopBar extends StatefulWidget {
  const ManagerTopBar({super.key, required this.sectionTitle, required this.m});

  final String sectionTitle;
  final ManagerData m;

  @override
  State<ManagerTopBar> createState() => _ManagerTopBarState();
}

class _ManagerTopBarState extends State<ManagerTopBar> {
  static const String _syncDiagnosticsPassword = 'Superadmin12?';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sectionTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLanguageService.instance.t(
                    'Manager Dashboard · POS System',
                    'Manager Dashboard · POS System',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          ListenableBuilder(
            listenable: SyncStatusService.instance,
            builder: (context, _) => _SyncStatusChip(
              status: SyncStatusService.instance,
              onTap: _openSyncDiagnosticsProtected,
            ),
          ),
          const SizedBox(width: 12),
          _TopBarChip(
            icon: Icons.schedule_outlined,
            label: timeStr,
            sublabel: dateStr,
          ),
          const SizedBox(width: 12),
          _TopBarManagerBadge(),
        ],
      ),
    );
  }

  Future<void> _openSyncDiagnosticsProtected() async {
    final allowed = await _askSyncPassword();
    if (!mounted || !allowed) return;
    await showSyncDiagnosticsDialog(context);
  }

  Future<bool> _askSyncPassword() async {
    String password = '';
    String? errorText;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr.kerkohetFjalekalim),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.vendosPasswordHapurDiagnostikenSinkronizimit,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => password = value,
                      onSubmitted: (_) {
                        final value = password.trim();
                        if (value == _syncDiagnosticsPassword) {
                          Navigator.of(dialogContext).pop(true);
                          return;
                        }
                        setStateDialog(() => errorText = tr.passwordPasakte);
                      },
                      decoration: InputDecoration(
                        labelText: tr.password,
                        errorText: errorText,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(tr.anulo),
                ),
                FilledButton(
                  onPressed: () {
                    final value = password.trim();
                    if (value == _syncDiagnosticsPassword) {
                      Navigator.of(dialogContext).pop(true);
                      return;
                    }
                    setStateDialog(() => errorText = tr.passwordPasakte);
                  },
                  child: const Text('Hap'),
                ),
              ],
            );
          },
        );
      },
    );
    return ok == true;
  }
}

class _TopBarChip extends StatelessWidget {
  const _TopBarChip({required this.icon, required this.label, this.sublabel});

  final IconData icon;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mediumGreenText),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                  height: 1.1,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.lightGreenText,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBarManagerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_accounts, size: 16, color: AppColors.white),
          SizedBox(width: 7),
          Text(
            'MENAXHER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.status, required this.onTap});

  final SyncStatusService status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final String label;
    final IconData icon;

    if (!status.isActivated) {
      dotColor = AppColors.mutedGray;
      bgColor = AppColors.lightGreenBg;
      borderColor = AppColors.lightGreenBorder;
      textColor = AppColors.lightGreenText;
      label = 'Jo aktivizuar';
      icon = Icons.sync_disabled_outlined;
    } else if (!status.isOnline) {
      dotColor = AppColors.softRed;
      bgColor = AppColors.softRed.withValues(alpha: 0.07);
      borderColor = AppColors.softRed.withValues(alpha: 0.25);
      textColor = AppColors.softRed;
      label = 'Jo online';
      icon = Icons.wifi_off_outlined;
    } else if (status.isSyncing) {
      dotColor = AppColors.mutedOrange;
      bgColor = AppColors.mutedOrange.withValues(alpha: 0.08);
      borderColor = AppColors.mutedOrange.withValues(alpha: 0.3);
      textColor = AppColors.mutedOrange;
      label = 'Sinkronizim…';
      icon = Icons.sync_outlined;
    } else if (status.hasFailed) {
      dotColor = AppColors.softRed;
      bgColor = AppColors.softRed.withValues(alpha: 0.07);
      borderColor = AppColors.softRed.withValues(alpha: 0.25);
      textColor = AppColors.softRed;
      label = '${status.failedOutboxCount} gabime';
      icon = Icons.sync_problem_outlined;
    } else if (status.hasPending) {
      dotColor = AppColors.mutedOrange;
      bgColor = AppColors.mutedOrange.withValues(alpha: 0.08);
      borderColor = AppColors.mutedOrange.withValues(alpha: 0.3);
      textColor = AppColors.mutedOrange;
      label = '${status.pendingOutboxCount} pritje';
      icon = Icons.upload_outlined;
    } else {
      dotColor = AppColors.successGreen;
      bgColor = AppColors.successGreen.withValues(alpha: 0.07);
      borderColor = AppColors.successGreen.withValues(alpha: 0.25);
      textColor = AppColors.successGreen;
      label = 'Sinkronizuar';
      icon = Icons.cloud_done_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagerBusinessPill extends StatelessWidget {
  const ManagerBusinessPill({super.key, required this.managerData});

  final ManagerData managerData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 20,
            color: AppColors.mutedGray.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              managerData.companyName ?? 'Main location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.charcoalText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerShiftPill extends StatelessWidget {
  const ManagerShiftPill({super.key, required this.managerData});

  final ManagerData managerData;

  @override
  Widget build(BuildContext context) {
    final open = managerData.shiftOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softGreenTint,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 20,
            color: AppColors.deepForestGreen,
          ),
          const SizedBox(width: 8),
          Text(
            open ? 'Shift open' : 'Shift closed',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.charcoalText,
            ),
          ),
        ],
      ),
    );
  }
}

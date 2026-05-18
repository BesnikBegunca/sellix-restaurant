import 'dart:async';

import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../screens/sync_diagnostics_screen.dart';
import '../../../services/sync_status_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_tokens.dart';

class ManagerTopBar extends StatefulWidget {
  const ManagerTopBar({
    super.key,
    required this.sectionTitle,
    required this.m,
  });

  final String sectionTitle;
  final ManagerData m;

  @override
  State<ManagerTopBar> createState() => _ManagerTopBarState();
}

class _ManagerTopBarState extends State<ManagerTopBar> {
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
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.lightGreenBorder),
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreenText,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Manager Dashboard · POS System',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),

          _ShiftStatusChip(open: widget.m.shiftOpen),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: SyncStatusService.instance,
            builder: (context, _) => _SyncStatusChip(
              status: SyncStatusService.instance,
              onTap: () => showSyncDiagnosticsDialog(context),
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
}

class _ShiftStatusChip extends StatelessWidget {
  const _ShiftStatusChip({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: open
            ? AppColors.primaryGreen.withValues(alpha: 0.08)
            : AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: open
              ? AppColors.primaryGreen.withValues(alpha: 0.25)
              : AppColors.lightGreenBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: open ? AppColors.primaryGreen : AppColors.lightGreenText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            open ? 'Gjendja e hapur' : 'Gjendja e mbyllur',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: open ? AppColors.primaryGreen : AppColors.lightGreenText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarChip extends StatelessWidget {
  const _TopBarChip({
    required this.icon,
    required this.label,
    this.sublabel,
  });

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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                  height: 1.1,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: const TextStyle(
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
      child: const Row(
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
              style: const TextStyle(
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
          const Icon(
            Icons.schedule_rounded,
            size: 20,
            color: AppColors.deepForestGreen,
          ),
          const SizedBox(width: 8),
          Text(
            open ? 'Shift open' : 'Shift closed',
            style: const TextStyle(
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

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../services/audit_log_service.dart';
import '../../../theme/app_colors.dart';

// ── date filter enum ──────────────────────────────────────────────────────────

enum AuditDateFilter { today, thisWeek, thisMonth, allTime, custom }

enum AuditCategoryFilter { all, security, payments, settings, users }

AuditCategoryFilter auditActionCategory(String action) {
  switch (action) {
    case AuditAction.failedPin:
    case AuditAction.unauthorizedAction:
      return AuditCategoryFilter.security;
    case AuditAction.saleCreated:
    case AuditAction.refundCreated:
    case AuditAction.voidCreated:
    case AuditAction.splitPayment:
    case AuditAction.paymentMethodOverride:
    case AuditAction.discountApplied:
    case AuditAction.manualDiscount:
    case AuditAction.priceOverride:
    case AuditAction.cashDrawerOpened:
    case AuditAction.receiptReprinted:
      return AuditCategoryFilter.payments;
    case AuditAction.settingChanged:
    case AuditAction.companyNameChanged:
    case AuditAction.printerChanged:
      return AuditCategoryFilter.settings;
    case AuditAction.waiterAdded:
    case AuditAction.waiterRemoved:
    case AuditAction.salaryChanged:
    case AuditAction.managerLogin:
    case AuditAction.waiterLogin:
      return AuditCategoryFilter.users;
    default:
      return AuditCategoryFilter.all;
  }
}

String auditCategoryLabel(AuditCategoryFilter cat) => switch (cat) {
  AuditCategoryFilter.security => 'Siguri',
  AuditCategoryFilter.payments => 'Pagesë',
  AuditCategoryFilter.settings => 'Cilësime',
  AuditCategoryFilter.users    => 'Përdorues',
  AuditCategoryFilter.all      => '',
};

({Color bg, Color fg}) auditCategoryBadgeStyle(AuditCategoryFilter cat) => switch (cat) {
  AuditCategoryFilter.security => (bg: const Color(0xFFFFEBEE), fg: const Color(0xFFE53935)),
  AuditCategoryFilter.payments => (bg: const Color(0xFFE8F5E9), fg: const Color(0xFF2E7D32)),
  AuditCategoryFilter.settings => (bg: const Color(0xFFFFF3E0), fg: const Color(0xFFE65100)),
  AuditCategoryFilter.users    => (bg: const Color(0xFFF5F5F5), fg: const Color(0xFF616161)),
  AuditCategoryFilter.all      => (bg: AppColors.beige,         fg: AppColors.mediumGreenText),
};

String auditLogDescription(AuditLogRow log) {
  final d = log.details;
  if (d == null || d.isEmpty) {
    if (log.entityType != null) {
      return '${log.entityType}${log.entityId != null ? ' #${log.entityId}' : ''}';
    }
    return '';
  }
  for (final key in ['description', 'note', 'reason', 'message', 'name']) {
    if (d.containsKey(key)) return d[key].toString();
  }
  if (log.entityType != null && log.entityId != null) {
    return '${log.entityType} #${log.entityId}';
  }
  final entry = d.entries.first;
  return '${entry.key}: ${entry.value}';
}

String auditTimeAgo(DateTime ts) {
  final diff = DateTime.now().difference(ts);
  if (diff.inMinutes < 1) return 'Tani';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min më parë';
  if (diff.inHours < 24) return '${diff.inHours} orë më parë';
  return '${diff.inDays} ditë më parë';
}

Color auditActionColor(String action) {
  switch (action) {
    case AuditAction.saleCreated:
    case AuditAction.shiftOpened:
    case AuditAction.managerLogin:
    case AuditAction.waiterLogin:
    case AuditAction.backupExported:
    case AuditAction.waiterAdded:
    case AuditAction.productCreated:
    case AuditAction.categoryCreated:
    case AuditAction.expenseAdded:
    case AuditAction.cashDrawerOpened:
    case AuditAction.receiptReprinted:
      return AppColors.successGreen;
    case AuditAction.refundCreated:
    case AuditAction.voidCreated:
    case AuditAction.productDeleted:
    case AuditAction.categoryDeleted:
    case AuditAction.expenseDeleted:
    case AuditAction.waiterRemoved:
    case AuditAction.failedPin:
    case AuditAction.unauthorizedAction:
    case AuditAction.failedRestore:
      return AppColors.negativeText;
    case AuditAction.discountApplied:
    case AuditAction.manualDiscount:
    case AuditAction.priceOverride:
    case AuditAction.shiftClosed:
    case AuditAction.shiftReopened:
    case AuditAction.backupRestored:
    case AuditAction.restoreUndone:
    case AuditAction.paymentMethodOverride:
    case AuditAction.itemRemoved:
      return AppColors.accentOrange;
    case AuditAction.splitPayment:
    case AuditAction.tableTransfer:
    case AuditAction.tableMerge:
    case AuditAction.tableSplit:
    case AuditAction.orderReopened:
      return AppColors.accentBlue;
    default:
      return AppColors.mediumGreenText;
  }
}

IconData auditActionIcon(String action) {
  switch (action) {
    case AuditAction.saleCreated:         return Icons.receipt_outlined;
    case AuditAction.refundCreated:       return Icons.undo_outlined;
    case AuditAction.voidCreated:         return Icons.cancel_outlined;
    case AuditAction.discountApplied:     return Icons.local_offer_outlined;
    case AuditAction.manualDiscount:      return Icons.discount_outlined;
    case AuditAction.priceOverride:       return Icons.edit_note_outlined;
    case AuditAction.splitPayment:        return Icons.call_split_outlined;
    case AuditAction.paymentMethodOverride: return Icons.swap_horiz_outlined;
    case AuditAction.receiptReprinted:    return Icons.print_outlined;
    case AuditAction.shiftOpened:         return Icons.play_circle_outline;
    case AuditAction.shiftClosed:         return Icons.stop_circle_outlined;
    case AuditAction.shiftReopened:       return Icons.replay_outlined;
    case AuditAction.tableOpened:         return Icons.table_restaurant_outlined;
    case AuditAction.tableCleared:        return Icons.table_bar_outlined;
    case AuditAction.tableTransfer:       return Icons.move_down_outlined;
    case AuditAction.tableMerge:          return Icons.merge_outlined;
    case AuditAction.tableSplit:          return Icons.call_split;
    case AuditAction.orderReopened:       return Icons.lock_open_outlined;
    case AuditAction.itemRemoved:         return Icons.remove_circle_outline;
    case AuditAction.cashDrawerOpened:    return Icons.point_of_sale_outlined;
    case AuditAction.productCreated:      return Icons.add_circle_outline;
    case AuditAction.productEdited:       return Icons.edit_outlined;
    case AuditAction.productDeleted:      return Icons.delete_outline;
    case AuditAction.categoryCreated:     return Icons.create_new_folder_outlined;
    case AuditAction.categoryDeleted:     return Icons.folder_delete_outlined;
    case AuditAction.expenseAdded:        return Icons.attach_money;
    case AuditAction.expenseDeleted:      return Icons.money_off_outlined;
    case AuditAction.managerLogin:        return Icons.admin_panel_settings_outlined;
    case AuditAction.waiterLogin:         return Icons.badge_outlined;
    case AuditAction.failedPin:           return Icons.lock_outlined;
    case AuditAction.unauthorizedAction:  return Icons.gpp_bad_outlined;
    case AuditAction.backupExported:      return Icons.upload_outlined;
    case AuditAction.backupRestored:      return Icons.download_outlined;
    case AuditAction.restoreUndone:       return Icons.history_outlined;
    case AuditAction.failedRestore:       return Icons.error_outline;
    case AuditAction.printerChanged:      return Icons.print_outlined;
    case AuditAction.settingChanged:
    case AuditAction.companyNameChanged:  return Icons.settings_outlined;
    case AuditAction.waiterAdded:         return Icons.person_add_outlined;
    case AuditAction.waiterRemoved:       return Icons.person_remove_outlined;
    case AuditAction.salaryChanged:       return Icons.payments_outlined;
    default:                              return Icons.info_outline;
  }
}

const kAllAuditActionTypes = [
  AuditAction.saleCreated,
  AuditAction.refundCreated,
  AuditAction.voidCreated,
  AuditAction.discountApplied,
  AuditAction.manualDiscount,
  AuditAction.priceOverride,
  AuditAction.splitPayment,
  AuditAction.paymentMethodOverride,
  AuditAction.receiptReprinted,
  AuditAction.shiftOpened,
  AuditAction.shiftClosed,
  AuditAction.shiftReopened,
  AuditAction.tableOpened,
  AuditAction.tableCleared,
  AuditAction.tableTransfer,
  AuditAction.tableMerge,
  AuditAction.tableSplit,
  AuditAction.orderReopened,
  AuditAction.itemRemoved,
  AuditAction.cashDrawerOpened,
  AuditAction.productCreated,
  AuditAction.productEdited,
  AuditAction.productDeleted,
  AuditAction.categoryCreated,
  AuditAction.categoryDeleted,
  AuditAction.expenseAdded,
  AuditAction.expenseDeleted,
  AuditAction.managerLogin,
  AuditAction.waiterLogin,
  AuditAction.failedPin,
  AuditAction.unauthorizedAction,
  AuditAction.backupExported,
  AuditAction.backupRestored,
  AuditAction.restoreUndone,
  AuditAction.failedRestore,
  AuditAction.printerChanged,
  AuditAction.settingChanged,
  AuditAction.companyNameChanged,
  AuditAction.waiterAdded,
  AuditAction.waiterRemoved,
  AuditAction.salaryChanged,
];

// ── log card ──────────────────────────────────────────────────────────────────

class AuditLogCard extends StatelessWidget {
  const AuditLogCard({
    super.key,
    required this.log,
    required this.expanded,
    required this.onToggle,
  });

  final AuditLogRow log;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final actionColor = auditActionColor(log.actionType);
    final category = auditActionCategory(log.actionType);
    final (:bg, :fg) = auditCategoryBadgeStyle(category);
    final catLabel = auditCategoryLabel(category);

    final ts = log.createdAt;
    final dateStr =
        '${ts.day.toString().padLeft(2, '0')}.${ts.month.toString().padLeft(2, '0')}.${ts.year}'
        ' ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    final description = auditLogDescription(log);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded
              ? AppColors.primaryGreen.withValues(alpha: 0.2)
              : AppColors.lightGreenBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── summary row ─────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(expanded ? 0 : 14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      auditActionIcon(log.actionType),
                      size: 20,
                      color: actionColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Thin vertical accent line
                  Container(
                    width: 1.5,
                    height: 50,
                    color: AppColors.lightGreenBorder,
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuditAction.label(log.actionType),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: AppColors.lightGreenText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              log.performedBy ?? '—',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGreenText,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.access_time_outlined,
                              size: 13,
                              color: AppColors.lightGreenText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGreenText,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category badge
                  if (catLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        catLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── expanded detail ──────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDetail(actionColor),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(Color color) {
    final details = log.details;
    final entries = details?.entries.toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle(0.1))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── context chips ──────────────────────────────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (log.shiftId  != null) _chip('Shift',   '#${log.shiftId}'),
              if (log.saleId   != null) _chip('Sale',    '#${log.saleId}'),
              if (log.tableId  != null) _chip('Table',   '${log.tableId}'),
              _chip('Log ID', '#${log.id}'),
            ],
          ),

          // ── device forensics ───────────────────────────────────────────
          if (log.deviceId != null || log.terminalName != null || log.platform != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Terminal',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (log.terminalName != null)
                  _chip('Host', log.terminalName!),
                if (log.platform != null)
                  _chip('Platform', log.platform!),
                if (log.appVersion != null)
                  _chip('App', log.appVersion!),
                if (log.deviceId != null)
                  _chip('Device', '…${log.deviceId!.substring(log.deviceId!.length > 8 ? log.deviceId!.length - 8 : 0)}'),
                if (log.rowHash != null)
                  _chip('Hash', log.rowHash!.substring(0, 8)),
              ],
            ),
          ],

          // ── action details ─────────────────────────────────────────────
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Detajet',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mediumGreenText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fmtValue(e.value),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.darkGreenText,
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

          // raw JSON fallback for logs with malformed details
          if (log.detailsJson != null && entries.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.detailsJson!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.lightGreenText,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.lightGreenText,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.mediumGreenText,
          ),
        ),
      ],
    );
  }

  String _fmtValue(dynamic v) {
    if (v is Map || v is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(v);
      } catch (_) {
        return v.toString();
      }
    }
    if (v is double) return v.toStringAsFixed(2);
    return v.toString();
  }
}

// ── KPI card widget ───────────────────────────────────────────────────────────

class AuditKpiCard extends StatelessWidget {
  const AuditKpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mediumGreenText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreenText,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

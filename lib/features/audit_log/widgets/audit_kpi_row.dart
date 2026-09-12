import 'package:flutter/material.dart';

import '../../../services/audit_log_service.dart';
import 'audit_kpi_card.dart';
import 'audit_log_card.dart';
import '../../../l10n/tr.dart';

class AuditKpiRow extends StatelessWidget {
  const AuditKpiRow({super.key, required this.logs});

  final List<AuditLogRow> logs;

  @override
  Widget build(BuildContext context) {
    final securityCount = logs
        .where((l) => auditActionCategory(l.actionType) == AuditCategoryFilter.security)
        .length;
    final paymentCount = logs
        .where((l) => auditActionCategory(l.actionType) == AuditCategoryFilter.payments)
        .length;
    final lastActivity = logs.isNotEmpty ? auditTimeAgo(logs.first.createdAt) : '—';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AuditKpiCard(
              icon: Icons.monitor_heart_outlined,
              label: tr.eventeGjithsej,
              value: '${logs.length}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AuditKpiCard(
              icon: Icons.shield_outlined,
              label: tr.eventeSigurie,
              value: '$securityCount',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AuditKpiCard(
              icon: Icons.attach_money_outlined,
              label: tr.eventePagesash,
              value: '$paymentCount',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AuditKpiCard(
              icon: Icons.schedule_outlined,
              label: tr.aktivitetiFundit,
              value: lastActivity,
            ),
          ),
        ],
      ),
    );
  }
}

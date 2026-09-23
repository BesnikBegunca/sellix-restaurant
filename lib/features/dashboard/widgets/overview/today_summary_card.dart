import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/app_card.dart';
import '../../../../l10n/tr.dart';

class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.m});
  final ManagerData m;

  static String _fmtHour(int h) {
    return '${h.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    final todaySales = m.salesToday;

    final totalOrders = todaySales.length;
    final totalRevenue = m.revenueToday;
    final avgOrder = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    final hourCounts = <int, int>{};
    for (final s in todaySales) {
      hourCounts[s.timestamp.hour] = (hourCounts[s.timestamp.hour] ?? 0) + 1;
    }
    final peakHour = hourCounts.isEmpty
        ? null
        : hourCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return AppCard(
      title: tr.permbledhjaSotme,
      subtitle: tr.porositeArdhuratDites,
      child: Column(
        children: [
          _SummaryRow(label: tr.porosi, value: '$totalOrders'),
          const SizedBox(height: 12),
          _SummaryRow(
            label: tr.porosiaMesatare,
            value: '${avgOrder.toStringAsFixed(2)}€',
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: tr.oraNgarkuar,
            value: peakHour != null ? _fmtHour(peakHour) : '—',
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.lightGreenBorder, height: 1),
          const SizedBox(height: 14),
          _SummaryRow(
            label: tr.ardhura2,
            value: '${totalRevenue.toStringAsFixed(2)}€',
            bold: true,
            valueColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? AppColors.darkGreenText : AppColors.lightGreenText,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';

class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.m});
  final ManagerData m;

  static String _fmtHour(int h) {
    final amPm = h >= 12 ? 'PM' : 'AM';
    final display = h == 0 ? 12 : h > 12 ? h - 12 : h;
    return '$display:00 $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final todaySales = m.salesHistory
        .where(
          (s) =>
              !s.timestamp.isBefore(todayStart) &&
              !s.timestamp.isAfter(todayEnd),
        )
        .toList();

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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Porosi Gjithsej', value: '$totalOrders'),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Porosia Mesatare',
            value: '${avgOrder.toStringAsFixed(2)}€',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Ora Kulmore',
            value: peakHour != null ? _fmtHour(peakHour) : '—',
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.lightGreenBorder),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Të Ardhura Gjithsej',
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
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

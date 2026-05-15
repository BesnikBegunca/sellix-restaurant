import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';

class WaiterSummaryCard extends StatelessWidget {
  const WaiterSummaryCard({
    super.key,
    required this.waiter,
    required this.m,
    required this.viewMonth,
    required this.onTap,
  });

  final WaiterInfo waiter;
  final ManagerData m;
  final DateTime viewMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worked = m.workedDaysInMonth(
      waiter.name,
      viewMonth.year,
      viewMonth.month,
    );
    final rate = m.getSalary(waiter.name);
    final gross = rate * worked;
    final periodStart = DateTime(viewMonth.year, viewMonth.month, 1);
    final periodEnd = DateTime(
      viewMonth.year,
      viewMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );
    final totalAdv = m.totalAdvancesFor(waiter.name, periodStart, periodEnd);
    final net = gross - totalAdv;
    final initial =
        waiter.name.isNotEmpty ? waiter.name[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waiter.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rate > 0
                        ? '${rate.toStringAsFixed(2)}€/ditë · $worked ditë'
                        : 'Pa pagë të caktuar',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                _statCell('Bruto', '${gross.toStringAsFixed(0)}€',
                    AppColors.darkGreenText),
                const SizedBox(width: 20),
                if (totalAdv > 0)
                  _statCell('Avans', '-${totalAdv.toStringAsFixed(0)}€',
                      AppColors.softRed),
                if (totalAdv > 0) const SizedBox(width: 20),
                _statCell(
                  'Neto',
                  '${net.toStringAsFixed(0)}€',
                  net >= 0 ? AppColors.primaryGreen : AppColors.softRed,
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumGreenText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.mediumGreenText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

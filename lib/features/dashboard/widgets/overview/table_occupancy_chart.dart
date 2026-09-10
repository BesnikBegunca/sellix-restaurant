import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/app_card.dart';

class TableOccupancyChart extends StatelessWidget {
  const TableOccupancyChart({
    super.key,
    required this.m,
    required this.occupied,
  });
  final ManagerData m;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final total = m.cashierTables.length;
    final free = total - occupied;
    final occupiedTables = m.cashierTables.where((t) => t.occupied).toList();

    return AppCard(
      title: 'Tavolinat tani',
      subtitle: total == 0
          ? 'Nuk ka tavolina të konfiguruara.'
          : '$occupied të zëna · $free të lira',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: total == 0
                ? const Center(
                    child: Text(
                      'Shto tavolina te seksioni Tavolinat.',
                      style: TextStyle(color: AppColors.lightGreenText),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 48,
                                startDegreeOffset: -90,
                                sections: [
                                  if (occupied > 0)
                                    PieChartSectionData(
                                      value: occupied.toDouble(),
                                      color: AppColors.mutedOrange,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                                  if (free > 0)
                                    PieChartSectionData(
                                      value: free.toDouble(),
                                      color: AppColors.primaryGreen,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                                  if (occupied == 0 && free == 0)
                                    PieChartSectionData(
                                      value: 1,
                                      color: AppColors.lightGreenBg,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$occupied',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkGreenText,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  'të zëna',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.lightGreenText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Legend(
                            color: AppColors.mutedOrange,
                            label: 'Të zëna',
                            value: '$occupied',
                          ),
                          const SizedBox(height: 10),
                          _Legend(
                            color: AppColors.primaryGreen,
                            label: 'Të lira',
                            value: '$free',
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (occupiedTables.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Asnjë tavolinë e zënë për momentin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mediumGreenText,
                ),
              ),
            )
          else
            ...occupiedTables.take(5).map((t) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.mutedOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tavolina ${t.id}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ),
                    Text(
                      t.assignedWaiterName ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(t.currentTotal ?? 0).toStringAsFixed(0)}€',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mediumGreenText,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';

class TableOccupancyChart extends StatelessWidget {
  const TableOccupancyChart({super.key, required this.m, required this.occupied});
  final ManagerData m;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final total = math.max(m.cashierTables.length, 1);
    final now = DateTime.now();
    final currentHour = now.hour.clamp(8, 22);

    double occupancyAt(int hour) {
      const lunchPeak = 13.0;
      const dinnerPeak = 19.0;
      final lunchWeight = math.exp(-math.pow(hour - lunchPeak, 2) / 8.0);
      final dinnerWeight = math.exp(-math.pow(hour - dinnerPeak, 2) / 8.0);
      final base = math.max(lunchWeight, dinnerWeight);
      final scale = occupied > 0 ? occupied.toDouble() : total * 0.4;
      return (base * scale).clamp(0.0, total.toDouble());
    }

    final endHour = math.max(currentHour, 12);
    final spots = <FlSpot>[];
    for (var h = 12; h <= endHour; h++) {
      spots.add(FlSpot((h - 12).toDouble(), occupancyAt(h)));
    }

    final maxY = (total * 1.1).ceilToDouble();
    final yInterval = total > 0 ? (total / 4).ceilToDouble() : 5.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zënia e Tavolinave Sot',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: spots.length < 2
                ? Center(
                    child: Text(
                      'No occupancy data yet.',
                      style: TextStyle(color: AppColors.lightGreenText),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (endHour - 12).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: AppColors.primaryGreen,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primaryGreen,
                              strokeWidth: 2,
                              strokeColor: AppColors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.06,
                            ),
                          ),
                        ),
                      ],
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.lightGreenBorder,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 2,
                            getTitlesWidget: (v, _) {
                              final h = v.toInt() + 12;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '$h:00',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mediumGreenText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: yInterval,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.lightGreenText,
                              ),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primaryGreen,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(0)} tables',
                                  const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

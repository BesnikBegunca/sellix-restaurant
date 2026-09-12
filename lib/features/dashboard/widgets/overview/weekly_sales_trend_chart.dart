import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/chart_card.dart';
import '../../../../l10n/tr.dart';

class WeeklySalesTrendChart extends StatelessWidget {
  const WeeklySalesTrendChart({super.key, required this.m});
  final ManagerData m;

  static List<String> get _dayAbbr => [tr.hen, 'Mar', tr.mer, 'Enj', 'Pre', 'Sht', 'Die'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dailyRevenue = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return m.revenueInRange(
        DateTime(day.year, day.month, day.day),
        DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
      );
    });
    final maxY = dailyRevenue.fold(0.0, math.max);
    final interval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1000.0;
    final chartMax = maxY > 0 ? (interval * 4) : 4000.0;

    final barGroups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: dailyRevenue[i],
            color: AppColors.primaryGreen,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: chartMax,
              color: AppColors.lightGreenBg.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    });

    final labels = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return _dayAbbr[day.weekday - 1];
    });

    return ChartCard(
      title: tr.shitjet7Diteve,
      subtitle: tr.ardhuratDitoreJoPorositeHapura,
      minHeight: 240,
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: chartMax,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
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
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[v.toInt()],
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGreenText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: interval,
                  getTitlesWidget: (v, _) => Text(
                    v >= 1000
                        ? '${(v / 1000).toStringAsFixed(0)}k'
                        : v.toStringAsFixed(0),
                    style: TextStyle(
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
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.primaryGreen,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${rod.toY.toStringAsFixed(0)}€',
                  TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

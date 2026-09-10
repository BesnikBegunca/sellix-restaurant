import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../widgets/stat_card.dart';
import '../widgets/profits/profit_breakdown_row.dart';

class ProfitsPanel extends StatefulWidget {
  const ProfitsPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<ProfitsPanel> createState() => _ProfitsPanelState();
}

class _ProfitsPanelState extends State<ProfitsPanel> {
  int _tab = 1; // 0=Daily, 1=Weekly, 2=Monthly

  @override
  void initState() {
    super.initState();
    widget.m.addListener(_onM);
  }

  void _onM() => setState(() {});

  @override
  void dispose() {
    widget.m.removeListener(_onM);
    super.dispose();
  }

  List<FlSpot> _buildSpots(ManagerData m) {
    final today = DateTime.now();
    switch (_tab) {
      case 0:
        return List.generate(12, (i) {
          final h = (today.hour - 11 + i).clamp(0, 23);
          final from = DateTime(today.year, today.month, today.day, h);
          final to = DateTime(today.year, today.month, today.day, h, 59, 59);
          final p = m.revenueInRange(from, to) - m.expensesInRange(from, to);
          return FlSpot(i.toDouble(), p);
        });
      case 2:
        return List.generate(30, (i) {
          final day = today.subtract(Duration(days: 29 - i));
          final from = DateTime(day.year, day.month, day.day);
          final to = DateTime(day.year, day.month, day.day, 23, 59, 59);
          final p = m.revenueInRange(from, to) - m.expensesInRange(from, to);
          return FlSpot(i.toDouble(), p);
        });
      default:
        return List.generate(7, (i) {
          final day = today.subtract(Duration(days: 6 - i));
          final from = DateTime(day.year, day.month, day.day);
          final to = DateTime(day.year, day.month, day.day, 23, 59, 59);
          final p = m.revenueInRange(from, to) - m.expensesInRange(from, to);
          return FlSpot(i.toDouble(), p);
        });
    }
  }

  String _xLabel(int i) {
    final today = DateTime.now();
    const dayAbbr = ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'];
    switch (_tab) {
      case 0:
        final h = (today.hour - 11 + i).clamp(0, 23);
        return '$h:00';
      case 2:
        final day = today.subtract(Duration(days: 29 - i));
        return '${day.day}';
      default:
        final day = today.subtract(Duration(days: 6 - i));
        return dayAbbr[day.weekday - 1];
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = widget.m;

    final profDay = m.profitToday;
    final profWeek = m.profitThisWeek;
    final profMonth = m.profitThisMonth;
    final totalSales = m.revenueThisMonth;

    final selRevenues = [m.revenueToday, m.revenueThisWeek, m.revenueThisMonth];
    final selExpenses = [
      m.expensesToday,
      m.expensesThisWeek,
      m.expensesThisMonth,
    ];
    final selProfits = [profDay, profWeek, profMonth];
    final selRev = selRevenues[_tab];
    final selExp = selExpenses[_tab];
    final selProfit = selProfits[_tab];

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final avgDaily = _tab == 0
        ? profDay
        : _tab == 1
        ? profWeek / 7
        : profMonth / daysInMonth;
    final margin = selRev > 0 ? (selProfit / selRev * 100) : 0.0;

    final spots = _buildSpots(m);
    final yValues = spots.map((s) => s.y).toList();
    final maxY = yValues.isEmpty ? 0.0 : yValues.reduce(math.max);
    final minY = yValues.isEmpty ? 0.0 : yValues.reduce(math.min);
    final chartMaxY = math.max(maxY * 1.15, 100.0);
    final chartMinY = math.min(minY * 1.1, 0.0);
    final yInterval = math.max((chartMaxY - chartMinY) / 4, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('Fitime'),
        const SizedBox(height: 6),
        const Text(
          'Fitimi = shitje – shpenzime, sipas periudhës.',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  title: 'Fitim Ditor',
                  value: '${profDay.toStringAsFixed(0)}€',
                  icon: Icons.attach_money,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Fitim Javor',
                  value: '${profWeek.toStringAsFixed(0)}€',
                  icon: Icons.trending_up_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Fitim Mujor',
                  value: '${profMonth.toStringAsFixed(0)}€',
                  icon: Icons.calendar_month_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Shitje Gjithsej',
                  value: '${totalSales.toStringAsFixed(0)}€',
                  icon: Icons.bar_chart_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Trendi i Fitimit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              for (final entry in [
                                (0, 'Ditore'),
                                (1, 'Javore'),
                                (2, 'Mujore'),
                              ])
                                GestureDetector(
                                  onTap: () => setState(() => _tab = entry.$1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tab == entry.$1
                                          ? AppColors.primaryGreen
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      entry.$2,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _tab == entry.$1
                                            ? AppColors.white
                                            : AppColors.mediumGreenText,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 320,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: (spots.length - 1).toDouble(),
                          minY: chartMinY,
                          maxY: chartMaxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              curveSmoothness: 0.3,
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
                                  alpha: 0.05,
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
                                interval: _tab == 2 ? 5 : 1,
                                getTitlesWidget: (v, _) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _xLabel(v.toInt()),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mediumGreenText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 52,
                                interval: yInterval,
                                getTitlesWidget: (v, _) => Text(
                                  v >= 1000
                                      ? '${(v / 1000).toStringAsFixed(0)}k'
                                      : v.toStringAsFixed(0),
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
                                      '${s.y.toStringAsFixed(0)}€',
                                      TextStyle(
                                        color: scheme.surfaceContainerHighest,
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
              ),
              const SizedBox(width: 20),

              SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mesatare Ditore',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${avgDaily.toStringAsFixed(0)}€',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.lightGreenBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ndarja',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ProfitBreakdownRow(
                            label: 'Të Ardhura',
                            value: '${selRev.toStringAsFixed(0)}€',
                          ),
                          const SizedBox(height: 10),
                          ProfitBreakdownRow(
                            label: 'Kosto',
                            value: selExp > 0
                                ? '-${selExp.toStringAsFixed(0)}€'
                                : '0€',
                            valueColor: selExp > 0
                                ? AppColors.softRed
                                : AppColors.darkGreenText,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightGreenBg.withValues(
                                alpha: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ProfitBreakdownRow(
                              label: 'Fitimi',
                              value: '${selProfit.toStringAsFixed(0)}€',
                              valueColor: AppColors.primaryGreen,
                              bold: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Marzhi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${margin.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selRev > 0
                                    ? '+${margin.toStringAsFixed(1)}%'
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

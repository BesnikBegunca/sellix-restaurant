import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../widgets/stat_card.dart';

class OverviewPanel extends StatelessWidget {
  const OverviewPanel({super.key, required this.m, required this.onNavigate});

  final ManagerData m;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    final productCount = m.categories.fold<int>(
      0,
      (s, c) => s + c.products.length,
    );
    final categoryCount = m.categories.length;
    final occupied = m.cashierTables.where((t) => t.occupied).length;
    final totalTables = m.cashierTables.length;
    final freeTables = totalTables - occupied;
    final occPct = totalTables > 0
        ? (occupied / totalTables * 100).toStringAsFixed(0)
        : '0';
    final totalStaffSales = m.waiterSales.values.fold<double>(
      0,
      (a, b) => a + b,
    );
    final openCheck = m.cashierTables.fold<double>(
      0,
      (s, t) => s + (t.currentTotal ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pasqyra',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Real-time operational insights',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _OverviewLiveClockChip(),
          ],
        ),
        const SizedBox(height: 24),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  title: 'Gjendja e Turnit',
                  value: m.shiftOpen ? 'Hapur' : 'Mbyllur',
                  icon: Icons.schedule_outlined,
                  accentColor: m.shiftOpen
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Kamarierë Aktivë',
                  value: '${m.waiters.length}',
                  icon: Icons.people_outline,
                  badge: m.waiters.isNotEmpty ? '+${m.waiters.length}' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Shpenzime Sot',
                  value: '${m.totalExpenses.toStringAsFixed(0)}€',
                  icon: Icons.payments_outlined,
                  accentColor: AppColors.softRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Fitim Ditor',
                  value: '${m.profitToday.toStringAsFixed(0)}€',
                  icon: Icons.trending_up,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Fitim Javor',
                  value: '${m.profitThisWeek.toStringAsFixed(0)}€',
                  icon: Icons.trending_up_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Punonjësi Më i Mirë',
                  value: top.key == '—' ? '—' : top.key,
                  subtitle: top.key == '—'
                      ? null
                      : '${top.value.toStringAsFixed(0)}€',
                  icon: Icons.emoji_events_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  title: 'Tavolina të Lira',
                  value: '$freeTables',
                  icon: Icons.table_restaurant_outlined,
                  accentColor: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Tavolina të Zëna',
                  value: '$occupied',
                  icon: Icons.event_seat_outlined,
                  accentColor: AppColors.mutedOrange,
                  badge: totalTables > 0 ? '$occPct%' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Bilanci i Hapur',
                  value: '${openCheck.toStringAsFixed(0)}€',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Kategoritë e Menusë',
                  value: '$categoryCount',
                  icon: Icons.restaurant_menu_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Produktet',
                  value: '$productCount',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Shitjet e Stafit',
                  value: '${totalStaffSales.toStringAsFixed(0)}€',
                  icon: Icons.point_of_sale_outlined,
                  accentColor: AppColors.warmGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _WeeklySalesTrendChart(m: m)),
            const SizedBox(width: 16),
            Expanded(child: _TableOccupancyChart(m: m, occupied: occupied)),
          ],
        ),
        const SizedBox(height: 20),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _TopPerformerCard(m: m)),
              const SizedBox(width: 16),
              Expanded(child: _QuickActionsCard(onNavigate: onNavigate)),
              const SizedBox(width: 16),
              Expanded(child: _TodaySummaryCard(m: m)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopPerformerCard extends StatelessWidget {
  const _TopPerformerCard({required this.m});
  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    final hasData = top.key != '—' && top.value > 0;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final topOrders = hasData
        ? m.salesHistory
              .where(
                (s) =>
                    s.waiterName == top.key &&
                    !s.timestamp.isBefore(todayStart) &&
                    !s.timestamp.isAfter(todayEnd),
              )
              .length
        : 0;

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Performuesi Kryesor',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (!hasData)
            Expanded(
              child: Center(
                child: Text(
                  'Nuk ka të dhëna ende.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      top.key.length >= 2
                          ? top.key.split(' ').map((w) => w[0]).take(2).join()
                          : top.key[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      top.key,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    const Text(
                      'Kamarier',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.lightGreenBorder),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shitje',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${top.value.toStringAsFixed(0)}€',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Porosi',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$topOrders',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
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
            'Veprime të Shpejta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          _BigActionButton(
            icon: Icons.schedule_outlined,
            label: 'Mbyll Turnin',
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 10),
          _BigActionButton(
            icon: Icons.attach_money,
            label: 'Shto Shpenzim',
            onTap: () => onNavigate(3),
          ),
          const SizedBox(height: 10),
          _BigActionButton(
            icon: Icons.bar_chart_outlined,
            label: 'Shiko Raportet',
            onTap: () => onNavigate(5),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatefulWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_BigActionButton> createState() => _BigActionButtonState();
}

class _BigActionButtonState extends State<_BigActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.lightGreenBg
                : const Color(0xFFEEF3EE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGreenText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.m});
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

class _OverviewLiveClockChip extends StatefulWidget {
  @override
  State<_OverviewLiveClockChip> createState() => _OverviewLiveClockChipState();
}

class _OverviewLiveClockChipState extends State<_OverviewLiveClockChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final hour = now.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    final t =
        '${displayHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ora Aktuale',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.lightGreenText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySalesTrendChart extends StatelessWidget {
  const _WeeklySalesTrendChart({required this.m});
  final ManagerData m;

  static const _dayAbbr = ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'];

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
            'Trendi Javor i Shitjeve',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
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
                          style: const TextStyle(
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
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryGreen,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(0)}€',
                      const TextStyle(
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
        ],
      ),
    );
  }
}

class _TableOccupancyChart extends StatelessWidget {
  const _TableOccupancyChart({required this.m, required this.occupied});
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

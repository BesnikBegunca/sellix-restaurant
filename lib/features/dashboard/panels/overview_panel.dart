import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../widgets/stat_card.dart';
import '../widgets/overview/overview_live_clock_chip.dart';
import '../widgets/overview/quick_actions_card.dart';
import '../widgets/overview/table_occupancy_chart.dart';
import '../widgets/overview/today_summary_card.dart';
import '../widgets/overview/top_performer_card.dart';
import '../widgets/overview/weekly_sales_trend_chart.dart';

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
            OverviewLiveClockChip(),
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
            Expanded(child: WeeklySalesTrendChart(m: m)),
            const SizedBox(width: 16),
            Expanded(child: TableOccupancyChart(m: m, occupied: occupied)),
          ],
        ),
        const SizedBox(height: 20),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: TopPerformerCard(m: m)),
              const SizedBox(width: 16),
              Expanded(child: QuickActionsCard(onNavigate: onNavigate)),
              const SizedBox(width: 16),
              Expanded(child: TodaySummaryCard(m: m)),
            ],
          ),
        ),
      ],
    );
  }
}


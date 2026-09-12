import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/dashboard/app_card.dart';
import '../../../widgets/dashboard/kpi_card.dart';
import '../../../widgets/dashboard/status_badge.dart';
import '../widgets/overview/overview_live_clock_chip.dart';
import '../widgets/overview/quick_actions_card.dart';
import '../widgets/overview/table_occupancy_chart.dart';
import '../widgets/overview/today_summary_card.dart';
import '../widgets/overview/top_performer_card.dart';
import '../widgets/overview/weekly_sales_trend_chart.dart';
import '../../../l10n/tr.dart';

class OverviewPanel extends StatelessWidget {
  const OverviewPanel({super.key, required this.m, required this.onNavigate});

  final ManagerData m;
  final ValueChanged<int> onNavigate;

  static String _euro(double n, {int digits = 0}) =>
      '${n.toStringAsFixed(digits)}€';

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    final productCount = m.categories.fold<int>(
      0,
      (s, c) => s + c.products.length,
    );
    final occupied = m.cashierTables.where((t) => t.occupied).length;
    final totalTables = m.cashierTables.length;
    final freeTables = totalTables - occupied;
    final occPct = totalTables > 0
        ? (occupied / totalTables * 100).toStringAsFixed(0)
        : '0';
    final openCheck = m.cashierTables.fold<double>(
      0,
      (s, t) => s + (t.currentTotal ?? 0),
    );
    final company = m.companyName?.trim().isNotEmpty == true
        ? m.companyName!
        : tr.posSystem;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final kpiCols = w >= 1100
            ? 4
            : w >= 720
            ? 2
            : 1;
        final gap = 16.0;
        final kpiW = (w - gap * (kpiCols - 1)) / kpiCols;
        final twoCol = w >= 980;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeCard(company: company, shiftOpen: m.shiftOpen),
            const SizedBox(height: 20),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: kpiW,
                  child: KpiCard(
                    label: tr.ardhuraSot,
                    value: _euro(m.revenueToday),
                    subtitle: tr.shitjetDitesAktuale,
                    icon: Icons.point_of_sale_outlined,
                    onTap: () => onNavigate(6),
                  ),
                ),
                SizedBox(
                  width: kpiW,
                  child: KpiCard(
                    label: tr.fitimSot,
                    value: _euro(m.profitToday),
                    subtitle: tr.pasShpenzimeve,
                    icon: Icons.trending_up,
                    accentColor: AppColors.warmGold,
                    onTap: () => onNavigate(5),
                  ),
                ),
                SizedBox(
                  width: kpiW,
                  child: KpiCard(
                    label: tr.bilanciHapur,
                    value: _euro(openCheck),
                    subtitle: occupied == 0
                        ? tr.asnjeTavolineZene
                        : trf.occupiedTables(occupied),
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: AppColors.infoBlue,
                    onTap: () => onNavigate(9),
                  ),
                ),
                SizedBox(
                  width: kpiW,
                  child: KpiCard(
                    label: tr.turni,
                    value: m.shiftOpen ? 'Hapur' : 'Mbyllur',
                    subtitle: m.shiftOpen
                        ? tr.operacioniEshteAktiv
                        : tr.hapeTurninShitur,
                    icon: Icons.schedule_outlined,
                    accentColor: m.shiftOpen
                        ? AppColors.successGreen
                        : AppColors.lightGreenText,
                    onTap: () => onNavigate(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _OpsSnapshotCard(
              waiters: m.waiters.length,
              expenses: m.totalExpenses,
              weekProfit: m.profitThisWeek,
              freeTables: freeTables,
              occupied: occupied,
              occPct: occPct,
              products: productCount,
              categories: m.categories.length,
              topName: top.key,
              topSales: top.value,
              onNavigate: onNavigate,
            ),
            const SizedBox(height: 20),
            if (twoCol)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: WeeklySalesTrendChart(m: m)),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TableOccupancyChart(m: m, occupied: occupied),
                  ),
                ],
              )
            else ...[
              WeeklySalesTrendChart(m: m),
              const SizedBox(height: 16),
              TableOccupancyChart(m: m, occupied: occupied),
            ],
            const SizedBox(height: 20),
            if (twoCol)
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
              )
            else ...[
              TopPerformerCard(m: m),
              const SizedBox(height: 16),
              QuickActionsCard(onNavigate: onNavigate),
              const SizedBox(height: 16),
              TodaySummaryCard(m: m),
            ],
          ],
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.company, required this.shiftOpen});

  final String company;
  final bool shiftOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.permbledhjeDites,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightGreenText,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreenText,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                StatusBadge(
                  label: shiftOpen ? 'Turni hapur' : 'Turni mbyllur',
                  variant: shiftOpen
                      ? StatusBadgeVariant.success
                      : StatusBadgeVariant.neutral,
                ),
              ],
            ),
          ),
          const OverviewLiveClockChip(),
        ],
      ),
    );
  }
}

class _OpsSnapshotCard extends StatelessWidget {
  const _OpsSnapshotCard({
    required this.waiters,
    required this.expenses,
    required this.weekProfit,
    required this.freeTables,
    required this.occupied,
    required this.occPct,
    required this.products,
    required this.categories,
    required this.topName,
    required this.topSales,
    required this.onNavigate,
  });

  final int waiters;
  final double expenses;
  final double weekProfit;
  final int freeTables;
  final int occupied;
  final String occPct;
  final int products;
  final int categories;
  final String topName;
  final double topSales;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: tr.pamjaOperative,
      subtitle:
          tr.gjendjaStafitTavolinaveMenuseKlikoHapur,
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 900
              ? 4
              : c.maxWidth >= 560
              ? 2
              : 1;
          final gap = 12.0;
          final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _MiniMetric(
                width: itemW,
                icon: Icons.people_outline,
                label: tr.kamariere,
                value: '$waiters',
                hint: tr.stafRegjistruar,
                onTap: () => onNavigate(2),
              ),
              _MiniMetric(
                width: itemW,
                icon: Icons.payments_outlined,
                label: tr.shpenzime,
                value: '${expenses.toStringAsFixed(0)}€',
                hint: tr.totaliShpenzimeve,
                accent: AppColors.softRed,
                onTap: () => onNavigate(4),
              ),
              _MiniMetric(
                width: itemW,
                icon: Icons.calendar_view_week_outlined,
                label: tr.fitimJavor2,
                value: '${weekProfit.toStringAsFixed(0)}€',
                hint: tr.k7DitetFundit,
                accent: AppColors.warmGold,
                onTap: () => onNavigate(5),
              ),
              _MiniMetric(
                width: itemW,
                icon: Icons.table_restaurant_outlined,
                label: tr.tavolina,
                value: '$freeTables lira',
                hint: trf.occupiedWithPct(occupied, int.parse(occPct)),
                onTap: () => onNavigate(9),
              ),
              _MiniMetric(
                width: itemW,
                icon: Icons.restaurant_menu_outlined,
                label: tr.menu,
                value: '$products produkte',
                hint: trf.categoriesCount(categories),
                onTap: () => onNavigate(8),
              ),
              _MiniMetric(
                width: itemW,
                icon: Icons.emoji_events_outlined,
                label: tr.topKamarier,
                value: topName == '—' ? '—' : topName,
                hint: topName == '—'
                    ? 'Nuk ka shitje ende'
                    : '${topSales.toStringAsFixed(0)}€',
                accent: AppColors.warmGold,
                onTap: () => onNavigate(7),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.accent,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primaryGreen;
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.lightGreenBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.lightGreenText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

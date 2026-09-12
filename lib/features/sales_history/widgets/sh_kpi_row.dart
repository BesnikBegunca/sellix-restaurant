import 'package:flutter/material.dart';

import '../models/sales_models.dart';
import '../../../theme/app_colors.dart';
import 'sh_kpi_card.dart';
import '../../../l10n/tr.dart';

class SHKpiRow extends StatelessWidget {
  const SHKpiRow({super.key, required this.analytics});

  final SalesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SHKpiCard(
              icon: Icons.attach_money_outlined,
              label: tr.ardhuratTotale,
              value: '${a.grossRevenue.toStringAsFixed(2)}€',
              badge: a.totalSales > 0 ? '+${a.totalSales} orders' : null,
              accentColor: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SHKpiCard(
              icon: Icons.shopping_cart_outlined,
              label: tr.porosiGjithsej,
              value: '${a.totalSales}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SHKpiCard(
              icon: Icons.trending_up_outlined,
              label: tr.vleraMesatare,
              value: '${a.avgOrderValue.toStringAsFixed(2)}€',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SHKpiCard(
              icon: Icons.inventory_2_outlined,
              label: tr.artikujShitur,
              value: '${a.totalItemsSold}',
            ),
          ),
        ],
      ),
    );
  }
}

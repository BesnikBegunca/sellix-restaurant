import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../../../l10n/tr.dart';

class TopEmployeePanel extends StatelessWidget {
  const TopEmployeePanel({super.key, required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = m.employeeSalesSorted;

    if (sorted.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            icon: Icons.emoji_events_outlined,
            title: tr.realizimiSipasPunetoreve,
            subtitle:
                'Renditet sipas PRINTO — jo sipas pagesës. Çdo printim e rrit totalin.',
          ),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    size: 36,
                    color: AppColors.lightGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr.asnjeShitjeRegjistruarEnde,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.mediumGreenText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr.shitjetDoShfaqenKetuPasiRegjistroni,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final top = sorted.first;
    final maxSales = top.value > 0 ? top.value : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PanelHeader(
          icon: Icons.emoji_events_outlined,
          title: tr.realizimiSipasPunetoreve,
          subtitle:
              'Renditet sipas PRINTO — jo sipas pagesës. Çdo printim e rrit totalin.',
        ),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.warmGold.withValues(alpha: 0.12),
                AppColors.warmGold.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.warmGold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warmGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.emoji_events,
                  size: 34,
                  color: AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.punetoriMire,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightGreenText,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      top.key,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreenText,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${top.value.toStringAsFixed(2)}€',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmGold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'totale',
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
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppTheme.cardShadow(context),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr.punetori,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightGreenText,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'SHITJET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightGreenText,
                          letterSpacing: 0.6,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: AppColors.lightGreenBorder),
                _TopEmployeeRow(
                  rank: i + 1,
                  name: sorted[i].key,
                  sales: sorted[i].value,
                  maxSales: maxSales,
                  isLast: i == sorted.length - 1,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TopEmployeeRow extends StatelessWidget {
  const _TopEmployeeRow({
    required this.rank,
    required this.name,
    required this.sales,
    required this.maxSales,
    required this.isLast,
  });

  final int rank;
  final String name;
  final double sales;
  final double maxSales;
  final bool isLast;

  Color get _rankColor {
    if (rank == 1) return AppColors.warmGold;
    if (rank == 2) return const Color(0xFF9E9E9E);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.lightGreenText;
  }

  @override
  Widget build(BuildContext context) {
    final progress = maxSales > 0 ? sales / maxSales : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(17))
            : BorderRadius.zero,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: rank <= 3 ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.lightGreenBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rank == 1
                          ? AppColors.warmGold
                          : AppColors.primaryGreen.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(
              '${sales.toStringAsFixed(2)}€',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: rank == 1 ? AppColors.warmGold : AppColors.darkGreenText,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

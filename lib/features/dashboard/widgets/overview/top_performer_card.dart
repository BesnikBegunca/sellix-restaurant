import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/app_card.dart';
import '../../../../l10n/tr.dart';

class TopPerformerCard extends StatelessWidget {
  const TopPerformerCard({super.key, required this.m});
  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    final hasData = top.key != '—' && top.value > 0;

    final topOrders = hasData
        ? (m.waiterPrintCounts[top.key] ?? 0)
        : 0;

    return AppCard(
      title: tr.performuesiDites,
      subtitle: tr.kamarieriShitjetLarta,
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          top.key.length >= 2
                              ? top.key
                                    .split(' ')
                                    .map((w) => w.isEmpty ? '' : w[0])
                                    .take(2)
                                    .join()
                              : top.key[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            top.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          Text(
                            'Kamarier',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.lightGreenBorder, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.shitje,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${top.value.toStringAsFixed(0)}€',
                            style: TextStyle(
                              fontSize: 20,
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
                          Text(
                            'PRINTO',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$topOrders',
                            style: TextStyle(
                              fontSize: 20,
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
            )
          : Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  tr.nukKaShitjeEndeKrahasuarStafin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ),
            ),
    );
  }
}

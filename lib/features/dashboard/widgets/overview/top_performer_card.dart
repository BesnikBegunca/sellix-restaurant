import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/dashboard/app_card.dart';

class TopPerformerCard extends StatelessWidget {
  const TopPerformerCard({super.key, required this.m});
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

    return AppCard(
      title: 'Performuesi i ditës',
      subtitle: 'Kamarieri me shitjet më të larta.',
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
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
                          style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.lightGreenBorder, height: 1),
                const SizedBox(height: 14),
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
                          const Text(
                            'Porosi sot',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$topOrders',
                            style: const TextStyle(
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
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nuk ka shitje ende për të krahasuar stafin.',
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

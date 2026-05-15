import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';

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

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class SHTopProductsCard extends StatelessWidget {
  const SHTopProductsCard({super.key, required this.products});

  final List<({String name, double revenue, int qty})> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produktet Kryesore',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          for (final p in products.take(4)) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                      Text(
                        '${p.qty} shitur',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${p.revenue.toStringAsFixed(0)}€',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

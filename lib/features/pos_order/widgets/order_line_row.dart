import 'package:flutter/material.dart';

import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/image_utils.dart';
import 'cart_line.dart';
import 'qty_button.dart';

class OrderLineRow extends StatelessWidget {
  const OrderLineRow({
    super.key,
    required this.line,
    required this.onMinus,
    required this.onPlus,
  });

  final CartLine line;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: line.product.imagePath != null
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: productImage(
                      line.product.imagePath,
                      fit: BoxFit.contain,
                    ),
                  )
                : Text(
                    line.product.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreenText,
                  ),
                ),
                Text(
                  '${line.product.price.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              QtyButton(label: '−', onPressed: onMinus),
              SizedBox(
                width: 24,
                child: Text(
                  '${line.qty}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ),
              QtyButton(label: '+', onPressed: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

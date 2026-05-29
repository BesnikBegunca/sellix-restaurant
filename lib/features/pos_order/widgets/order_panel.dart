import 'package:flutter/material.dart';

import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import 'cart_line.dart';
import 'order_line_row.dart';
import 'pay_button.dart';
import 'send_order_button.dart';

class OrderPanel extends StatelessWidget {
  const OrderPanel({
    super.key,
    required this.tableNumber,
    required this.orderNumber,
    required this.lines,
    required this.total,
    required this.onDelta,
    required this.onSend,
    required this.onPay,
    this.canPay = false,
    this.isPaying = false,
    this.isSendingOrder = false,
  });

  final int tableNumber;
  final int orderNumber;
  final List<CartLine> lines;
  final double total;
  /// Pagesë e lejuar: tavolinë e zënë (e hapur) ose artikuj në listë.
  final bool canPay;
  final void Function(ProductItem p, int delta) onDelta;
  final VoidCallback onSend;
  final VoidCallback onPay;
  final bool isPaying;
  final bool isSendingOrder;

  @override
  Widget build(BuildContext context) {
    final empty = lines.isEmpty;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Porosia aktuale',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '#${orderNumber.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.lightGreenText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.table_restaurant_outlined,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tavolina $tableNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: empty
                ? const Center(
                    child: Text(
                      'Ende pa artikuj',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final l = lines[i];
                      return OrderLineRow(
                        line: l,
                        onMinus: () => onDelta(l.product, -1),
                        onPlus: () => onDelta(l.product, 1),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle(0.1)),
              ),
            ),
            child: _moneyRow('Totali', total, large: true),
          ),
          const SizedBox(height: 24),
          SendOrderButton(
            enabled: !empty && !isSendingOrder && !isPaying,
            isSending: isSendingOrder,
            onSend: onSend,
          ),
          const SizedBox(height: 10),
          PayButton(
            enabled: canPay && !isPaying && !isSendingOrder,
            onPay: onPay,
            isPaying: isPaying,
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount, {required bool large}) {
    final style = TextStyle(
      fontSize: large ? 24 : 16,
      fontWeight: large ? FontWeight.w500 : FontWeight.w400,
      color: large ? AppColors.darkGreenText : AppColors.mediumGreenText,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text('${amount.toStringAsFixed(2)}€', style: style),
      ],
    );
  }
}


import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../models/sales_models.dart';
import 'adjustment_row.dart';

class SaleCard extends StatelessWidget {
  const SaleCard({
    super.key,
    required this.data,
    required this.expanded,
    required this.onToggle,
    this.onRefund,
    this.onDelete,
    this.onReprint,
  });

  final SaleWithLines data;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onRefund;
  final VoidCallback? onDelete;
  final VoidCallback? onReprint;

  @override
  Widget build(BuildContext context) {
    final sale = data.sale;
    final lines = data.lines;

    final ts = sale.timestamp;
    final dateStr =
        '${ts.day.toString().padLeft(2, '0')}.${ts.month.toString().padLeft(2, '0')}.${ts.year}';
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    final orderId =
        'ORD-${(sale.dbId ?? 0).toString().padLeft(3, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expanded
              ? AppColors.primaryGreen.withValues(alpha: 0.25)
              : AppColors.lightGreenBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── header row ─────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(expanded ? 0 : 14),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Table number badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'T${sale.tableId}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Order ID + date/waiter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderId,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$dateStr at $timeStr  •  ${sale.waiterName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sale.total.toStringAsFixed(2)}€',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: expanded
                          ? AppColors.primaryGreen
                          : AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── expanded line items ────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildLineItems(
              lines,
              data.adjustments,
              onRefund,
              onDelete,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItems(
    List<SaleLineRow> lines,
    List<SaleAdjustmentRow> adjustments,
    VoidCallback? onRefund,
    VoidCallback? onDelete,
  ) {
    final linesTotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final adjTotal = adjustments.fold(0.0, (s, a) => s + a.amount);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F8F4),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1),
          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'Artikujt e Porosisë',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const Spacer(),
                Text(
                  '${lines.length} artikull${lines.length == 1 ? '' : 'ë'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGreenText,
                  ),
                ),
              ],
            ),
          ),
          // Line items
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  // Quantity circle
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${line.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Emoji
                  Text(line.productEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  // Product name
                  Expanded(
                    child: Text(
                      line.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ),
                  // Unit price (small)
                  Text(
                    '${line.productPrice.toStringAsFixed(2)}€ × ${line.quantity}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Line total
                  Text(
                    '${line.lineTotal.toStringAsFixed(2)}€',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ],
              ),
            ),
          // Adjustment rows
          if (adjustments.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            for (final adj in adjustments) AdjustmentRow(adj: adj),
          ],
          // Footer
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                if (onDelete != null)
                  FilledButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('Fshi porosinë'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.negativeText,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (onReprint != null) ...[
                  if (onDelete != null) const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onReprint,
                    icon: const Icon(Icons.print_outlined, size: 14),
                    label: const Text('Ridërgo kuponin'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: BorderSide(color: AppColors.lightGreenBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (onRefund != null) ...[
                  if (onDelete != null || onReprint != null)
                    const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onRefund,
                    icon: const Icon(Icons.undo_outlined, size: 14),
                    label: const Text('Rimburso'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negativeText,
                      side: BorderSide(
                        color: AppColors.negativeText.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                const Spacer(),
                if (adjTotal > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Nëntotali  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGreenText,
                            ),
                          ),
                          Text(
                            '${linesTotal.toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Refund  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.negativeText,
                            ),
                          ),
                          Text(
                            '-${adjTotal.toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.negativeText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Totali Neto  ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          Text(
                            '${(linesTotal - adjTotal).toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Text(
                        'Totali  ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                      Text(
                        '${linesTotal.toStringAsFixed(2)}€',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

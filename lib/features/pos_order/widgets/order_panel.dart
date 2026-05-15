import 'package:flutter/material.dart';

import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/image_utils.dart';
import 'cart_line.dart';

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
  });

  final int tableNumber;
  final int orderNumber;
  final List<CartLine> lines;
  final double total;
  final void Function(ProductItem p, int delta) onDelta;
  final VoidCallback onSend;
  final VoidCallback onPay;

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
                      return _OrderLineRow(
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
          _SendOrderButton(enabled: !empty, onSend: onSend),
          const SizedBox(height: 10),
          _PayButton(onPay: onPay),
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
        Text('\$${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({
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
                  '\$${line.product.price.toStringAsFixed(2)}',
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
              _QtyButton(label: '−', onPressed: onMinus),
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
              _QtyButton(label: '+', onPressed: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatefulWidget {
  const _QtyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_QtyButton> createState() => _QtyButtonState();
}

class _QtyButtonState extends State<_QtyButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? AppColors.lightGreenBg : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderVisible(0.2)),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 20,
              color: AppColors.primaryGreen,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendOrderButton extends StatefulWidget {
  const _SendOrderButton({required this.enabled, required this.onSend});

  final bool enabled;
  final VoidCallback onSend;

  @override
  State<_SendOrderButton> createState() => _SendOrderButtonState();
}

class _SendOrderButtonState extends State<_SendOrderButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = !widget.enabled
        ? AppColors.lightGreenText
        : (_hover ? AppColors.darkerGreenHover : AppColors.primaryGreen);
    final scale = widget.enabled
        ? (_pressed ? 0.95 : (_hover ? 1.05 : 1.0))
        : 1.0;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.enabled ? widget.onSend : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PRINTO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatefulWidget {
  const _PayButton({required this.onPay});

  final VoidCallback onPay;

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPay,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : (_hover ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? AppColors.lightGreenBg : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hover
                    ? AppColors.primaryGreen
                    : AppColors.borderVisible(0.25),
                width: _hover ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: _hover
                      ? AppColors.primaryGreen
                      : AppColors.mediumGreenText,
                ),
                const SizedBox(width: 8),
                Text(
                  'PAGUAJ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: _hover
                        ? AppColors.primaryGreen
                        : AppColors.mediumGreenText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

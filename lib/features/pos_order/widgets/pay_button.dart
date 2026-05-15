import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class PayButton extends StatefulWidget {
  const PayButton({super.key, required this.onPay});

  final VoidCallback onPay;

  @override
  State<PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<PayButton> {
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

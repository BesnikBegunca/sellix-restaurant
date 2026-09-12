import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class PayButton extends StatefulWidget {
  const PayButton({
    super.key,
    required this.enabled,
    required this.onPay,
    this.isPaying = false,
  });

  final bool enabled;
  final VoidCallback onPay;
  final bool isPaying;

  @override
  State<PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<PayButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isPaying) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderVisible(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.mediumGreenText,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'PAGUAJ...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.mediumGreenText,
              ),
            ),
          ],
        ),
      );
    }

    final canTap = widget.enabled && !widget.isPaying;
    final scale = canTap
        ? (_pressed ? 0.95 : (_hover ? 1.02 : 1.0))
        : 1.0;
    return MouseRegion(
      cursor: canTap
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) {
        if (canTap) setState(() => _hover = true);
      },
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          if (canTap) setState(() => _pressed = true);
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: canTap ? widget.onPay : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !widget.enabled
                  ? AppColors.lightGreenBg.withValues(alpha: 0.35)
                  : (_hover ? AppColors.lightGreenBg : AppColors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !widget.enabled
                    ? AppColors.borderVisible(0.12)
                    : (_hover
                        ? AppColors.primaryGreen
                        : AppColors.borderVisible(0.25)),
                width: _hover && widget.enabled ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: !widget.enabled
                      ? AppColors.lightGreenText
                      : (_hover
                          ? AppColors.primaryGreen
                          : AppColors.mediumGreenText),
                ),
                const SizedBox(width: 8),
                Text(
                  'PAGUAJ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: !widget.enabled
                        ? AppColors.lightGreenText
                        : (_hover
                            ? AppColors.primaryGreen
                            : AppColors.mediumGreenText),
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

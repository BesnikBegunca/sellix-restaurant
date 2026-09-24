import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Issues an ATK fiscal coupon for the lines currently on the order.
///
/// Deliberately built like [SendOrderButton] — same size, same press
/// behaviour, same busy state — because it is the same gesture for the
/// waiter; only what comes out of the printer differs.
class FiscalCouponButton extends StatefulWidget {
  const FiscalCouponButton({
    super.key,
    required this.enabled,
    required this.onIssue,
    this.isIssuing = false,
  });

  final bool enabled;
  final VoidCallback onIssue;
  final bool isIssuing;

  @override
  State<FiscalCouponButton> createState() => _FiscalCouponButtonState();
}

class _FiscalCouponButtonState extends State<FiscalCouponButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isIssuing) {
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
            const SizedBox(width: 10),
            Text(
              'KUPON FISKAL...',
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

    final canTap = widget.enabled;
    final scale = canTap ? (_pressed ? 0.95 : (_hover ? 1.02 : 1.0)) : 1.0;
    final fg = !canTap
        ? AppColors.lightGreenText
        : (_hover ? AppColors.primaryGreen : AppColors.mediumGreenText);

    return MouseRegion(
      cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
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
        onTap: canTap ? widget.onIssue : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !canTap
                  ? AppColors.lightGreenBg.withValues(alpha: 0.35)
                  : (_hover ? AppColors.lightGreenBg : AppColors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !canTap
                    ? AppColors.borderVisible(0.12)
                    : (_hover
                        ? AppColors.primaryGreen
                        : AppColors.borderVisible(0.25)),
                width: _hover && canTap ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 20, color: fg),
                const SizedBox(width: 8),
                Text(
                  'KUPON FISKAL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: fg,
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

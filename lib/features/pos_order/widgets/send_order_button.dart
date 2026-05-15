import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class SendOrderButton extends StatefulWidget {
  const SendOrderButton({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final VoidCallback onSend;

  @override
  State<SendOrderButton> createState() => _SendOrderButtonState();
}

class _SendOrderButtonState extends State<SendOrderButton> {
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

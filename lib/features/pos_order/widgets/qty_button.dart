import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class QtyButton extends StatefulWidget {
  const QtyButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<QtyButton> createState() => _QtyButtonState();
}

class _QtyButtonState extends State<QtyButton> {
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

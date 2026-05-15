import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HoverSmallChip extends StatefulWidget {
  const HoverSmallChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<HoverSmallChip> createState() => _HoverSmallChipState();
}

class _HoverSmallChipState extends State<HoverSmallChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? AppColors.lightGreenBg : AppColors.beige,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle(0.1)),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGreenText,
            ),
          ),
        ),
      ),
    );
  }
}

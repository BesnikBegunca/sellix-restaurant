import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NumKeyBody extends StatefulWidget {
  const NumKeyBody({super.key, required this.label});

  final String label;

  @override
  State<NumKeyBody> createState() => _NumKeyBodyState();
}

class _NumKeyBodyState extends State<NumKeyBody> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover ? AppColors.lightGreenBg : AppColors.beige,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle(0.1)),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(fontSize: 32, color: AppColors.darkGreenText),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../staff_pin_display.dart';

class ManagerGridCard extends StatefulWidget {
  const ManagerGridCard({
    super.key,
    required this.initials,
    required this.name,
    this.pinView,
    this.onRevealPin,
    required this.onDelete,
  });

  final String initials;
  final String name;
  final String? pinView;
  final Future<void> Function()? onRevealPin;
  final VoidCallback onDelete;

  @override
  State<ManagerGridCard> createState() => _ManagerGridCardState();
}

class _ManagerGridCardState extends State<ManagerGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                : AppColors.lightGreenBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? AppColors.primaryGreen.withValues(alpha: 0.06)
                  : const Color(0x08000000),
              blurRadius: _hovered ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.initials,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  StaffPinDisplay(
                    pinView: widget.pinView,
                    onRevealTap: widget.onRevealPin,
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered ? 1.0 : 0.35,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.softRed.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: _hovered
                        ? AppColors.softRed
                        : AppColors.mediumGreenText,
                  ),
                  onPressed: widget.onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

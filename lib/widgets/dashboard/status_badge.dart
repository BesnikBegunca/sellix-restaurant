import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

enum StatusBadgeVariant {
  /// Free, paid, active — soft green
  success,

  /// Occupied, pending — soft orange
  warning,

  /// Reserved, info — soft blue
  info,

  /// Cancelled, error — soft red
  error,

  /// Inactive — muted green tint
  neutral,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = StatusBadgeVariant.neutral,
    this.compact = false,
  });

  final String label;
  final StatusBadgeVariant variant;
  final bool compact;

  ({Color bg, Color fg, Color border}) _colors() {
    switch (variant) {
      case StatusBadgeVariant.success:
        return (
          bg: AppColors.softGreenTint,
          fg: AppColors.deepForestGreen,
          border: AppColors.lightGreenBorder,
        );
      case StatusBadgeVariant.warning:
        return (
          bg: AppColors.accentOrange.withValues(alpha: 0.22),
          fg: AppColors.charcoalText,
          border: AppColors.accentOrange.withValues(alpha: 0.45),
        );
      case StatusBadgeVariant.info:
        return (
          bg: AppColors.accentBlue.withValues(alpha: 0.14),
          fg: AppColors.charcoalText,
          border: AppColors.accentBlue.withValues(alpha: 0.35),
        );
      case StatusBadgeVariant.error:
        return (
          bg: AppColors.accentRed.withValues(alpha: 0.12),
          fg: AppColors.accentRed,
          border: AppColors.accentRed.withValues(alpha: 0.35),
        );
      case StatusBadgeVariant.neutral:
        return (
          bg: AppColors.softGreenTint.withValues(alpha: 0.65),
          fg: AppColors.mutedGray,
          border: AppColors.lightGreenBorder,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 12 : AppTokens.tableTextSize,
          fontWeight: FontWeight.w600,
          color: c.fg,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.name,
    this.radius = 20,
    this.tooltip,
  });

  final String? name;
  final double radius;
  final String? tooltip;

  String get _initials {
    final n = name?.trim();
    if (n == null || n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final w = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.softGreenTint,
      foregroundColor: AppColors.deepForestGreen,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: w);
    }
    return w;
  }
}

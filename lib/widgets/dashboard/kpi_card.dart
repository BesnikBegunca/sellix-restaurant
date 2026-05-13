import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Premium KPI tile: white card, border, icon box, muted label, large value.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.trendLabel,
    this.trendPositive,
    this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  /// e.g. "+12%" — shown with green/red tint when [trendPositive] is set.
  final String? trendLabel;
  final bool? trendPositive;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final trendColor = trendPositive == null
        ? AppColors.mutedGray
        : (trendPositive!
              ? AppColors.successGreen
              : AppColors.accentRed);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          border: Border.all(color: AppColors.lightGreenBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.softGreenTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: AppColors.deepForestGreen,
                      size: 24,
                    ),
                  ),
                  if (trendLabel != null) ...[
                    const Spacer(),
                    Text(
                      trendLabel!,
                      style: TextStyle(
                        fontSize: AppTokens.tableTextSize,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: AppTokens.metaTextSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedGray,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: AppTokens.kpiValueSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoalText,
                    height: 1.05,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: AppTokens.tableTextSize,
                    color: AppColors.mutedGray,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

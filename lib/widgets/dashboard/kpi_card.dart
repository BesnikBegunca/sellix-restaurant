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
    this.accentColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;

  /// e.g. "+12%" — shown with green/red tint when [trendPositive] is set.
  final String? trendLabel;
  final bool? trendPositive;
  final double? width;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trendColor = trendPositive == null
        ? AppColors.mutedGray
        : (trendPositive! ? AppColors.successGreen : AppColors.accentRed);

    final accent = accentColor ?? AppColors.deepForestGreen;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: AppColors.charcoalText.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
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
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 24),
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
              style: TextStyle(
                fontSize: AppTokens.metaTextSize,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
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
                style: TextStyle(
                  fontSize: AppTokens.kpiValueSize,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.05,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: AppTokens.tableTextSize,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final sized = SizedBox(width: width, child: card);
    if (onTap == null) return sized;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: card,
        ),
      ),
    );
  }
}

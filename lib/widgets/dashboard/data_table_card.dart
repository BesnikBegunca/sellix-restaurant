import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Card wrapper tuned for [DataTable] / wide tabular content.
class DataTableCard extends StatelessWidget {
  const DataTableCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.table,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget table;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoalText.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.cardPadding,
                vertical: 18,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.lightGreenBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: AppTokens.sectionTitleSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoalText,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: AppTokens.metaTextSize,
                              color: AppColors.mutedGray,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.cardPadding),
                child: table,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

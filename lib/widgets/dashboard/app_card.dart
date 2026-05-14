import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// White surface card with subtle border — base for dashboard sections.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.cardPadding),
    this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoalText.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || trailing != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: const TextStyle(
                              fontSize: AppTokens.sectionTitleSize,
                              fontWeight: FontWeight.w600,
                              color: AppColors.charcoalText,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: AppTokens.metaTextSize,
                                height: 1.35,
                                color: AppColors.mutedGray,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailing case final w?) w,
                ],
              ),
            if (title != null || trailing != null) const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  List<Widget>? actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppColors.pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          side: const BorderSide(color: AppColors.lightGreenBorder),
        ),
        title: DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: AppTokens.sectionTitleSize,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoalText,
          ),
          child: title,
        ),
        content: DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: AppTokens.bodySize,
            color: AppColors.charcoalText,
            height: 1.4,
          ),
          child: content,
        ),
        actions: actions,
      );
    },
  );
}

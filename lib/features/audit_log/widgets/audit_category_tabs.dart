import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'audit_log_card.dart';

class AuditCategoryTabs extends StatelessWidget {
  const AuditCategoryTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AuditCategoryFilter selected;
  final void Function(AuditCategoryFilter) onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (AuditCategoryFilter.all,      Icons.bar_chart_outlined,    'Të gjitha'),
      (AuditCategoryFilter.security, Icons.shield_outlined,       'Siguri'),
      (AuditCategoryFilter.payments, Icons.attach_money_outlined, 'Pagesat'),
      (AuditCategoryFilter.settings, Icons.settings_outlined,     'Cilësimet'),
      (AuditCategoryFilter.users,    Icons.person_outline,        'Përdoruesit'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (filter, icon, label) in tabs)
          GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected == filter
                    ? AppColors.primaryGreen
                    : AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected == filter
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected == filter
                        ? Colors.white
                        : AppColors.mediumGreenText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected == filter
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == filter
                          ? Colors.white
                          : AppColors.darkGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

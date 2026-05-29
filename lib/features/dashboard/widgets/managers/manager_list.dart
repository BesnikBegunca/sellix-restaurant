import 'package:flutter/material.dart';

import '../../../../models/pos_models.dart';
import '../../../../theme/app_colors.dart';
import 'manager_grid_card.dart';

class ManagerList extends StatelessWidget {
  const ManagerList({
    super.key,
    required this.managers,
    required this.onRemove,
  });

  final List<ManagerInfo> managers;
  final void Function(int) onRemove;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (managers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lightGreenBorder),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.supervisor_account_outlined,
              size: 48,
              color: AppColors.lightGreenBorder,
            ),
            SizedBox(height: 16),
            Text(
              'Nuk ka menaxherë ende',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Shto menaxherin e parë me formularin më sipër.',
              style: TextStyle(fontSize: 13, color: AppColors.lightGreenText),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 4.5,
      ),
      itemCount: managers.length,
      itemBuilder: (context, i) {
        final mgr = managers[i];
        return ManagerGridCard(
          initials: _initials(mgr.name),
          name: mgr.name,
          onDelete: () => onRemove(i),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import 'waiter_grid_card.dart';

class WaiterList extends StatelessWidget {
  const WaiterList({
    required this.waiters,
    required this.waiterSales,
    required this.onRemove,
    required this.m,
  });
  final List<dynamic> waiters;
  final Map<String, double> waiterSales;
  final void Function(int) onRemove;
  final ManagerData m;

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    if (waiters.isEmpty) {
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
              Icons.badge_outlined,
              size: 48,
              color: AppColors.lightGreenBorder,
            ),
            SizedBox(height: 16),
            Text(
              'Nuk ka kamarierë ende',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add a waiter using the form above.',
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
      itemCount: waiters.length,
      itemBuilder: (context, i) {
        final w = waiters[i];
        final name = w.name as String;
        final pin = w.pin as String;
        final salary = m.getSalary(name);
        final initials = _initials(name);

        return WaiterGridCard(
          initials: initials,
          name: name,
          pin: pin,
          salary: salary,
          onDelete: () => onRemove(i),
        );
      },
    );
  }
}

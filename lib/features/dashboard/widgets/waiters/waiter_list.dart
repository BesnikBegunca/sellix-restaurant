import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../staff_pin_reveal_dialog.dart';
import 'waiter_grid_card.dart';

class WaiterList extends StatelessWidget {
  const WaiterList({
    required this.waiters,
    required this.waiterSales,
    required this.onRemove,
    required this.m,
  });
  final List<WaiterInfo> waiters;
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
    final scheme = Theme.of(context).colorScheme;
    if (waiters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
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
        final name = w.name;
        final pinView = w.pinView;
        final salary = m.getSalary(name);
        final initials = _initials(name);

        return WaiterGridCard(
          initials: initials,
          name: name,
          pinView: pinView,
          onRevealPin: pinView == null || pinView.isEmpty
              ? () => _revealWaiterPin(context, i)
              : null,
          salary: salary,
          onDelete: () => onRemove(i),
        );
      },
    );
  }

  Future<void> _revealWaiterPin(BuildContext context, int index) async {
    final name = waiters[index].name;
    final pin = await showStaffPinRevealDialog(context, staffName: name);
    if (pin == null || !context.mounted) return;
    final ok = await m.revealWaiterPinAt(index, pin);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN i gabuar.'),
          backgroundColor: AppColors.softRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';

import '../../../../models/pos_models.dart';
import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';
import '../staff_pin_reveal_dialog.dart';
import 'manager_grid_card.dart';

class ManagerList extends StatelessWidget {
  const ManagerList({
    super.key,
    required this.managers,
    required this.onRemove,
    required this.m,
  });

  final List<ManagerInfo> managers;
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
    if (managers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.lightGreenBorder),
        ),
        child: Column(
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
          pinView: mgr.pinView,
          onRevealPin: mgr.pinView == null || mgr.pinView!.isEmpty
              ? () => _revealManagerPin(context, i)
              : null,
          onDelete: () => onRemove(i),
        );
      },
    );
  }

  Future<void> _revealManagerPin(BuildContext context, int index) async {
    final name = managers[index].name;
    final pin = await showStaffPinRevealDialog(context, staffName: name);
    if (pin == null || !context.mounted) return;
    final ok = await m.revealManagerPinAt(index, pin);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PIN i gabuar.'),
          backgroundColor: AppColors.softRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

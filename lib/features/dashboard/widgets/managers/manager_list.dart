import 'package:flutter/material.dart';

import '../../../../models/pos_models.dart';
import '../../../../manager/manager_data.dart';
import '../staff_pin_reveal_dialog.dart';
import 'manager_grid_card.dart';
import '../../../../l10n/tr.dart';

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
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.supervisor_account_outlined,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              tr.nukKaMenaxhereEnde,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr.shtoMenaxherinPareFormularinSiper,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        // Keep cards a readable width instead of always forcing two columns.
        final columns = c.maxWidth >= 1180
            ? 3
            : c.maxWidth >= 640
            ? 2
            : 1;
        return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 76,
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
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

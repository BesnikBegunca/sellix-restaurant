import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';

class ManagerSideNav extends StatelessWidget {
  const ManagerSideNav({
    super.key,
    required this.expanded,
    required this.selectedIndex,
    required this.onToggle,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final bool expanded;
  final int selectedIndex;
  final VoidCallback onToggle;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  static const _items = <({IconData icon, IconData sel, String label})>[
    (icon: Icons.dashboard_outlined, sel: Icons.dashboard,       label: 'Përmbledhje'),
    (icon: Icons.schedule_outlined,  sel: Icons.schedule,        label: 'Gjendja'),
    (icon: Icons.badge_outlined,     sel: Icons.badge,           label: 'Kamarierët'),
    (icon: Icons.table_rows_outlined,sel: Icons.table_rows,      label: 'Shpenzime'),
    (icon: Icons.trending_up_outlined,sel: Icons.trending_up,    label: 'Fitime'),
    (icon: Icons.description_outlined,sel: Icons.description,    label: 'Raporte'),
    (icon: Icons.emoji_events_outlined,sel: Icons.emoji_events,  label: 'Top puntor'),
    (icon: Icons.menu_book_outlined, sel: Icons.menu_book,       label: 'Menu'),
    (icon: Icons.grid_view_outlined, sel: Icons.grid_view,       label: 'Tavolinat'),
    (icon: Icons.settings_outlined,  sel: Icons.settings,        label: 'Cilësimet'),
    (icon: Icons.payments_outlined,  sel: Icons.payments,        label: 'Pagat'),
    (icon: Icons.history_outlined,   sel: Icons.history,         label: 'Historiku'),
    (icon: Icons.security_outlined,  sel: Icons.security,        label: 'Audit'),
  ];

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final m = ManagerData.instance;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: expanded ? 256 : 80,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(color: AppColors.lightGreenBorder),
        ),
      ),
      child: ClipRect(
        child: Column(
          children: [
            SizedBox(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (expanded) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: AppColors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Menaxher POS',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: expanded ? 'Mbyll' : 'Hap',
                      onPressed: onToggle,
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_double_arrow_left
                            : Icons.menu,
                        size: 20,
                        color: AppColors.mediumGreenText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: AppColors.lightGreenBorder),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final it = _items[i];
                  final sel = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _SideNavItem(
                      icon: sel ? it.sel : it.icon,
                      label: it.label,
                      selected: sel,
                      expanded: expanded,
                      onTap: () => onDestinationSelected(i),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1, thickness: 1, color: AppColors.lightGreenBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: expanded
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Dil'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.mediumGreenText,
                          side: const BorderSide(color: AppColors.lightGreenBorder),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : Tooltip(
                      message: 'Dil',
                      child: InkWell(
                        onTap: onLogout,
                        borderRadius: BorderRadius.circular(12),
                        child: const SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: Icon(
                            Icons.logout,
                            size: 20,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final showBg = active || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: showBg ? AppColors.lightGreenBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              if (active)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

              Row(
                children: [
                  SizedBox(
                    width: widget.expanded ? 44 : 56,
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: active
                            ? AppColors.primaryGreen
                            : AppColors.mediumGreenText,
                      ),
                    ),
                  ),
                  if (widget.expanded)
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                          color: active
                              ? AppColors.primaryGreen
                              : AppColors.mediumGreenText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

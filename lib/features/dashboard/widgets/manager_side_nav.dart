import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../services/app_language_service.dart';
import '../../../widgets/gg_header.dart';
import '../../../l10n/tr.dart';

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

  static List<({IconData icon, IconData sel, String sq, String en})>
  get _items => <({IconData icon, IconData sel, String sq, String en})>[
    (
      icon: Icons.dashboard_outlined,
      sel: Icons.dashboard,
      sq: tr.permbledhje,
      en: 'Overview',
    ),
    (
      icon: Icons.schedule_outlined,
      sel: Icons.schedule,
      sq: tr.gjendja,
      en: 'Shift',
    ),
    (
      icon: Icons.groups_2_outlined,
      sel: Icons.groups_2,
      sq: 'Stafi',
      en: 'Staff',
    ),
    (
      icon: Icons.table_rows_outlined,
      sel: Icons.table_rows,
      sq: tr.shpenzime,
      en: 'Expenses',
    ),
    (
      icon: Icons.trending_up_outlined,
      sel: Icons.trending_up,
      sq: tr.fitime,
      en: 'Profits',
    ),
    (
      icon: Icons.receipt_long_outlined,
      sel: Icons.receipt_long,
      sq: tr.shitjet,
      en: 'Sales',
    ),
    (
      icon: Icons.emoji_events_outlined,
      sel: Icons.emoji_events,
      sq: 'Top puntor',
      en: 'Top employee',
    ),
    (
      icon: Icons.menu_book_outlined,
      sel: Icons.menu_book,
      sq: tr.menu,
      en: tr.menu,
    ),
    (
      icon: Icons.grid_view_outlined,
      sel: Icons.grid_view,
      sq: tr.tavolinat,
      en: 'Tables',
    ),
    (
      icon: Icons.settings_outlined,
      sel: Icons.settings,
      sq: tr.cilesimet,
      en: 'Settings',
    ),
    (
      icon: Icons.lock_outline,
      sel: Icons.lock,
      sq: 'Permissions',
      en: 'Permissions',
    ),
    (
      icon: Icons.payments_outlined,
      sel: Icons.payments,
      sq: 'Pagat',
      en: 'Payroll',
    ),
    (icon: Icons.undo_outlined, sel: Icons.undo, sq: 'Refund', en: 'Refunds'),
    (
      icon: Icons.history_outlined,
      sel: Icons.history,
      sq: 'Historiku',
      en: 'History',
    ),
    (
      icon: Icons.security_outlined,
      sel: Icons.security,
      sq: 'Audit',
      en: 'Audit log',
    ),
    (
      icon: Icons.receipt_long_outlined,
      sel: Icons.receipt_long,
      sq: 'Fiskalizimi',
      en: 'Fiscalisation',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(builder: (context) => _buildRail(context)),
    );
  }

  Widget _buildRail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: AppLanguageService.instance,
      builder: (context, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: expanded ? 256 : 80,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFF101A16),
          border: Border(right: BorderSide(color: scheme.outline.withValues(alpha: 0.35))),
        ),
        child: ClipRect(
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 8),
                  child: expanded
                      ? Row(
                          children: [
                            const GgLogoBox(size: 32, radius: 8),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Menaxher POS',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _ToggleButton(
                              expanded: expanded,
                              onPressed: onToggle,
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GgLogoBox(size: 28, radius: 6),
                            const SizedBox(height: 6),
                            _ToggleButton(
                              expanded: expanded,
                              onPressed: onToggle,
                            ),
                          ],
                        ),
                ),
              ),

              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),

              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    expanded ? 12 : 8,
                    12,
                    expanded ? 12 : 8,
                    0,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final sel = i == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _SideNavItem(
                        icon: sel ? it.sel : it.icon,
                        label: AppLanguageService.instance.t(it.sq, it.en),
                        selected: sel,
                        expanded: expanded,
                        onTap: () => onDestinationSelected(i),
                      ),
                    );
                  },
                ),
              ),

              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  expanded ? 12 : 8,
                  10,
                  expanded ? 12 : 8,
                  16,
                ),
                child: expanded
                    ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout, size: 18),
                          label: Text(
                            AppLanguageService.instance.t('Dil', 'Log out'),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.onSurfaceVariant,
                            side: BorderSide(color: scheme.outlineVariant),
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
                        message: AppLanguageService.instance.t(
                          'Dil',
                          'Log out',
                        ),
                        child: InkWell(
                          onTap: onLogout,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: Icon(
                              Icons.logout,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
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

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: expanded ? tr.mbyll : 'Hap',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        expanded ? Icons.keyboard_double_arrow_left : Icons.menu,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final showBg = active || _hovered;
    final scheme = Theme.of(context).colorScheme;
    final iconColor = active ? scheme.primary : scheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: _wrapCollapsedTooltip(
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: showBg
                  ? scheme.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.hardEdge,
            child: widget.expanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (active)
                        Container(
                          width: 4,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      else
                        const SizedBox(width: 12),
                      SizedBox(
                        width: 28,
                        child: Center(
                          child: Icon(widget.icon, size: 20, color: iconColor),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      if (active)
                        Positioned(
                          left: 0,
                          top: 8,
                          bottom: 8,
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      Icon(widget.icon, size: 20, color: iconColor),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _wrapCollapsedTooltip(Widget child) {
    if (widget.expanded) return child;
    return Tooltip(message: widget.label, child: child);
  }
}

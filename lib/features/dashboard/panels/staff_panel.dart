import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../services/app_language_service.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../../../theme/app_colors.dart';
import '../widgets/staff_pin_display.dart';
import '../widgets/staff_pin_reveal_dialog.dart';
import '../../../l10n/tr.dart';

enum StaffRole { waiter, manager }

class StaffPanel extends StatefulWidget {
  const StaffPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends State<StaffPanel> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  StaffRole _role = StaffRole.waiter;
  StaffRole? _filter;
  String? _errorMsg;

  AppLanguageService get _lang => AppLanguageService.instance;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _salaryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(
        () => _errorMsg = _lang.t('Shkruaj emrin e anëtarit.', 'Enter the name.'),
      );
      return;
    }
    if (pin.length < 4 || !RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() => _errorMsg = tr.pinMinimum4ShifraVetemNumra);
      return;
    }
    if (await widget.m.staffPinExists(pin)) {
      setState(() => _errorMsg = tr.kyPinEkzistonTashme);
      return;
    }
    if (_role == StaffRole.waiter) {
      await widget.m.addWaiter(name, pin);
      if (!mounted) return;
      final salary =
          double.tryParse(_salaryCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      if (salary > 0) widget.m.setSalary(name, salary);
    } else {
      await widget.m.addManager(name, pin);
      if (!mounted) return;
    }
    _nameCtrl.clear();
    _pinCtrl.clear();
    _salaryCtrl.clear();
    setState(() => _errorMsg = null);
  }

  List<_StaffEntry> _entries() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final out = <_StaffEntry>[];
    if (_filter != StaffRole.manager) {
      for (var i = 0; i < widget.m.waiters.length; i++) {
        final w = widget.m.waiters[i];
        if (q.isNotEmpty && !w.name.toLowerCase().contains(q)) continue;
        out.add(
          _StaffEntry(
            role: StaffRole.waiter,
            index: i,
            name: w.name,
            pinView: w.pinView,
            salary: widget.m.getSalary(w.name),
          ),
        );
      }
    }
    if (_filter != StaffRole.waiter) {
      for (var i = 0; i < widget.m.managers.length; i++) {
        final mgr = widget.m.managers[i];
        if (q.isNotEmpty && !mgr.name.toLowerCase().contains(q)) continue;
        out.add(
          _StaffEntry(
            role: StaffRole.manager,
            index: i,
            name: mgr.name,
            pinView: mgr.pinView,
          ),
        );
      }
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<void> _confirmRemove(_StaffEntry entry) async {
    final roleLabel = entry.role == StaffRole.waiter
        ? _lang.t('kamarier', 'waiter')
        : _lang.t('menaxher', 'manager');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_lang.t('Hiq nga stafi', 'Remove from staff')),
        content: Text(
          _lang.t(
            'Të hiqet ${entry.name} ($roleLabel) nga stafi?',
            'Remove ${entry.name} ($roleLabel) from staff?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.anulo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negativeText,
            ),
            child: Text(tr.fshi),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (entry.role == StaffRole.waiter) {
      await widget.m.removeWaiterAt(entry.index);
    } else {
      await widget.m.removeManagerAt(entry.index);
    }
  }

  Future<void> _revealPin(_StaffEntry entry) async {
    final pin = await showStaffPinRevealDialog(context, staffName: entry.name);
    if (pin == null || !mounted) return;
    final ok = entry.role == StaffRole.waiter
        ? await widget.m.revealWaiterPinAt(entry.index, pin)
        : await widget.m.revealManagerPinAt(entry.index, pin);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_lang.t('PIN i gabuar.', 'Wrong PIN.')),
          backgroundColor: AppColors.softRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final entries = _entries();
    final waiters = m.waiters.length;
    final managers = m.managers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.groups_2_outlined,
          title: _lang.t('Stafi', 'Staff'),
          subtitle: _lang.t(
            'Kamarierët dhe menaxherët në një vend. Roli zgjidhet kur shtohet anëtari.',
            'Waiters and managers in one place. Pick the role when adding someone.',
          ),
        ),
        _StaffStatsRow(
          total: waiters + managers,
          waiters: waiters,
          managers: managers,
        ),
        const SizedBox(height: 20),
        _AddStaffComposer(
          nameCtrl: _nameCtrl,
          pinCtrl: _pinCtrl,
          salaryCtrl: _salaryCtrl,
          role: _role,
          errorMsg: _errorMsg,
          onRoleChanged: (role) => setState(() {
            _role = role;
            _errorMsg = null;
          }),
          onSubmit: _add,
        ),
        const SizedBox(height: 20),
        _StaffDirectory(
          searchCtrl: _searchCtrl,
          filter: _filter,
          entries: entries,
          onFilter: (role) => setState(() => _filter = role),
          onRevealPin: _revealPin,
          onRemove: _confirmRemove,
        ),
      ],
    );
  }
}

class _StaffEntry {
  const _StaffEntry({
    required this.role,
    required this.index,
    required this.name,
    this.pinView,
    this.salary = 0,
  });

  final StaffRole role;
  final int index;
  final String name;
  final String? pinView;
  final double salary;
}

class _StaffStatsRow extends StatelessWidget {
  const _StaffStatsRow({
    required this.total,
    required this.waiters,
    required this.managers,
  });

  final int total;
  final int waiters;
  final int managers;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageService.instance;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 3 : 1;
        final gap = 12.0;
        final w = cols == 1
            ? c.maxWidth
            : (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _StatTile(
              width: w,
              icon: Icons.groups_outlined,
              label: lang.t('Gjithsej', 'Total'),
              value: '$total',
              tint: AppColors.primaryGreen,
            ),
            _StatTile(
              width: w,
              icon: Icons.badge_outlined,
              label: lang.t('Kamarierë', 'Waiters'),
              value: '$waiters',
              tint: AppColors.infoBlue,
            ),
            _StatTile(
              width: w,
              icon: Icons.admin_panel_settings_outlined,
              label: lang.t('Menaxherë', 'Managers'),
              value: '$managers',
              tint: AppColors.warmGold,
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddStaffComposer extends StatelessWidget {
  const _AddStaffComposer({
    required this.nameCtrl,
    required this.pinCtrl,
    required this.salaryCtrl,
    required this.role,
    required this.errorMsg,
    required this.onRoleChanged,
    required this.onSubmit,
  });

  final TextEditingController nameCtrl;
  final TextEditingController pinCtrl;
  final TextEditingController salaryCtrl;
  final StaffRole role;
  final String? errorMsg;
  final ValueChanged<StaffRole> onRoleChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = AppLanguageService.instance;
    final isWaiter = role == StaffRole.waiter;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.t('Shto anëtar', 'Add member'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.t(
                          'Zgjidh rolin, pastaj emrin dhe PIN-in e hyrjes.',
                          'Choose a role, then the name and login PIN.',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelFormRow(
                  breakpoint: 980,
                  fields: [
                    PanelField(
                      label: lang.t('Roli', 'Role'),
                      flex: 3,
                      child: DropdownButtonFormField<StaffRole>(
                        key: ValueKey(role),
                        initialValue: role,
                        isExpanded: true,
                        decoration: inputDeco(
                          lang.t('Zgjidh rolin', 'Select role'),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          DropdownMenuItem(
                            value: StaffRole.waiter,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 18,
                                  color: AppColors.infoBlue,
                                ),
                                const SizedBox(width: 10),
                                Text(lang.t('Kamarier', 'Waiter')),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: StaffRole.manager,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 18,
                                  color: AppColors.warmGold,
                                ),
                                const SizedBox(width: 10),
                                Text(lang.t('Menaxher', 'Manager')),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) onRoleChanged(v);
                        },
                      ),
                    ),
                    PanelField(
                      label: tr.emriPlote,
                      flex: 4,
                      child: TextField(
                        controller: nameCtrl,
                        decoration: inputDeco('p.sh. Arta Krasniqi'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    PanelField(
                      label: tr.kodiPin,
                      flex: 3,
                      helper: lang.t('Minimum 4 shifra.', 'At least 4 digits.'),
                      child: TextField(
                        controller: pinCtrl,
                        decoration: inputDeco('••••'),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        obscuringCharacter: '•',
                        textInputAction: isWaiter
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: (_) {
                          if (!isWaiter) onSubmit();
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    if (isWaiter)
                      PanelField(
                        label: tr.rrogaDite,
                        flex: 3,
                        helper: lang.t('Opsionale.', 'Optional.'),
                        child: TextField(
                          controller: salaryCtrl,
                          decoration: inputDeco('0.00', prefix: '€ '),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => onSubmit(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]'),
                            ),
                          ],
                        ),
                      ),
                  ],
                  trailing: FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(lang.t('Shto anëtar', 'Add member')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 14),
                  PanelErrorBanner(message: errorMsg!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffDirectory extends StatelessWidget {
  const _StaffDirectory({
    required this.searchCtrl,
    required this.filter,
    required this.entries,
    required this.onFilter,
    required this.onRevealPin,
    required this.onRemove,
  });

  final TextEditingController searchCtrl;
  final StaffRole? filter;
  final List<_StaffEntry> entries;
  final ValueChanged<StaffRole?> onFilter;
  final Future<void> Function(_StaffEntry) onRevealPin;
  final Future<void> Function(_StaffEntry) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = AppLanguageService.instance;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 720;
                final search = TextField(
                  controller: searchCtrl,
                  decoration: inputDeco(
                    lang.t('Kërko emrin…', 'Search by name…'),
                  ).copyWith(
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                );
                final chips = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: lang.t('Të gjithë', 'All'),
                      selected: filter == null,
                      onTap: () => onFilter(null),
                    ),
                    _FilterChip(
                      label: lang.t('Kamarierë', 'Waiters'),
                      selected: filter == StaffRole.waiter,
                      accent: AppColors.infoBlue,
                      onTap: () => onFilter(StaffRole.waiter),
                    ),
                    _FilterChip(
                      label: lang.t('Menaxherë', 'Managers'),
                      selected: filter == StaffRole.manager,
                      accent: AppColors.warmGold,
                      onTap: () => onFilter(StaffRole.manager),
                    ),
                  ],
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 12), chips],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 16),
                    chips,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.groups_2_outlined,
                      size: 30,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.t('Nuk ka anëtarë stafi', 'No staff members yet'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.t(
                      'Shto kamarierin ose menaxherin e parë më sipër.',
                      'Add the first waiter or manager above.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.lightGreenText,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: scheme.outlineVariant),
              itemBuilder: (context, i) {
                return _StaffRow(
                  entry: entries[i],
                  onRevealPin: () => onRevealPin(entries[i]),
                  onRemove: () => onRemove(entries[i]),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : scheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? color : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffRow extends StatefulWidget {
  const _StaffRow({
    required this.entry,
    required this.onRevealPin,
    required this.onRemove,
  });

  final _StaffEntry entry;
  final VoidCallback onRevealPin;
  final VoidCallback onRemove;

  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  bool _hovered = false;

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
    final lang = AppLanguageService.instance;
    final entry = widget.entry;
    final isWaiter = entry.role == StaffRole.waiter;
    final accent = isWaiter ? AppColors.infoBlue : AppColors.warmGold;
    final pinView = entry.pinView;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: _hovered
            ? scheme.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.16),
              child: Text(
                _initials(entry.name),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isWaiter
                              ? lang.t('Kamarier', 'Waiter')
                              : lang.t('Menaxher', 'Manager'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                      StaffPinDisplay(
                        pinView: pinView,
                        onRevealTap: pinView == null || pinView.isEmpty
                            ? () async => widget.onRevealPin()
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isWaiter && entry.salary > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.salary.toStringAsFixed(0)}€/d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            IconButton(
              tooltip: lang.t('Hiq', 'Remove'),
              onPressed: widget.onRemove,
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: _hovered ? AppColors.softRed : AppColors.mediumGreenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep older imports compiling after the Waiters / Managers tabs were merged.
class WaitersPanel extends StatelessWidget {
  const WaitersPanel({super.key, required this.m});
  final ManagerData m;
  @override
  Widget build(BuildContext context) => StaffPanel(m: m);
}

class ManagersPanel extends StatelessWidget {
  const ManagersPanel({super.key, required this.m});
  final ManagerData m;
  @override
  Widget build(BuildContext context) => StaffPanel(m: m);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manager/manager_data.dart';
import '../models/mock_data.dart';
import '../theme/app_colors.dart';

/// Të dhënat që barten me drag nga një produkt.
typedef _ProductDrag = ({String fromCatId, ProductItem product});

/// Dashboard menaxheri (PIN 9999). Seksionet 1–8 sipas kërkesës.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerData _m = ManagerData.instance;
  int _railIndex = 0;

  @override
  void initState() {
    super.initState();
    _m.addListener(_onData);
  }

  void _onData() => setState(() {});

  @override
  void dispose() {
    _m.removeListener(_onData);
    super.dispose();
  }

  void _exitToLogin() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 1100,
            backgroundColor: AppColors.white,
            selectedIndex: _railIndex,
            onDestinationSelected: (i) => setState(() => _railIndex = i),
            // Kur `extended: true`, `labelType` duhet të jetë null (rregull i Flutter-it).
            labelType: MediaQuery.sizeOf(context).width > 1100
                ? null
                : NavigationRailLabelType.selected,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: IconButton(
                tooltip: 'Kthehu te hyrja',
                onPressed: _exitToLogin,
                icon: const Icon(Icons.logout, color: AppColors.primaryGreen),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Përmbledhje'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule),
                label: Text('Gjendja'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge),
                label: Text('Kamarierët'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.table_rows_outlined),
                selectedIcon: Icon(Icons.table_rows),
                label: Text('Shpenzime'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up),
                label: Text('Fitime'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Raporte'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: Text('Top puntor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: Text('Menu'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: Text('Tavolinat'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ManagerTopBar(onLogout: _exitToLogin),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: _buildSection(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (_railIndex) {
      case 0:
        return _OverviewPanel(m: _m);
      case 1:
        return _ShiftPanel(m: _m);
      case 2:
        return _WaitersPanel(m: _m);
      case 3:
        return _ExpensesPanel(m: _m);
      case 4:
        return _ProfitsPanel(m: _m);
      case 5:
        return _ReportsPanel();
      case 6:
        return _TopEmployeePanel(m: _m);
      case 7:
        return _MenuPanel(m: _m);
      case 8:
        return _TablesConfigPanel(m: _m);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ManagerTopBar extends StatelessWidget {
  const _ManagerTopBar({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 0,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle(0.1))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'MANAGER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Dashboard menaxheri',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.darkGreenText,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Dil'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Përmbledhje',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGreenText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'PIN menaxheri: 9999',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              title: 'Gjendja',
              value: m.shiftOpen ? 'E hapur' : 'E mbyllur',
              icon: Icons.schedule,
            ),
            _StatCard(
              title: 'Kamarierë',
              value: '${m.waiters.length}',
              icon: Icons.badge,
            ),
            _StatCard(
              title: 'Shpenzime totale',
              value: '\$${m.totalExpenses.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            _StatCard(
              title: 'Fitim sot (demo)',
              value: '\$${m.profitDaily().toStringAsFixed(0)}',
              icon: Icons.trending_up,
            ),
            _StatCard(
              title: 'Top puntor',
              value: top.key,
              subtitle: '\$${top.value.toStringAsFixed(0)}',
              icon: Icons.emoji_events,
            ),
            _StatCard(
              title: 'Tavolina',
              value: '${m.cashierTables.length} · ${m.tablesPerRow}/rresht',
              icon: Icons.grid_view,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.lightGreenText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mediumGreenText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftPanel extends StatelessWidget {
  const _ShiftPanel({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Gjendja (shift)'),
        const SizedBox(height: 8),
        Text(
          'Hap ose mbyll gjendjen e ditës për kasë / raportim.',
          style: TextStyle(color: AppColors.mediumGreenText),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            FilledButton.icon(
              onPressed: m.shiftOpen ? null : () => m.openShift(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Hap gjendjen'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: !m.shiftOpen ? null : () => m.closeShift(),
              icon: const Icon(Icons.stop),
              label: const Text('Mbyll gjendjen'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkGreenText,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statusi: ${m.shiftOpen ? "AKTIV" : "JOAKTIV"}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: m.shiftOpen
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenText,
                ),
              ),
              if (m.shiftOpenedAt != null)
                Text(
                  'Hapur: ${m.shiftOpenedAt}',
                  style: const TextStyle(fontSize: 13),
                ),
              if (m.shiftClosedAt != null)
                Text(
                  'Mbyllur së fundmi: ${m.shiftClosedAt}',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitersPanel extends StatefulWidget {
  const _WaitersPanel({required this.m});

  final ManagerData m;

  @override
  State<_WaitersPanel> createState() => _WaitersPanelState();
}

class _WaitersPanelState extends State<_WaitersPanel> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Shkruaj emrin e kamarierit.');
      return;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      setState(() => _errorMsg = 'PIN duhet të jetë 4–6 shifra.');
      return;
    }
    if (pin == '9999') {
      setState(() => _errorMsg = 'PIN 9999 është rezervuar për menaxherin.');
      return;
    }
    if (widget.m.waiters.any((w) => w.pin == pin)) {
      setState(() => _errorMsg = 'Ky PIN ekziston tashmë.');
      return;
    }
    widget.m.addWaiter(name, pin);
    _nameCtrl.clear();
    _pinCtrl.clear();
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('2. Kamarierët'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameCtrl,
                decoration: _inputDeco('Emri i kamarierit'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _pinCtrl,
                decoration: _inputDeco('PIN (4–6 shifra)'),
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton(
                onPressed: _add,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                ),
                child: const Text('Shto'),
              ),
            ),
          ],
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMsg!,
            style: const TextStyle(
              color: AppColors.negativeText,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (m.waiters.isEmpty)
          Text(
            'Nuk ka kamarierë të regjistruar.',
            style: TextStyle(color: AppColors.lightGreenText),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle(0.12)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: m.waiters.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.borderSubtle(0.08)),
              itemBuilder: (context, i) {
                final w = m.waiters[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lightGreenBg,
                    child: Text(
                      w.name.isNotEmpty ? w.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Text(
                    w.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  subtitle: Text(
                    'PIN: ${'●' * w.pin.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.lightGreenText,
                      letterSpacing: 2,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => m.removeWaiterAt(i),
                    color: AppColors.negativeText,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ExpensesPanel extends StatefulWidget {
  const _ExpensesPanel({required this.m});

  final ManagerData m;

  @override
  State<_ExpensesPanel> createState() => _ExpensesPanelState();
}

class _ExpensesPanelState extends State<_ExpensesPanel> {
  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('3. Shpenzime / rroga (tabelë)'),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _openAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Shto rresht'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(AppColors.lightGreenBg),
            columns: const [
              DataColumn(label: Text('Lloji')),
              DataColumn(label: Text('Përshkrimi')),
              DataColumn(label: Text('Shuma'), numeric: true),
              DataColumn(label: Text('Data')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (var i = 0; i < m.expenses.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text(m.expenses[i].type)),
                    DataCell(Text(m.expenses[i].description)),
                    DataCell(Text('\$${m.expenses[i].amount.toStringAsFixed(2)}')),
                    DataCell(Text(_fmtDate(m.expenses[i].date))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => m.removeExpenseAt(i),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _openAddDialog(BuildContext context) async {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    var selType = 'Shpenzim';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Shto shpenzim / rrogë'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputDecorator(
                  decoration: _inputDeco('Lloji'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Shpenzim',
                          child: Text('Shpenzim'),
                        ),
                        DropdownMenuItem(value: 'Rrogë', child: Text('Rrogë')),
                        DropdownMenuItem(value: 'Bonus', child: Text('Bonus')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() => selType = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: _inputDeco('Përshkrimi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  decoration: _inputDeco('Shuma (USD)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anulo'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ruaj'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && context.mounted) {
      final a = double.tryParse(amtCtrl.text.trim()) ?? 0;
      if (a > 0 && descCtrl.text.trim().isNotEmpty) {
        widget.m.addExpense(
          ExpenseRow(
            type: selType,
            description: descCtrl.text.trim(),
            amount: a,
          ),
        );
      }
    }
    descCtrl.dispose();
    amtCtrl.dispose();
  }
}

class _ProfitsPanel extends StatefulWidget {
  const _ProfitsPanel({required this.m});

  final ManagerData m;

  @override
  State<_ProfitsPanel> createState() => _ProfitsPanelState();
}

class _ProfitsPanelState extends State<_ProfitsPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final values = [m.profitDaily(), m.profitWeekly(), m.profitMonthly()];
    final labels = ['Ditore', 'Javore', 'Mujore'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('4. Totali i fitimeve'),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: [
            for (var i = 0; i < 3; i++)
              ButtonSegment<int>(value: i, label: Text(labels[i])),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: 24),
        Text(
          'Fitimi ${labels[_tab].toLowerCase()} (vlerë demo, minus shpenzime)',
          style: TextStyle(color: AppColors.mediumGreenText),
        ),
        const SizedBox(height: 8),
        Text(
          '\$${values[_tab].toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGreenText,
          ),
        ),
      ],
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    void snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('5. Nxjerrja e raporteve'),
        const SizedBox(height: 8),
        Text(
          'Gjenerim demo (nuk shkarkon skedarë të vërtetë).',
          style: TextStyle(color: AppColors.mediumGreenText),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => snack('Raporti PDF u gjenerua (demo).'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Raport PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => snack('Eksport Excel u përgatit (demo).'),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Export Excel'),
            ),
            OutlinedButton.icon(
              onPressed: () => snack('Raporti i zbritjeve u printua (demo).'),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Printo'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopEmployeePanel extends StatelessWidget {
  const _TopEmployeePanel({required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final top = m.topEmployee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('6. Realizimi sipas puntorëve'),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: AppColors.lightGreenBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, size: 48, color: AppColors.primaryGreen),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Më shumë realizim',
                      style: TextStyle(color: AppColors.mediumGreenText),
                    ),
                    Text(
                      top.key,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                    Text(
                      '\$${top.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (m.employeeSalesSorted.isEmpty)
          Text(
            'Asnjë shitje e regjistruar ende.',
            style: TextStyle(color: AppColors.lightGreenText),
          )
        else ...[
          const Text('Të gjithë:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ...m.employeeSalesSorted.map(
            (e) => ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: AppColors.lightGreenBg,
                radius: 16,
                child: Text(
                  e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              title: Text(e.key),
              trailing: Text(
                '\$${e.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Asset image picker (dynamic — reads AssetManifest at runtime) ──────────

const _kImageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

String _assetLabel(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

Future<List<String>> _loadImageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((a) {
        if (!a.startsWith('assets/images/')) return false;
        final lower = a.toLowerCase();
        return _kImageExtensions.any((ext) => lower.endsWith(ext));
      })
      .toList()
    ..sort();
}

Future<String?> _showAssetPicker(
    BuildContext context, String? current) async {
  final assets = await _loadImageAssets();
  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zgjidh foton',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AssetPickerThumb(
                      path: null,
                      label: 'Pa foto',
                      selected: current == null,
                      onTap: () => Navigator.pop(ctx, ''),
                    ),
                    for (final a in assets)
                      _AssetPickerThumb(
                        path: a,
                        label: _assetLabel(a),
                        selected: current == a,
                        onTap: () => Navigator.pop(ctx, a),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anulo'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssetPickerThumb extends StatefulWidget {
  const _AssetPickerThumb({
    required this.path,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String? path;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AssetPickerThumb> createState() => _AssetPickerThumbState();
}

class _AssetPickerThumbState extends State<_AssetPickerThumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primaryGreen
                  : _hover
                      ? AppColors.borderVisible(0.4)
                      : AppColors.borderSubtle(0.15),
              width: widget.selected ? 2 : 1,
            ),
            color: widget.selected
                ? AppColors.lightGreenBg
                : _hover
                    ? AppColors.beige
                    : AppColors.white,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: widget.path != null
                    ? Image.asset(
                        widget.path!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: AppColors.lightGreenText,
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: AppColors.lightGreenBg,
                        child: const Icon(
                          Icons.hide_image_outlined,
                          size: 28,
                          color: AppColors.lightGreenText,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.selected
                      ? AppColors.primaryGreen
                      : AppColors.mediumGreenText,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu Panel ──────────────────────────────────────────────────────────────

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({required this.m});

  final ManagerData m;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  final _catCtrl = TextEditingController();
  final _prodName = TextEditingController();
  final _prodPrice = TextEditingController();
  String? _selectedCatId;
  String? _newProductImage; // null = no image

  @override
  void initState() {
    super.initState();
    final c = ManagerData.instance.categories;
    if (c.isNotEmpty) _selectedCatId = c.first.id;
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _prodName.dispose();
    _prodPrice.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final picked = await _showAssetPicker(context, _newProductImage);
    if (picked != null) {
      setState(() => _newProductImage = picked.isEmpty ? null : picked);
    }
  }

  void _addProduct(String catId) {
    final pr = double.tryParse(_prodPrice.text.trim()) ?? 0;
    if (_prodName.text.trim().isEmpty || pr <= 0) return;
    widget.m.addProduct(
      categoryId: catId,
      name: _prodName.text.trim(),
      price: pr,
      imagePath: _newProductImage,
    );
    _prodName.clear();
    _prodPrice.clear();
    setState(() => _newProductImage = null);
  }

  Future<void> _openEditDialog(
    BuildContext context,
    String catId,
    ProductItem p,
  ) async {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl =
        TextEditingController(text: p.price.toStringAsFixed(2));
    String? editImage = p.imagePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ndrysho produktin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Photo row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: editImage != null
                            ? Image.asset(
                                editImage!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, _) => _noImageBox(),
                              )
                            : _noImageBox(),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fotoja',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _showAssetPicker(
                                  context, editImage);
                              if (picked != null) {
                                setSt(() => editImage =
                                    picked.isEmpty ? null : picked);
                              }
                            },
                            icon: const Icon(Icons.image_outlined, size: 16),
                            label: const Text('Ndrysho foton'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                  color: AppColors.primaryGreen),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: _inputDeco('Emri i produktit'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    decoration: _inputDeco('Çmimi'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Anulo'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final pr =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (nameCtrl.text.trim().isEmpty || pr <= 0) return;
                          widget.m.editProduct(
                            catId,
                            p.id,
                            name: nameCtrl.text.trim(),
                            price: pr,
                            imagePath: editImage,
                            clearImage: editImage == null,
                          );
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                        ),
                        child: const Text('Ruaj ndryshimet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
  }

  Widget _noImageBox() => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.hide_image_outlined,
          size: 28,
          color: AppColors.lightGreenText,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final cats = m.categories;

    if (cats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('7. Menu / kategori dinamike'),
          const SizedBox(height: 16),
          Text(
            'Shto të paktën një kategori.',
            style: TextStyle(color: AppColors.lightGreenText),
          ),
        ],
      );
    }

    final catValue =
        (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
            ? _selectedCatId!
            : cats.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('7. Menu / kategori dinamike'),
        const SizedBox(height: 20),

        // ── Add category ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _catCtrl,
                decoration: _inputDeco('Emri i kategorisë së re'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                if (_catCtrl.text.trim().isNotEmpty) {
                  m.addCategory(_catCtrl.text);
                  _catCtrl.clear();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Shto kategori'),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ── Add product form ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shto produkt',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: _inputDeco('Kategoria'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: catValue,
                    isExpanded: true,
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedCatId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Photo picker
                  GestureDetector(
                    onTap: _pickNewImage,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Tooltip(
                        message: 'Zgjidh foton',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: _newProductImage != null
                                ? Image.asset(
                                    _newProductImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, _) => const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 22,
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 22,
                                    color: AppColors.primaryGreen,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _prodName,
                      decoration: _inputDeco('Emri i produktit'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _prodPrice,
                      decoration: _inputDeco('Çmimi'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addProduct(catValue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _addProduct(catValue),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                    child: const Text('Shto'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── Category tables ──────────────────────────────────────────────
        for (final c in cats) ...[
          _CategoryProductTable(
            category: c,
            onDeleteCategory: () => m.removeCategory(c.id),
            onDeleteProduct: (pid) => m.removeProduct(c.id, pid),
            onEditProduct: (p) => _openEditDialog(context, c.id, p),
            onMoveIn: (p, fromCatId) => m.moveProduct(fromCatId, p.id, c.id),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Premium Category Table ──────────────────────────────────────────────────

class _CategoryProductTable extends StatefulWidget {
  const _CategoryProductTable({
    required this.category,
    required this.onDeleteCategory,
    required this.onDeleteProduct,
    required this.onEditProduct,
    required this.onMoveIn,
  });

  final CategoryData category;
  final VoidCallback onDeleteCategory;
  final void Function(String productId) onDeleteProduct;
  final void Function(ProductItem product) onEditProduct;
  final void Function(ProductItem product, String fromCatId) onMoveIn;

  @override
  State<_CategoryProductTable> createState() => _CategoryProductTableState();
}

class _CategoryProductTableState extends State<_CategoryProductTable> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    return DragTarget<_ProductDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromCatId != widget.category.id,
      onAcceptWithDetails: (d) =>
          widget.onMoveIn(d.data.product, d.data.fromCatId),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return Container(
      decoration: BoxDecoration(
        color: isOver
            ? AppColors.lightGreenBg.withValues(alpha: 0.6)
            : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver
              ? AppColors.primaryGreen
              : AppColors.borderSubtle(0.12),
          width: isOver ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isOver ? 0.06 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    c.icon,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGreenText,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${c.products.length} produkte',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Fshi kategorinë',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.negativeText,
                    onPressed: widget.onDeleteCategory,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Products list
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: c.products.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.beige,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Nuk ka produkte në këtë kategori.',
                        style: TextStyle(
                          color: AppColors.lightGreenText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Table header
                      Container(
                        color: AppColors.lightGreenBg,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            const SizedBox(width: 52),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 3,
                              child: Text(
                                'Emri',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mediumGreenText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 100,
                              child: Text(
                                'Çmimi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mediumGreenText,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 88),
                          ],
                        ),
                      ),
                      for (var i = 0; i < c.products.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: AppColors.borderSubtle(0.08),
                          ),
                        _ProductTableRow(
                          product: c.products[i],
                          isLast: i == c.products.length - 1,
                          onEdit: () => widget.onEditProduct(c.products[i]),
                          onDelete: () =>
                              widget.onDeleteProduct(c.products[i].id),
                        ),
                      ],
                    ],
                  ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
        );
      },
    );
  }
}

class _ProductTableRow extends StatefulWidget {
  const _ProductTableRow({
    required this.product,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductItem product;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover
              ? AppColors.lightGreenBg.withValues(alpha: 0.5)
              : AppColors.white,
          borderRadius: widget.isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.imagePath != null
                  ? Image.asset(
                      p.imagePath!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, _) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 16),
            // Name
            Expanded(
              flex: 3,
              child: Text(
                p.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGreenText,
                ),
              ),
            ),
            // Price
            SizedBox(
              width: 100,
              child: Text(
                '\$${p.price.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Ndrysho',
                    color: AppColors.primaryGreen,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Fshi',
                    color: AppColors.negativeText,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.fastfood_outlined,
          size: 22,
          color: AppColors.lightGreenText,
        ),
      );
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hover
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _TablesConfigPanel extends StatefulWidget {
  const _TablesConfigPanel({required this.m});

  final ManagerData m;

  @override
  State<_TablesConfigPanel> createState() => _TablesConfigPanelState();
}

class _TablesConfigPanelState extends State<_TablesConfigPanel> {
  late double _count;
  late double _perRow;

  @override
  void initState() {
    super.initState();
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
  }

  @override
  void didUpdateWidget(covariant _TablesConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _count = widget.m.tableCount.toDouble();
    _perRow = widget.m.tablesPerRow.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('8. Numri i tavolinave dhe kolonat'),
        const SizedBox(height: 8),
        Text(
          'Ruajtja rifillon listën e tavolinave (1…N) nga të dhënat fillestare; kamarieri mund të shtojë me “+”.',
          style: TextStyle(color: AppColors.mediumGreenText),
        ),
        const SizedBox(height: 24),
        Text('Numri i tavolinave: ${_count.round()}'),
        Slider(
          value: _count,
          min: 1,
          max: 48,
          divisions: 47,
          label: '${_count.round()}',
          activeColor: AppColors.primaryGreen,
          onChanged: (v) => setState(() => _count = v),
        ),
        const SizedBox(height: 8),
        Text('Tavolina për rresht: ${_perRow.round()}'),
        Slider(
          value: _perRow,
          min: 2,
          max: 12,
          divisions: 10,
          label: '${_perRow.round()}',
          activeColor: AppColors.primaryGreen,
          onChanged: (v) => setState(() => _perRow = v),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            m.setTableLayout(
              count: _count.round(),
              perRow: _perRow.round(),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cilësimet e tavolinave u ruajtën.')),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Ruaj cilësimet'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}

Widget _sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.darkGreenText,
    ),
  );
}

InputDecoration _inputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.borderVisible(0.2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.borderVisible(0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

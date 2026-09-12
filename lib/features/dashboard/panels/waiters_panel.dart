import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../manager/manager_data.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../widgets/waiters/waiter_list.dart';

class WaitersPanel extends StatefulWidget {
  const WaitersPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<WaitersPanel> createState() => _WaitersPanelState();
}

class _WaitersPanelState extends State<WaitersPanel> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Shkruaj emrin e kamarierit.');
      return;
    }
    if (pin.length < 4 || !RegExp(r'^\d+$').hasMatch(pin)) {
      setState(
        () =>
            _errorMsg = 'PIN: minimum 4 shifra, vetëm numra (gjatësia e lirë).',
      );
      return;
    }
    if (await widget.m.waiterPinExists(pin)) {
      setState(() => _errorMsg = 'Ky PIN ekziston tashmë.');
      return;
    }
    await widget.m.addWaiter(name, pin);
    if (!mounted) return;
    final salary =
        double.tryParse(_salaryCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (salary > 0) {
      widget.m.setSalary(name, salary);
    }
    _nameCtrl.clear();
    _pinCtrl.clear();
    _salaryCtrl.clear();
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.badge_outlined,
          title: 'Menaxhimi i Kamarierëve',
          subtitle: 'Menaxho anëtarët e stafit dhe kodet e hyrjes.',
        ),

        PanelCard(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Shto Kamarier të Ri',
          subtitle: 'Emri dhe PIN-i janë të detyrueshëm; rroga është opsionale.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelFormRow(
                fields: [
                  PanelField(
                    label: 'Emri i plotë',
                    flex: 4,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: inputDeco('p.sh. Arta Krasniqi'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  PanelField(
                    label: 'Kodi PIN',
                    flex: 3,
                    helper: 'Minimum 4 shifra.',
                    child: TextField(
                      controller: _pinCtrl,
                      decoration: inputDeco('••••'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      obscuringCharacter: '•',
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  PanelField(
                    label: 'Rroga (€/ditë)',
                    flex: 3,
                    helper: 'Opsionale.',
                    child: TextField(
                      controller: _salaryCtrl,
                      decoration: inputDeco('0.00'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                    ),
                  ),
                ],
                trailing: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Shto Kamarier'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 14),
                PanelErrorBanner(message: _errorMsg!),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        WaiterList(
          waiters: m.waiters,
          waiterSales: m.waiterSales,
          onRemove: (i) => m.removeWaiterAt(i),
          m: m,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../widgets/managers/manager_list.dart';
import '../../../l10n/tr.dart';

class ManagersPanel extends StatefulWidget {
  const ManagersPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<ManagersPanel> createState() => _ManagersPanelState();
}

class _ManagersPanelState extends State<ManagersPanel> {
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Shkruaj emrin e menaxherit.');
      return;
    }
    if (pin.length < 4 || !RegExp(r'^\d+$').hasMatch(pin)) {
      setState(
        () =>
            _errorMsg = tr.pinMinimum4ShifraVetemNumra,
      );
      return;
    }
    if (await widget.m.staffPinExists(pin)) {
      setState(() => _errorMsg = tr.kyPinEkzistonTashme);
      return;
    }
    await widget.m.addManager(name, pin);
    if (!mounted) return;
    _nameCtrl.clear();
    _pinCtrl.clear();
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.supervisor_account_outlined,
          title: tr.menaxheret,
          subtitle:
              tr.llogariDrejtaMenaxheriDashboardGjendjeMenu,
        ),

        PanelCard(
          icon: Icons.person_add_alt_1_outlined,
          title: tr.shtoMenaxherRi,
          subtitle: tr.pinDuhetJeteUnikMinimum4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelFormRow(
                fields: [
                  PanelField(
                    label: tr.emriPlote,
                    flex: 5,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: inputDeco('p.sh. Driton Berisha'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  PanelField(
                    label: tr.kodiPin,
                    flex: 3,
                    helper: 'Minimum 4 shifra.',
                    child: TextField(
                      controller: _pinCtrl,
                      decoration: inputDeco('••••'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      obscuringCharacter: '•',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
                trailing: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Shto Menaxher'),
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

        ManagerList(
          managers: m.managers,
          onRemove: (i) => m.removeManagerAt(i),
          m: m,
        ),
      ],
    );
  }
}

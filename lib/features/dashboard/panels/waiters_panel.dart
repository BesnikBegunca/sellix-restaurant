import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
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
        () => _errorMsg =
            'PIN: minimum 4 shifra, vetëm numra (gjatësia e lirë).',
      );
      return;
    }
    if (await widget.m.waiterPinExists(pin)) {
      setState(() => _errorMsg = 'Ky PIN ekziston tashmë.');
      return;
    }
    await widget.m.addWaiter(name, pin);
    if (!mounted) return;
    final salary = double.tryParse(
          _salaryCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
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
        sectionTitle('Menaxhimi i Kamarierëve'),
        const SizedBox(height: 6),
        const Text(
          'Menaxho anëtarët e stafit dhe kodet e hyrjes',
          style: TextStyle(fontSize: 14, color: AppColors.lightGreenText),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightGreenBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shto Kamarier të Ri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: inputDeco('Emri i Plotë'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _pinCtrl,
                      decoration: inputDeco('Kodi PIN'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _salaryCtrl,
                      decoration: inputDeco('Rroga (€/ditë)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) { _add(); },
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () { _add(); },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Shto Kamarier'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.softRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.softRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _errorMsg!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.softRed,
                        ),
                      ),
                    ],
                  ),
                ),
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

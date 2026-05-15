import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';

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

  void _add() {
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
    if (pin == '9999') {
      setState(() => _errorMsg = 'PIN 9999 është rezervuar për menaxherin.');
      return;
    }
    if (widget.m.waiters.any((w) => w.pin == pin)) {
      setState(() => _errorMsg = 'Ky PIN ekziston tashmë.');
      return;
    }
    widget.m.addWaiter(name, pin);
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
                      maxLength: 6,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
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
                      onSubmitted: (_) => _add(),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _add,
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

        _WaiterList(
          waiters: m.waiters,
          waiterSales: m.waiterSales,
          onRemove: (i) => m.removeWaiterAt(i),
          m: m,
        ),
      ],
    );
  }
}

class _WaiterList extends StatelessWidget {
  const _WaiterList({
    required this.waiters,
    required this.waiterSales,
    required this.onRemove,
    required this.m,
  });
  final List<dynamic> waiters;
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
    if (waiters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppColors.white,
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
        final name = w.name as String;
        final pin = w.pin as String;
        final salary = m.getSalary(name);
        final initials = _initials(name);

        return _WaiterGridCard(
          initials: initials,
          name: name,
          pin: pin,
          salary: salary,
          onDelete: () => onRemove(i),
        );
      },
    );
  }
}

class _WaiterGridCard extends StatefulWidget {
  const _WaiterGridCard({
    required this.initials,
    required this.name,
    required this.pin,
    required this.salary,
    required this.onDelete,
  });
  final String initials;
  final String name;
  final String pin;
  final double salary;
  final VoidCallback onDelete;

  @override
  State<_WaiterGridCard> createState() => _WaiterGridCardState();
}

class _WaiterGridCardState extends State<_WaiterGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? AppColors.primaryGreen.withValues(alpha: 0.4)
                : AppColors.lightGreenBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? AppColors.primaryGreen.withValues(alpha: 0.06)
                  : const Color(0x08000000),
              blurRadius: _hovered ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.initials,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PIN: ${widget.pin}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.salary > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.salary.toStringAsFixed(0)}€/d',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered ? 1.0 : 0.35,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.softRed.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: _hovered
                        ? AppColors.softRed
                        : AppColors.mediumGreenText,
                  ),
                  onPressed: widget.onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

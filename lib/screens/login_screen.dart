import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../theme/app_colors.dart';
import '../widgets/hover_interaction.dart';
import '../widgets/gg_header.dart';
import 'manager_dashboard_screen.dart';
import 'table_selection_screen.dart';

/// Ekrani 1: PIN + kalkulator ndrysi; tastiera kryesore shërben për të dy sipas fokusit.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  String _bill = '';
  String _paid = '';
  /// null = hyrje në PIN; 0 = fatura; 1 = pagesa.
  int? _calcField;

  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    ManagerData.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  bool get _pinConfirmEnabled => _pin.length >= 4 && _pin.length <= 6;

  void _setCalcField(int? field) {
    setState(() => _calcField = field);
  }

  void _appendDigit(String d) {
    setState(() {
      if (_calcField != null) {
        _appendMoney(_calcField!, d);
      } else if (_pin.length < 6) {
        _pin += d;
      }
    });
  }

  void _appendMoney(int field, String d) {
    String s = field == 0 ? _bill : _paid;
    if (d == '.') {
      if (s.contains('.')) return;
      if (s.isEmpty) {
        s = '0.';
      } else {
        s += '.';
      }
    } else {
      if (s.contains('.')) {
        final parts = s.split('.');
        if (parts.length == 2 && parts[1].length >= 2) return;
      }
      s += d;
    }
    if (field == 0) {
      _bill = s;
    } else {
      _paid = s;
    }
  }

  void _backspace() {
    setState(() {
      if (_calcField != null) {
        final s = _calcField == 0 ? _bill : _paid;
        if (s.isNotEmpty) {
          if (_calcField == 0) {
            _bill = s.substring(0, s.length - 1);
          } else {
            _paid = s.substring(0, s.length - 1);
          }
        }
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _clearActiveMoney() {
    setState(() {
      if (_calcField == 0) _bill = '';
      if (_calcField == 1) _paid = '';
    });
  }

  void _appendDoubleZero() {
    if (_calcField == null) return;
    setState(() {
      if (_calcField == 0) {
        _bill += '00';
      } else {
        _paid += '00';
      }
    });
  }

  double? _parseMoney(String s) {
    if (s.isEmpty || s == '.') return null;
    return double.tryParse(s);
  }

  double? get _changeValue {
    final b = _parseMoney(_bill);
    final p = _parseMoney(_paid);
    if (b == null || p == null) return null;
    return p - b;
  }

  void _submitPin() {
    if (!_pinConfirmEnabled) return;

    if (_pin == '9999') {
      setState(() => _pin = '');
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ManagerDashboardScreen(),
        ),
      );
      return;
    }

    final waiter = ManagerData.instance.findWaiterByPin(_pin);
    setState(() => _pin = '');

    if (waiter != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TableSelectionScreen(waiterName: waiter.name),
        ),
      );
      return;
    }

    // PIN i panjohur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PIN i gabuar. Kontakto menaxherin.'),
        backgroundColor: AppColors.negativeText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 960;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeaderGroup(),
                        const SizedBox(height: 48),
                        if (narrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _pinCard(context),
                              const SizedBox(height: 24),
                              _calcCard(context),
                            ],
                          )
                        else
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _pinCard(context),
                                ),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 320,
                                  child: _calcCard(context),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderGroup() {
    final companyName = ManagerData.instance.companyName;
    final title = companyName != null && companyName.isNotEmpty
        ? companyName
        : 'POS System';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const GgLogoBox(size: 48, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreenText,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Fast and simple restaurant management system',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.lightGreenText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pinCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _setCalcField(null),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter PIN',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(6, (i) {
                    final filled = i < _pin.length;
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                      child: _pinSlot(filled),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _keypadSection(context),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Enter 4-6 digit PIN to continue',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.lightGreenText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinSlot(bool filled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.lightGreenBg : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled
              ? AppColors.primaryGreen
              : AppColors.lightGreenBorderEmpty(),
          width: filled ? 2 : 2,
        ),
      ),
      child: filled
          ? const Text(
              '●',
              style: TextStyle(
                fontSize: 32,
                color: AppColors.darkGreenText,
                height: 1,
              ),
            )
          : Icon(
              Icons.circle_outlined,
              size: 22,
              color: AppColors.lightGreenText.withValues(alpha: 0.5),
            ),
    );
  }

  Widget _calcCard(BuildContext context) {
    final change = _changeValue;
    final negative = change != null && change < 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quick Change Calculator',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 24),
          _moneyField(
            label: 'Bill Amount',
            value: _bill,
            selected: _calcField == 0,
            onTap: () => _setCalcField(0),
          ),
          const SizedBox(height: 16),
          _moneyField(
            label: 'Customer Paid',
            value: _paid,
            selected: _calcField == 1,
            onTap: () => _setCalcField(1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              height: 1,
              color: AppColors.borderSubtle(0.1),
            ),
          ),
          const Text(
            'Change',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.lightGreenText,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: change == null
                  ? AppColors.beige
                  : (negative ? AppColors.negativeBg : AppColors.lightGreenBg),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              change == null
                  ? r'$0.00'
                  : '\$${change.abs().toStringAsFixed(2)}${negative ? ' owed' : ''}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: change == null
                    ? AppColors.lightGreenText
                    : (negative ? AppColors.negativeText : AppColors.primaryGreen),
              ),
            ),
          ),
          if (_calcField != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _quickChip('Clear', _clearActiveMoney)),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickChip('.', () {
                    if (_calcField != null) _appendDigit('.');
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(child: _quickChip('00', _appendDoubleZero)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Click field to select, use main keypad to enter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.lightGreenText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyField({
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.lightGreenText,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: selected ? AppColors.lightGreenBg : AppColors.beige,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryGreen
                      : AppColors.borderVisible(0.2),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                value.isEmpty ? r'$0.00' : '\$$value',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.darkGreenText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return _HoverSmallChip(label: label, onTap: onTap);
  }

  Widget _keypadSection(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        children: [
          _keyRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _keyRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _keyRow(['7', '8', '9']),
          const SizedBox(height: 12),
          _bottomKeyRow(context),
        ],
      ),
    );
  }

  Widget _keyRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (k) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _numKey(k),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _bottomKeyRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: HoverScaleButton(
              onPressed: _backspace,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.beige,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle(0.1)),
                ),
                child: const Icon(
                  Icons.backspace_outlined,
                  color: AppColors.primaryGreen,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _numKey('0'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: HoverScaleButton(
              onPressed: _pinConfirmEnabled ? _submitPin : null,
              enabled: _pinConfirmEnabled,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _pinConfirmEnabled
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenText.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check,
                  color: _pinConfirmEnabled
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: 0.6),
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numKey(String label) {
    return HoverScaleButton(
      onPressed: () => _appendDigit(label),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _NumKeyBody(label: label),
      ),
    );
  }
}

class _NumKeyBody extends StatefulWidget {
  const _NumKeyBody({required this.label});

  final String label;

  @override
  State<_NumKeyBody> createState() => _NumKeyBodyState();
}

class _NumKeyBodyState extends State<_NumKeyBody> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover ? AppColors.lightGreenBg : AppColors.beige,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle(0.1)),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 32,
            color: AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }
}

class _HoverSmallChip extends StatefulWidget {
  const _HoverSmallChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_HoverSmallChip> createState() => _HoverSmallChipState();
}

class _HoverSmallChipState extends State<_HoverSmallChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? AppColors.lightGreenBg : AppColors.beige,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle(0.1)),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGreenText,
            ),
          ),
        ),
      ),
    );
  }
}

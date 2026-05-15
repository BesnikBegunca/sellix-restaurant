import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../manager/manager_data.dart';
import '../services/audit_log_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gg_header.dart';
import '../widgets/hover_card_button.dart';
import '../widgets/hover_interaction.dart';
import '../widgets/hover_small_chip.dart';
import '../widgets/num_key_body.dart';

// Reuse hover widgets already defined in `hover_interaction.dart`.
// (HoverInteraction might not exist in this project version.)

import 'manager_dashboard_screen.dart';
import 'table_selection_screen.dart';
import 'waiter_selection_screen.dart';

/// Ekrani 1: PIN + kalkulator ndarë; tastiera e PIN-it dhe numpadi i kalkulatorit janë të pavarura.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  String _bill = '';
  String _paid = '';

  /// null = hyrje në PIN; 0 = fatura; 1 = pagesa.
  int? _calcField;

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    ManagerData.instance.addListener(_onDataChanged);
    _pinController.addListener(() => setState(() {}));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pinController.dispose();
    _pinFocus.dispose();
    ManagerData.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  static final RegExp _pinDigitsOnly = RegExp(r'^\d+$');

  bool get _pinConfirmEnabled {
    final p = _pinController.text;
    return p.length >= 4 && _pinDigitsOnly.hasMatch(p);
  }

  void _setCalcField(int? field) {
    setState(() => _calcField = field);
  }

  void _appendDigit(String d) {
    setState(() {
      _calcField = null;
      final t = _pinController.text + d;
      _pinController.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
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
      _calcField = null;
      if (_pinController.text.isNotEmpty) {
        _pinController.clear();
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
    final pin = _pinController.text;

    if (pin == '9999') {
      _pinController.clear();
      AuditLogService.instance.logManagerLogin();
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ManagerDashboardScreen()),
      );
      return;
    }

    // In PINMODE, check for waiter PIN
    if (ManagerData.instance.loginMode == 'PINMODE') {
      final waiter = ManagerData.instance.findWaiterByPin(pin);
      _pinController.clear();

      if (waiter != null) {
        AuditLogService.instance.logWaiterLogin(waiterName: waiter.name);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TableSelectionScreen(waiterName: waiter.name),
          ),
        );
        return;
      }

      AuditLogService.instance.logFailedPin();
      // PIN i panjohur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN i gabuar. Kontakto menaxherin.'),
          backgroundColor: AppColors.negativeText,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      // NAMEMODE: Only accept admin PIN
      _pinController.clear();
      AuditLogService.instance.logFailedPin();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN i gabuar. Kontakto menaxherin.'),
          backgroundColor: AppColors.negativeText,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _goToWaiterSelection() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WaiterSelectionScreen()),
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
                                Expanded(flex: 3, child: _pinCard(context)),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 460,
                                  child:
                                      ManagerData.instance.loginMode ==
                                          'NAMEMODE'
                                      ? _waiterSelectionCard(context)
                                      : _calcCard(context),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 28),
                        _clockDisplay(),
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

  Widget _clockDisplay() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return Text(
      '$h:$m:$s',
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w300,
        color: AppColors.lightGreenText,
        letterSpacing: 4,
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
        GgLogoBox(size: 80, radius: 16),
        const SizedBox(width: 16),
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
                'Sistem i shpejtë dhe i thjeshtë për menaxhim restoranti',
                style: TextStyle(fontSize: 16, color: AppColors.lightGreenText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pinCard(BuildContext context) {
    final isNameMode = ManagerData.instance.loginMode == 'NAMEMODE';

    return GestureDetector(
      onTap: () {
        _setCalcField(null);
        _pinFocus.requestFocus();
      },
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
            Text(
              isNameMode ? 'Hyrja e Administratorit' : 'Shkruaj PIN',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 24),
            if (isNameMode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '👤 Kamarierë: Klikoni butonin poshtë për të zgjedhur emrin tuaj',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkGreenText,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _pinController,
              focusNode: _pinFocus,
              obscureText: true,
              obscuringCharacter: '•',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 6,
                color: AppColors.darkGreenText,
              ),
              decoration: InputDecoration(
                hintText: 'PIN!',
                hintStyle: TextStyle(
                  fontSize: 18,
                  color: AppColors.lightGreenText.withValues(alpha: 0.7),
                ),
                filled: true,
                fillColor: AppColors.beige,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.lightGreenBorderEmpty(),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.lightGreenBorderEmpty(),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => _submitPin(),
            ),
            const SizedBox(height: 32),
            _keypadSection(context),
          ],
        ),
      ),
    );
  }

  void _calcNumpadAppend(String d) {
    setState(() {
      if (_calcField == null) _calcField = 0;
      _appendMoney(_calcField!, d);
    });
  }

  void _calcEnter() {
    setState(() {
      if (_calcField == null || _calcField == 0) {
        _calcField = 1;
      } else {
        _calcField = null;
      }
    });
  }

  void _calcAc() {
    setState(() {
      if (_calcField == null) _calcField = 0;
      _bill = '';
      _paid = '';
    });
  }

  Widget _calcNumpad() {
    Widget padBtn(String label, VoidCallback onTap, {Color? accent}) {
      return HoverCardButton(
        onPressed: onTap,
        builder: (ctx, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent != null
                ? (hovered ? accent.withValues(alpha: 0.82) : accent)
                : (hovered ? AppColors.lightGreenBg : AppColors.beige),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent != null
                  ? Colors.transparent
                  : AppColors.borderSubtle(0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == 'Enter' ? 13 : 18,
              fontWeight: FontWeight.w500,
              color: accent != null
                  ? AppColors.white
                  : AppColors.darkGreenText,
            ),
          ),
        ),
      );
    }

    Widget numRow(List<String> digits) {
      return Row(
        children: digits
            .map(
              (d) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: padBtn(d, () => _calcNumpadAppend(d)),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        padBtn('AC', _calcAc, accent: AppColors.softRed),
        const SizedBox(height: 15),
        numRow(['7', '8', '9']),
        const SizedBox(height: 15),
        numRow(['4', '5', '6']),
        const SizedBox(height: 15),
        numRow(['1', '2', '3']),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: padBtn('.', () => _calcNumpadAppend('.')),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: 3),
                child: padBtn('0', () => _calcNumpadAppend('0')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        padBtn('Enter', _calcEnter, accent: AppColors.primaryGreen),
      ],
    );
  }

  Widget _calcCard(BuildContext context) {
    final change = _changeValue;
    final negative = change != null && change < 0;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Llogaritësi i Kusurit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                _moneyField(
                  label: 'Shuma e Faturës',
                  value: _bill,
                  selected: _calcField == 0,
                  onTap: () => _setCalcField(0),
                ),
                const SizedBox(height: 12),
                _moneyField(
                  label: 'Pagoi Klienti',
                  value: _paid,
                  selected: _calcField == 1,
                  onTap: () => _setCalcField(1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 1, color: AppColors.borderSubtle(0.1)),
                ),
                const Text(
                  'Kusuri',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.lightGreenText,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: change == null
                        ? AppColors.beige
                        : (negative
                            ? AppColors.negativeBg
                            : AppColors.lightGreenBg),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    change == null
                        ? '0.00€'
                        : '${change.abs().toStringAsFixed(2)}€${negative ? ' borxh' : ''}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: change == null
                          ? AppColors.lightGreenText
                          : (negative
                                ? AppColors.negativeText
                                : AppColors.primaryGreen),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 152, child: _calcNumpad()),
        ],
      ),
      ),
    );
  }

  Widget _waiterSelectionCard(BuildContext context) {
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 48, color: AppColors.primaryGreen),
          const SizedBox(height: 16),
          const Text(
            'Jeni kamarier?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Klikoni poshtë për të zgjedhur emrin tuaj',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
          ),
          const SizedBox(height: 24),
          HoverCardButton(
            onPressed: _goToWaiterSelection,
            builder: (context, isHovered) {
              return Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isHovered
                      ? AppColors.primaryGreen
                      : AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen,
                    width: isHovered ? 2 : 1,
                  ),
                ),
                child: Text(
                  '👤 Zgjidh Emrin Tënd',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isHovered
                        ? AppColors.white
                        : AppColors.darkGreenText,
                  ),
                ),
              );
            },
          ),
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
          style: const TextStyle(fontSize: 14, color: AppColors.lightGreenText),
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
                value.isEmpty ? '0.00€' : '${value}€',
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
        child: NumKeyBody(label: label),
      ),
    );
  }
}

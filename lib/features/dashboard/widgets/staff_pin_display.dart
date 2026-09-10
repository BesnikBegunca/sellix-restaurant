import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Shfaq PIN të fshehur; menaxheri e zbulon me ikonën e syrit.
class StaffPinDisplay extends StatefulWidget {
  const StaffPinDisplay({super.key, this.pinView, this.onRevealTap});

  /// PIN në plaintext (vetëm për panel menaxheri, ruhet lokalisht në DB).
  final String? pinView;

  /// Kur [pinView] mungon — hap dialogun e verifikimit të PIN-it.
  final Future<void> Function()? onRevealTap;

  @override
  State<StaffPinDisplay> createState() => _StaffPinDisplayState();
}

class _StaffPinDisplayState extends State<StaffPinDisplay> {
  bool _visible = false;

  String get _masked => '••••';

  bool get _hasStoredPin =>
      widget.pinView != null && widget.pinView!.trim().isNotEmpty;

  bool get _canUseEye => _hasStoredPin || widget.onRevealTap != null;

  String get _displayText {
    if (!_visible) return _masked;
    final p = widget.pinView?.trim();
    if (p == null || p.isEmpty) return '—';
    return p;
  }

  Future<void> _onEyePressed() async {
    if (_hasStoredPin) {
      setState(() => _visible = !_visible);
      return;
    }
    final reveal = widget.onRevealTap;
    if (reveal == null) return;
    await reveal();
    if (!mounted) return;
    if (widget.pinView != null && widget.pinView!.trim().isNotEmpty) {
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PIN: $_displayText',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mediumGreenText,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: _visible ? 'Fshih PIN' : 'Shfaq PIN',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 16,
            color: _canUseEye
                ? AppColors.primaryGreen
                : AppColors.lightGreenText,
          ),
          onPressed: _canUseEye ? _onEyePressed : null,
        ),
      ],
    );
  }
}

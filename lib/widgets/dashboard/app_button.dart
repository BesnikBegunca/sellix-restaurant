import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, destructive }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.minimumSize = const Size(0, 44),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final Size minimumSize;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    switch (widget.variant) {
      case AppButtonVariant.primary:
        final style = FilledButton.styleFrom(
          minimumSize: widget.minimumSize,
          backgroundColor: AppColors.deepForestGreen,
          foregroundColor: AppColors.pureWhite,
          disabledBackgroundColor: AppColors.mutedGray.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.pureWhite.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        );
        if (widget.icon != null) {
          return FilledButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, size: 20),
            label: Text(widget.label),
            style: style,
          );
        }
        return FilledButton(
          onPressed: widget.onPressed,
          style: style,
          child: Text(widget.label),
        );
      case AppButtonVariant.secondary:
        return _wrapHover(
          child: OutlinedButton.icon(
            onPressed: widget.onPressed,
            icon: widget.icon != null
                ? Icon(widget.icon, size: 20, color: _secIconColor(enabled))
                : const SizedBox.shrink(),
            label: Text(widget.label, style: TextStyle(color: _secFg(enabled))),
            style: OutlinedButton.styleFrom(
              minimumSize: widget.minimumSize,
              backgroundColor: _secBg(enabled),
              side: BorderSide(
                color: AppColors.lightGreenBorder,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.controlRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        );
      case AppButtonVariant.destructive:
        return _wrapHover(
          child: OutlinedButton.icon(
            onPressed: widget.onPressed,
            icon: widget.icon != null
                ? Icon(widget.icon, size: 20, color: _destFg(enabled))
                : const SizedBox.shrink(),
            label: Text(widget.label, style: TextStyle(color: _destFg(enabled))),
            style: OutlinedButton.styleFrom(
              minimumSize: widget.minimumSize,
              backgroundColor: _destBg(enabled),
              side: BorderSide(
                color: AppColors.accentRed.withValues(alpha: 0.45),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.controlRadius),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        );
    }
  }

  Color _secFg(bool enabled) =>
      enabled ? AppColors.deepForestGreen : AppColors.mutedGray;

  Color _secIconColor(bool enabled) => _secFg(enabled);

  Color _secBg(bool enabled) {
    if (!enabled) return AppColors.pureWhite;
    if (_pressed) return AppColors.softGreenTint;
    if (_hover) return AppColors.softGreenTint.withValues(alpha: 0.65);
    return AppColors.pureWhite;
  }

  Color _destFg(bool enabled) =>
      enabled ? AppColors.accentRed : AppColors.mutedGray;

  Color _destBg(bool enabled) {
    if (!enabled) return AppColors.pureWhite;
    if (_pressed) return AppColors.accentRed.withValues(alpha: 0.12);
    if (_hover) return AppColors.accentRed.withValues(alpha: 0.08);
    return AppColors.pureWhite;
  }

  Widget _wrapHover({required Widget child}) {
    if (widget.variant == AppButtonVariant.primary) return child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: child,
      ),
    );
  }
}

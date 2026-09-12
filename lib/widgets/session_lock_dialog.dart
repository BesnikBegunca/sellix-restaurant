import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

const double _kPinBoxSize = 68;
const double _kPinBoxRadius = 18;

/// Premium PIN unlock UI for admin session lock.
/// Auth/verify logic stays in [ManagerDashboardScreen]; this widget is UI only.
class SessionLockDialogContent extends StatefulWidget {
  const SessionLockDialogContent({
    super.key,
    required this.pinController,
    required this.errorMessage,
    required this.rateLimited,
    required this.lockoutSeconds,
    required this.onPinChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController pinController;
  final String? errorMessage;
  final bool rateLimited;
  final int lockoutSeconds;
  final VoidCallback onPinChanged;
  final Future<void> Function() onSubmit;
  final VoidCallback onCancel;

  @override
  State<SessionLockDialogContent> createState() =>
      _SessionLockDialogContentState();
}

class _SessionLockDialogContentState extends State<SessionLockDialogContent>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  late final List<TextEditingController> _boxControllers;
  late final List<FocusNode> _focusNodes;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _hasErrorBorder = false;

  @override
  void initState() {
    super.initState();
    _boxControllers = List.generate(_pinLength, (_) => TextEditingController());
    _focusNodes = List.generate(_pinLength, (_) => FocusNode());
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    widget.pinController.addListener(_syncFromParentController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.rateLimited) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(SessionLockDialogContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null &&
        widget.errorMessage != oldWidget.errorMessage) {
      _hasErrorBorder = true;
      _triggerShake();
    }
    if (widget.rateLimited && !oldWidget.rateLimited) {
      for (final n in _focusNodes) {
        n.unfocus();
      }
    }
  }

  @override
  void dispose() {
    widget.pinController.removeListener(_syncFromParentController);
    _shakeController.dispose();
    for (final c in _boxControllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _syncFromParentController() {
    if (widget.pinController.text.isEmpty) {
      _clearBoxes(keepFocus: false);
    }
  }

  void _clearBoxes({bool keepFocus = true}) {
    for (final c in _boxControllers) {
      c.clear();
    }
    _hasErrorBorder = false;
    if (keepFocus && !widget.rateLimited && mounted) {
      _focusNodes.first.requestFocus();
    }
  }

  void _syncToParent() {
    widget.pinController.text = _boxControllers.map((c) => c.text).join();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  bool get _canSubmit {
    if (widget.rateLimited) return false;
    final pin = _boxControllers.map((c) => c.text).join();
    return pin.length == _pinLength && RegExp(r'^\d+$').hasMatch(pin);
  }

  void _onBoxChanged(int index, String value) {
    widget.onPinChanged();
    if (_hasErrorBorder) {
      setState(() => _hasErrorBorder = false);
    }

    if (value.length == 1 && index < _pinLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _syncToParent();

    if (_canSubmit) {
      widget.onSubmit();
    }
  }

  Future<void> _handleSubmit() async {
    _syncToParent();
    await widget.onSubmit();
  }

  KeyEventResult _onKeyEvent(int index, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _boxControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rateLimited = widget.rateLimited;
    final errorText = widget.errorMessage;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              elevation: 24,
              shadowColor: Colors.black.withValues(alpha: 0.22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 36,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Sesioni u Bllokua',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vendos PIN-in e administratorit për të vazhduar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (i) {
                        return Padding(
                          padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 10,
                            right: i == _pinLength - 1 ? 0 : 10,
                          ),
                          child: _PinBoxField(
                            controller: _boxControllers[i],
                            focusNode: _focusNodes[i],
                            enabled: !rateLimited,
                            hasError: _hasErrorBorder,
                            onChanged: (v) => _onBoxChanged(i, v),
                            onKeyEvent: (node, event) =>
                                _onKeyEvent(i, node, event),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    if (rateLimited) ...[
                      Text(
                        'Shumë tentativa. Provo pas ${widget.lockoutSeconds}s.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.softRed,
                        ),
                      ),
                    ] else if (errorText != null) ...[
                      Text(
                        errorText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.softRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: _canSubmit
                              ? LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    AppColors.primaryGreen,
                                    AppColors.oliveGreen,
                                  ],
                                )
                              : null,
                          color: _canSubmit ? null : AppColors.lightGreenBg,
                          boxShadow: _canSubmit
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _canSubmit ? _handleSubmit : null,
                            borderRadius: BorderRadius.circular(16),
                            child: const Center(
                              child: Text(
                                'Vazhdo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.mediumGreenText,
                          side: BorderSide(
                            color: AppColors.lightGreenBorderEmpty(),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Anulo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinBoxField extends StatelessWidget {
  const _PinBoxField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final FocusOnKeyEventCallback onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: _kPinBoxSize,
        height: _kPinBoxSize,
        child: Focus(
          onKeyEvent: onKeyEvent,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            obscureText: true,
            obscuringCharacter: '•',
            maxLength: 1,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
              height: 1.1,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.beige,
              contentPadding: EdgeInsets.zero,
              border: _border(
                hasError
                    ? AppColors.softRed
                    : AppColors.lightGreenBorderEmpty(),
                width: hasError ? 2 : 1,
              ),
              enabledBorder: _border(
                hasError
                    ? AppColors.softRed
                    : AppColors.lightGreenBorderEmpty(),
                width: hasError ? 2 : 1,
              ),
              focusedBorder: _border(
                hasError ? AppColors.softRed : AppColors.primaryGreen,
                width: 2,
              ),
              disabledBorder: _border(
                AppColors.lightGreenBorderEmpty().withValues(alpha: 0.5),
              ),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onChanged(controller.text),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kPinBoxRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

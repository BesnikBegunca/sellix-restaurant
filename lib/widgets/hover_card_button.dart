import 'package:flutter/material.dart';

class HoverCardButton extends StatefulWidget {
  const HoverCardButton({super.key, required this.onPressed, required this.builder});

  final VoidCallback onPressed;
  final Widget Function(BuildContext context, bool isHovered) builder;

  @override
  State<HoverCardButton> createState() => _HoverCardButtonState();
}

class _HoverCardButtonState extends State<HoverCardButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

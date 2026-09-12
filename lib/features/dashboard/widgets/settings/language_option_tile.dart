import 'package:flutter/material.dart';

import '../../../../services/app_language_service.dart';

/// One selectable language in the settings language grid.
class LanguageOptionTile extends StatefulWidget {
  const LanguageOptionTile({
    super.key,
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<LanguageOptionTile> createState() => _LanguageOptionTileState();
}

class _LanguageOptionTileState extends State<LanguageOptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;

    final borderColor = selected
        ? scheme.primary
        : _hovered
        ? scheme.primary.withValues(alpha: 0.45)
        : scheme.outlineVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : _hovered
                ? scheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                widget.language.flag,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.language.nativeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Badge(
                text: widget.language.badge,
                selected: selected,
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

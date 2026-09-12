import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Light / dark chooser showing a miniature preview of each appearance rather
/// than a bare switch, so the choice is visible before it is made.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({
    super.key,
    required this.isDark,
    required this.onChanged,
    required this.lightLabel,
    required this.darkLabel,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;
  final String lightLabel;
  final String darkLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 340;
        final options = [
          _ThemeOption(
            label: lightLabel,
            selected: !isDark,
            dark: false,
            onTap: () => onChanged(false),
          ),
          _ThemeOption(
            label: darkLabel,
            selected: isDark,
            dark: true,
            onTap: () => onChanged(true),
          ),
        ];

        if (stacked) {
          return Column(
            children: [options[0], const SizedBox(height: 10), options[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: options[0]),
            const SizedBox(width: 12),
            Expanded(child: options[1]),
          ],
        );
      },
    );
  }
}

class _ThemeOption extends StatefulWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;

    // Colours of the miniature being previewed — always the *other* theme's
    // real palette, independent of what is currently active.
    final bg = widget.dark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surface = widget.dark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final line = widget.dark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final accent = widget.dark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final textBar = widget.dark
        ? AppTheme.darkOnSurfaceVariant
        : AppTheme.lightOnSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : _hovered
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniature app window. Unselected previews are dimmed slightly
              // so a light preview does not glare out of a dark settings page
              // (and vice versa) before it is chosen.
              Opacity(
                opacity: selected ? 1 : 0.72,
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: line),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sidebar
                      Container(
                        width: 16,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: line),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 4,
                        ),
                        child: Column(
                          children: [
                            Container(height: 3, color: accent),
                            const SizedBox(height: 3),
                            Container(
                              height: 2,
                              color: textBar.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 2,
                              color: textBar.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 5,
                              width: 26,
                              decoration: BoxDecoration(
                                color: textBar,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _miniCard(surface, line, accent),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _miniCard(surface, line, null),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    widget.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 16,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    scale: selected ? 1 : 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCard(Color surface, Color line, Color? accent) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: line),
      ),
      padding: const EdgeInsets.all(4),
      alignment: Alignment.bottomLeft,
      child: accent == null
          ? null
          : Container(
              height: 3,
              width: 14,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
    );
  }
}

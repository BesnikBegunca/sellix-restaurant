import 'package:flutter/material.dart';

/// Layout primitives shared by the manager dashboard panels.
///
/// The panels used to lay their controls out as a single bare [Row] of
/// unlabelled fields, which crammed together on narrow windows and gave no
/// hint what each field was. These widgets provide a labelled, wrapping,
/// responsive alternative that every panel can reuse.

/// Page heading: a title, an optional one-line description, and optional
/// trailing actions that drop below the title when the window is narrow.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (actions.isEmpty) {
      return Padding(padding: const EdgeInsets.only(bottom: 24), child: text);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              const SizedBox(width: 24),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        },
      ),
    );
  }
}

/// A titled card used to group the controls of one task (e.g. "Add a waiter").
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasHeader = title != null || trailing != null;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 20, color: scheme.primary),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: scheme.onSurface,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }
}

/// A form field with a label above it, sized to a preferred width but free to
/// shrink. Meant to be dropped into a [PanelFormRow].
class PanelField extends StatelessWidget {
  const PanelField({
    super.key,
    required this.label,
    required this.child,
    this.width = 240,
    this.flex,
    this.helper,
  });

  final String label;
  final Widget child;

  /// Preferred width when the row wraps rather than flexes.
  final double width;

  /// When set, the field flexes to this share of the row instead of using
  /// [width].
  final int? flex;

  final String? helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
        child,
        if (helper != null) ...[
          const SizedBox(height: 5),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

/// Lays [PanelField]s out in a row that wraps to multiple lines instead of
/// squeezing every control onto one line.
///
/// Above [breakpoint] the fields flex across one row; below it each field takes
/// the full width and stacks, so nothing is ever crushed to an unusable size.
class PanelFormRow extends StatelessWidget {
  const PanelFormRow({
    super.key,
    required this.fields,
    this.trailing,
    this.breakpoint = 820,
    this.spacing = 14,
  });

  /// The fields in display order.
  final List<PanelField> fields;

  /// Action buttons placed at the end of the row (bottom-aligned with inputs).
  final Widget? trailing;

  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < breakpoint;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                fields[i],
              ],
              if (trailing != null) ...[
                SizedBox(height: spacing + 2),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(
                flex: fields[i].flex ?? _flexFor(fields[i].width),
                child: fields[i],
              ),
            ],
            if (trailing != null) ...[
              SizedBox(width: spacing),
              Padding(
                // Align the button with the inputs, not the labels.
                padding: const EdgeInsets.only(bottom: 1),
                child: trailing,
              ),
            ],
          ],
        );
      },
    );
  }

  /// Turn a preferred width into a flex weight so wide fields stay wide.
  static int _flexFor(double width) => (width / 40).round().clamp(2, 12);
}

/// Section separator with a small caption — used to break a long panel into
/// scannable groups.
class PanelSectionLabel extends StatelessWidget {
  const PanelSectionLabel({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Inline error message shown under a form.
class PanelErrorBanner extends StatelessWidget {
  const PanelErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: scheme.error),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.35, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive two-column layout that collapses to one column when narrow.
class PanelColumns extends StatelessWidget {
  const PanelColumns({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 900,
    this.gap = 16,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;
  final double gap;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: gap),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            SizedBox(width: gap),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

/// Row of KPI/stat cards that reflows into fewer columns as the window
/// narrows, instead of squeezing every card onto one line.
class PanelStatRow extends StatelessWidget {
  const PanelStatRow({
    super.key,
    required this.cards,
    this.gap = 12,
    this.minCardWidth = 220,
  });

  final List<Widget> cards;
  final double gap;

  /// Below this width a card stops being readable, so the row wraps instead.
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final perRow = ((c.maxWidth + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, cards.length);

        if (perRow >= cards.length) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += perRow) {
          final slice = cards.sublist(i, (i + perRow).clamp(0, cards.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < perRow; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    // Pad the final row so cards keep their column width.
                    Expanded(
                      child: j < slice.length
                          ? slice[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

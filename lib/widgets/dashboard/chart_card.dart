import 'package:flutter/material.dart';

import 'app_card.dart';

/// Chart-sized [AppCard] for analytics-style blocks.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.minHeight = 240,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: title,
      subtitle: subtitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: child,
      ),
    );
  }
}

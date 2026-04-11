import 'package:flutter/material.dart';

/// Rrjeti për kategori dhe produkte në POS (4 kolona).
abstract final class PosGrid {
  static const int crossAxisCount = 4;
  static const int tableCrossAxisCount = 6;
  static const double spacing = 24;
  static const double childAspectRatio = 1.55;

  static const SliverGridDelegateWithFixedCrossAxisCount delegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
    childAspectRatio: childAspectRatio,
  );

  /// Rrjeti i tavolinave në `TableSelectionScreen` (6 kolona).
  static const SliverGridDelegateWithFixedCrossAxisCount tableDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: tableCrossAxisCount,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
    childAspectRatio: childAspectRatio,
  );

  static double cellWidth(double gridInnerWidth) {
    final n = crossAxisCount;
    return (gridInnerWidth - (n - 1) * spacing) / n;
  }

  static double cellHeight(double gridInnerWidth) =>
      cellWidth(gridInnerWidth) / childAspectRatio;

  static double tableCellWidth(double gridInnerWidth) {
    final n = tableCrossAxisCount;
    return (gridInnerWidth - (n - 1) * spacing) / n;
  }

  static double tableCellHeight(double gridInnerWidth) =>
      tableCellWidth(gridInnerWidth) / childAspectRatio;
}

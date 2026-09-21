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

  /// Rrjeti i tavolinave në `TableSelectionScreen` (6 kolona — default).
  static const SliverGridDelegateWithFixedCrossAxisCount tableDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: tableCrossAxisCount,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
    childAspectRatio: childAspectRatio,
  );

  static SliverGridDelegateWithFixedCrossAxisCount tableDelegateFor(
    int columns,
  ) {
    final c = columns.clamp(2, 12);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: c,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
    );
  }

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

  static double tableCellWidthFor(double gridInnerWidth, int columns) {
    final n = columns.clamp(2, 12);
    return (gridInnerWidth - (n - 1) * spacing) / n;
  }

  static double tableCellHeightFor(double gridInnerWidth, int columns) =>
      tableCellWidthFor(gridInnerWidth, columns) / childAspectRatio;

  /// Rrit kolonat derisa të gjithë [itemCount] qelizat përshtaten në [height]
  /// (pa scroll — i njëjti algoritëm si te ekrani i tavolinave).
  static int resolveCrossAxisCount({
    required int itemCount,
    required double width,
    required double height,
    int startColumns = crossAxisCount,
    int minColumns = 2,
    int maxColumns = 12,
  }) {
    if (itemCount <= 0) return startColumns.clamp(minColumns, maxColumns);

    final W = width;
    final H = height;
    var columns = startColumns.clamp(minColumns, maxColumns);

    while (columns < itemCount && columns < maxColumns) {
      final rows = (itemCount / columns).ceil();
      final cellW = (W - (columns - 1) * spacing) / columns;
      final cellH = cellW / childAspectRatio;
      final needed = rows * cellH + (rows - 1) * spacing;
      if (needed <= H) break;
      columns++;
    }
    return columns;
  }

  static SliverGridDelegateWithFixedCrossAxisCount delegateFor(int columns) {
    final c = columns.clamp(2, 12);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: c,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
    );
  }

  /// Taller product cards when the admin enlarges product names.
  static double productAspectRatioFor(int nameScale) {
    return switch (nameScale.clamp(0, 2)) {
      1 => 1.22,
      2 => 1.02,
      _ => childAspectRatio,
    };
  }

  static int resolveProductCrossAxisCount({
    required int itemCount,
    required double width,
    required double height,
    required int nameScale,
    int startColumns = crossAxisCount,
    int minColumns = 2,
    int maxColumns = 12,
  }) {
    if (itemCount <= 0) return startColumns.clamp(minColumns, maxColumns);
    final ratio = productAspectRatioFor(nameScale);
    var columns = startColumns.clamp(minColumns, maxColumns);
    while (columns < itemCount && columns < maxColumns) {
      final rows = (itemCount / columns).ceil();
      final cellW = (width - (columns - 1) * spacing) / columns;
      final cellH = cellW / ratio;
      final needed = rows * cellH + (rows - 1) * spacing;
      if (needed <= height) break;
      columns++;
    }
    return columns;
  }

  static SliverGridDelegateWithFixedCrossAxisCount productDelegateFor(
    int columns, {
    required int nameScale,
  }) {
    final c = columns.clamp(2, 12);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: c,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: productAspectRatioFor(nameScale),
    );
  }
}

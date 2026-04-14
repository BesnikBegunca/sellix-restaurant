import 'package:flutter/material.dart';

// Domain models used throughout the app.
// All persistent data is loaded from SQLite via DatabaseService.

class TableInfo {
  const TableInfo({
    required this.id,
    required this.occupied,
    this.currentTotal,
  });

  final int id;
  final bool occupied;
  final double? currentTotal;

  factory TableInfo.fromMap(Map<String, dynamic> m) => TableInfo(
        id: m['id'] as int,
        occupied: (m['occupied'] as int) == 1,
        currentTotal: m['currentTotal'] as double?,
      );
}

class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.emoji,
    this.imagePath,
  });

  final String id;
  final String name;
  final double price;
  final String emoji;
  final String? imagePath;

  factory ProductItem.fromMap(Map<String, dynamic> m) => ProductItem(
        id: m['id'] as String,
        name: m['name'] as String,
        price: (m['price'] as num).toDouble(),
        emoji: m['emoji'] as String? ?? '☕',
        imagePath: m['imagePath'] as String?,
      );
}

class CategoryData {
  const CategoryData({
    required this.id,
    required this.name,
    required this.icon,
    required this.products,
  });

  final String id;
  final String name;
  final IconData icon;
  final List<ProductItem> products;

  /// Builds a [CategoryData] from a DB row. Products are supplied separately
  /// because they live in their own table.
  factory CategoryData.fromMap(
    Map<String, dynamic> m,
    List<ProductItem> products,
  ) =>
      CategoryData(
        id: m['id'] as String,
        name: m['name'] as String,
        // All predefined Material icons use fontFamily 'MaterialIcons'.
        icon: IconData(
          m['iconCodePoint'] as int,
          fontFamily: 'MaterialIcons',
        ),
        products: products,
      );
}

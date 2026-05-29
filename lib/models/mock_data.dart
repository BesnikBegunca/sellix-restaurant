import 'package:flutter/material.dart';

// Domain models used throughout the app.
// All persistent data is loaded from SQLite via DatabaseService.

class TableInfo {
  const TableInfo({
    required this.id,
    required this.occupied,
    this.currentTotal,
    this.assignedWaiterName,
    this.currentOrderNumber,
  });

  final int id;
  final bool occupied;
  final double? currentTotal;
  final String? assignedWaiterName;
  final int? currentOrderNumber;

  factory TableInfo.fromMap(Map<String, dynamic> m) => TableInfo(
        id: (m['id'] as num).toInt(),
        occupied: ((m['occupied'] as num?) ?? 0).toInt() == 1,
        currentTotal: (m['currentTotal'] as num?)?.toDouble(),
        assignedWaiterName: m['assignedWaiterName'] as String?,
        currentOrderNumber: (m['currentOrderNumber'] as num?)?.toInt(),
      );
}

class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.emoji,
    this.imagePath,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final double price;
  final String emoji;
  final String? imagePath;
  final int sortOrder;

  factory ProductItem.fromMap(Map<String, dynamic> m) => ProductItem(
        id: m['id'] as String,
        name: m['name'] as String,
        price: (m['price'] as num).toDouble(),
        emoji: m['emoji'] as String? ?? '☕',
        imagePath: m['imagePath'] as String?,
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
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

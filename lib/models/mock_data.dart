import 'package:flutter/material.dart';

// Të dhëna statike vetëm për UI.

class TableInfo {
  const TableInfo({
    required this.id,
    required this.occupied,
    this.currentTotal,
  });

  final int id;
  final bool occupied;
  final double? currentTotal;
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
}

final List<TableInfo> mockTables = [
  for (var i = 1; i <= 15; i++) TableInfo(id: i, occupied: false),
];

final List<CategoryData> mockCategories = [
  CategoryData(
    id: 'coffee',
    name: 'Coffee',
    icon: Icons.local_cafe_outlined,
    products: const [
      ProductItem(id: 'c1', name: 'Espresso', price: 2.5, emoji: '☕', imagePath: 'assets/images/espreso.webp'),
      ProductItem(id: 'c2', name: 'Macchiato', price: 4.0, emoji: '☕', imagePath: 'assets/images/makiato.png'),
      ProductItem(id: 'c3', name: 'Cappuccino', price: 4.25, emoji: '☕', imagePath: 'assets/images/kapuqino.png'),
    ],
  ),
  CategoryData(
    id: 'spirits',
    name: 'Spirits',
    icon: Icons.liquor_outlined,
    products: const [
      ProductItem(id: 'sp9', name: 'Coca Cola', price: 2.5, emoji: '🥤', imagePath: 'assets/images/cocacola.png'),
      ProductItem(id: 'sp10', name: 'Fanta', price: 2.5, emoji: '🥤', imagePath: 'assets/images/fanta.webp'),
      ProductItem(id: 'sp11', name: 'Sprite', price: 2.5, emoji: '🥤', imagePath: 'assets/images/sprite.png'),
      ProductItem(id: 'sp12', name: 'Heineken', price: 3.5, emoji: '🍺', imagePath: 'assets/images/heineken.png'),
      ProductItem(id: 'sp13', name: 'Peja', price: 3.0, emoji: '🍺', imagePath: 'assets/images/peja.png'),
      ProductItem(id: 'sp14', name: 'Shkupi', price: 3.0, emoji: '🍺', imagePath: 'assets/images/shkupi.png'),
      ProductItem(id: 'sp15', name: 'Tuborg', price: 3.5, emoji: '🍺', imagePath: 'assets/images/tuborg.png'),
    ],
  ),
  CategoryData(
    id: 'cocktails',
    name: 'Cocktails',
    icon: Icons.local_bar_outlined,
    products: const [
      ProductItem(id: 'ck1', name: 'Mojito', price: 9.0, emoji: '🍹'),
      ProductItem(id: 'ck2', name: 'Margarita', price: 9.5, emoji: '🍸'),
      ProductItem(id: 'ck3', name: 'Martini', price: 10.0, emoji: '🍸'),
      ProductItem(id: 'ck4', name: 'Cosmopolitan', price: 9.75, emoji: '🍸'),
      ProductItem(id: 'ck5', name: 'Old Fashioned', price: 10.5, emoji: '🥃'),
      ProductItem(id: 'ck6', name: 'Negroni', price: 10.0, emoji: '🍹'),
      ProductItem(id: 'ck7', name: 'Aperol Spritz', price: 9.25, emoji: '🧡'),
      ProductItem(id: 'ck8', name: 'Moscow Mule', price: 9.0, emoji: '🫚'),
    ],
  ),
  CategoryData(
    id: 'snack',
    name: 'Snack',
    icon: Icons.cookie_outlined,
    products: const [
      ProductItem(id: 's1', name: 'Croissant', price: 3.5, emoji: '🥐'),
      ProductItem(id: 's2', name: 'Muffin', price: 3.0, emoji: '🧁'),
      ProductItem(id: 's3', name: 'Bagel', price: 2.75, emoji: '🥯'),
      ProductItem(id: 's4', name: 'Brownie', price: 3.25, emoji: '🍫'),
    ],
  ),
];

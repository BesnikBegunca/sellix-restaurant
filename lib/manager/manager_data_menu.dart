part of 'manager_data.dart';

extension MenuMethods on ManagerData {
  // ─────────────────────────────── menu ─────────────────────────────────────

  Future<void> addCategoryWithIcon({
    required String name,
    required int iconCodePoint,
  }) async {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final sortOrder = _categories.length;

    await ProductRepository.instance.insertCategory(
      id: id,
      name: name.trim(),
      iconCodePoint: iconCodePoint,
      sortOrder: sortOrder,
    );

    final icon = IconData(iconCodePoint, fontFamily: 'MaterialIcons');

    _categories = [
      ..._categories,
      CategoryData(id: id, name: name.trim(), icon: icon, products: const []),
    ];
    AuditLogService.instance.logCategoryCreated(
      categoryId:   id,
      categoryName: name.trim(),
    );
    _notify();
  }

  // Backward compatible helper (keeps older code compiling if present).
  Future<void> addCategory(String name) async {
    await addCategoryWithIcon(
      name: name,
      iconCodePoint: Icons.restaurant_menu_outlined.codePoint,
    );
  }

  Future<void> removeCategory(String categoryId) async {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryData(id: categoryId, name: '', icon: Icons.category, products: []),
    );
    await ProductRepository.instance.deleteCategory(categoryId);
    _categories = _categories.where((c) => c.id != categoryId).toList();
    AuditLogService.instance.logCategoryDeleted(
      categoryId:   categoryId,
      categoryName: cat.name,
    );
    _notify();
  }

  Future<void> addProduct({
    required String categoryId,
    required String name,
    required double price,
    String emoji = '☕',
    String? imagePath,
  }) async {
    final pid = 'p_${DateTime.now().microsecondsSinceEpoch}';
    await ProductRepository.instance.insertProduct(
      id: pid,
      name: name.trim(),
      price: price,
      emoji: emoji,
      imagePath: imagePath,
      categoryId: categoryId,
    );
    final product = ProductItem(
      id: pid,
      name: name.trim(),
      price: price,
      emoji: emoji,
      imagePath: imagePath,
    );
    _categories = _categories.map((c) {
      if (c.id != categoryId) return c;
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: [...c.products, product],
      );
    }).toList();
    final catName = _categories
        .firstWhere((c) => c.id == categoryId, orElse: () => CategoryData(id: '', name: '', icon: Icons.category, products: []))
        .name;
    AuditLogService.instance.logProductCreated(
      productId:    pid,
      productName:  name.trim(),
      price:        price,
      categoryName: catName,
    );
    _notify();
  }

  Future<void> removeProduct(String categoryId, String productId) async {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryData(id: '', name: '', icon: Icons.category, products: []),
    );
    final prod = cat.products.firstWhere(
      (p) => p.id == productId,
      orElse: () => ProductItem(id: productId, name: '', price: 0, emoji: ''),
    );
    await ProductRepository.instance.deleteProduct(productId);
    _categories = _categories.map((c) {
      if (c.id != categoryId) return c;
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: c.products.where((p) => p.id != productId).toList(),
      );
    }).toList();
    AuditLogService.instance.logProductDeleted(
      productId:    productId,
      productName:  prod.name,
      categoryName: cat.name,
    );
    _notify();
  }

  Future<void> editProduct(
    String categoryId,
    String productId, {
    String? name,
    double? price,
    String? imagePath,
    bool clearImage = false,
  }) async {
    final fields = <String, dynamic>{};
    if (name != null) fields['name'] = name;
    if (price != null) fields['price'] = price;
    if (clearImage) {
      fields['imagePath'] = null;
    } else if (imagePath != null) {
      fields['imagePath'] = imagePath;
    }
    // Capture old values before update for audit snapshot.
    ProductItem? oldProduct;
    for (final c in _categories) {
      if (c.id == categoryId) {
        try { oldProduct = c.products.firstWhere((p) => p.id == productId); } catch (_) {}
        break;
      }
    }

    if (fields.isNotEmpty) {
      await ProductRepository.instance.updateProduct(productId, fields);
    }

    _categories = _categories.map((c) {
      if (c.id != categoryId) return c;
      return CategoryData(
        id: c.id,
        name: c.name,
        icon: c.icon,
        products: c.products.map((p) {
          if (p.id != productId) return p;
          return ProductItem(
            id: p.id,
            name: name ?? p.name,
            price: price ?? p.price,
            emoji: p.emoji,
            imagePath: clearImage ? null : (imagePath ?? p.imagePath),
          );
        }).toList(),
      );
    }).toList();

    AuditLogService.instance.logProductEdited(
      productId:   productId,
      productName: name ?? oldProduct?.name ?? productId,
      oldValues:   {
        if (oldProduct != null && name  != null) 'name':  oldProduct.name,
        if (oldProduct != null && price != null) 'price': oldProduct.price,
      },
      newValues: {
        if (name  != null) 'name':  name,
        if (price != null) 'price': price,
      },
    );
    _notify();
  }

  /// Lëviz produktin lart/poshtë në listë brenda kategorisë ([direction] -1 ose +1).
  Future<void> reorderProduct(
    String categoryId,
    String productId,
    int direction,
  ) async {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryData(id: categoryId, name: '', icon: Icons.category, products: []),
    );
    final ids = cat.products.map((p) => p.id).toList();
    final idx = ids.indexOf(productId);
    if (idx < 0) return;
    final newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= ids.length) return;
    final moved = ids.removeAt(idx);
    ids.insert(newIdx, moved);
    await ProductRepository.instance.setProductOrderInCategory(categoryId, ids);
    await _reloadMenu();
    _notify();
  }

  Future<void> moveProduct(
    String fromCategoryId,
    String productId,
    String toCategoryId,
  ) async {
    if (fromCategoryId == toCategoryId) return;

    // Find the product in the cache
    ProductItem? product;
    for (final c in _categories) {
      if (c.id == fromCategoryId) {
        try {
          product = c.products.firstWhere((p) => p.id == productId);
        } catch (_) {}
        break;
      }
    }
    if (product == null) return;
    final prod = product;

    await ProductRepository.instance.moveProductCategory(
      productId,
      toCategoryId,
    );

    _categories = _categories.map((c) {
      if (c.id == fromCategoryId) {
        return CategoryData(
          id: c.id,
          name: c.name,
          icon: c.icon,
          products: c.products.where((p) => p.id != productId).toList(),
        );
      }
      if (c.id == toCategoryId) {
        return CategoryData(
          id: c.id,
          name: c.name,
          icon: c.icon,
          products: [...c.products, prod],
        );
      }
      return c;
    }).toList();
    _notify();
  }


}

import '../services/database_service.dart';

/// Menu categories and products.
class ProductRepository {
  ProductRepository._();
  static final ProductRepository instance = ProductRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<List<Map<String, dynamic>>> fetchCategories() => _db.fetchCategories();

  Future<List<Map<String, dynamic>>> fetchProducts() => _db.fetchProducts();

  Future<void> insertCategory({
    required String id,
    required String name,
    required int iconCodePoint,
    required int sortOrder,
  }) =>
      _db.insertCategory(
        id: id,
        name: name,
        iconCodePoint: iconCodePoint,
        sortOrder: sortOrder,
      );

  Future<void> deleteCategory(String id) => _db.deleteCategory(id);

  Future<void> insertProduct({
    required String id,
    required String name,
    required double price,
    required String emoji,
    String? imagePath,
    required String categoryId,
  }) =>
      _db.insertProduct(
        id: id,
        name: name,
        price: price,
        emoji: emoji,
        imagePath: imagePath,
        categoryId: categoryId,
      );

  Future<void> updateProduct(String id, Map<String, dynamic> fields) =>
      _db.updateProduct(id, fields);

  Future<void> deleteProduct(String id) => _db.deleteProduct(id);

  Future<void> moveProductCategory(String productId, String newCategoryId) =>
      _db.moveProductCategory(productId, newCategoryId);
}

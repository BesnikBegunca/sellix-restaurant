import '../services/database_service.dart';

/// Inventory items and stock movement ledger.
class InventoryRepository {
  InventoryRepository._();
  static final InventoryRepository instance = InventoryRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<int> insertInventoryItem({
    required String name,
    required String unit,
    String? productUuid,
    double currentQuantity = 0,
    double lowStockThreshold = 0,
    double costPerUnit = 0,
    bool isActive = true,
  }) =>
      _db.insertInventoryItem(
        name: name,
        unit: unit,
        productUuid: productUuid,
        currentQuantity: currentQuantity,
        lowStockThreshold: lowStockThreshold,
        costPerUnit: costPerUnit,
        isActive: isActive,
      );

  Future<void> updateInventoryItem(int id, Map<String, dynamic> fields) =>
      _db.updateInventoryItem(id, fields);

  Future<List<Map<String, dynamic>>> getInventoryItems({
    bool includeInactive = false,
  }) =>
      _db.getInventoryItems(includeInactive: includeInactive);

  Future<List<Map<String, dynamic>>> getLowStockItems() =>
      _db.getLowStockItems();

  Future<int> insertStockMovement({
    required String inventoryItemUuid,
    required String movementType,
    required double quantity,
    String? reason,
    String? referenceType,
    String? referenceUuid,
  }) =>
      _db.insertStockMovement(
        inventoryItemUuid: inventoryItemUuid,
        movementType: movementType,
        quantity: quantity,
        reason: reason,
        referenceType: referenceType,
        referenceUuid: referenceUuid,
      );

  Future<List<Map<String, dynamic>>> getStockMovementsForItem(
    String inventoryItemUuid, {
    int? limit,
  }) =>
      _db.getStockMovementsForItem(inventoryItemUuid, limit: limit);
}

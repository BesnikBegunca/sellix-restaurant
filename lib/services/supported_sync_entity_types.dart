/// Entity types accepted by pos_api [SUPPORTED_ENTITY_TYPES].
///
/// Desktop must not enqueue outbox rows for other types — they are rejected
/// with "Unsupported entityType" and clutter sync diagnostics.
const Set<String> supportedSyncEntityTypes = {
  'sales',
  'sale_lines',
  'sale_adjustments',
  'products',
  'categories',
  'expenses',
  'shifts',
  'inventory_items',
  'stock_movements',
};

String normalizeSyncEntityType(String entityType) =>
    entityType.trim().toLowerCase().replaceAll('-', '_');

/// Whether [entityType] may be written to the outbox and pushed to pos_api.
bool isSupportedSyncEntityType(String entityType) =>
    supportedSyncEntityTypes.contains(normalizeSyncEntityType(entityType));

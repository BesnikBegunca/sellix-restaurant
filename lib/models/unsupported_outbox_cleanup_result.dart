/// Result of [DatabaseService.cleanupUnsupportedOutboxEvents].
class UnsupportedOutboxCleanupResult {
  const UnsupportedOutboxCleanupResult({
    required this.totalRemoved,
    required this.removedByEntityType,
  });

  /// Total outbox rows deleted.
  final int totalRemoved;

  /// Deleted row counts keyed by normalized [entityType].
  final Map<String, int> removedByEntityType;
}

import '../services/database_service.dart';

/// Outbox queue for future NestJS upload.
class SyncRepository {
  SyncRepository._();
  static final SyncRepository instance = SyncRepository._();

  final DatabaseService _db = DatabaseService.instance;

  Future<String> insertOutboxEvent({
    required String entityType,
    required String entityUuid,
    required String operation,
    required String payloadJson,
    String? businessId,
    String? branchId,
    String? deviceId,
  }) =>
      _db.insertOutboxEvent(
        entityType: entityType,
        entityUuid: entityUuid,
        operation: operation,
        payloadJson: payloadJson,
        businessId: businessId,
        branchId: branchId,
        deviceId: deviceId,
      );

  Future<List<Map<String, dynamic>>> getPendingOutboxEvents({
    int limit = 100,
  }) =>
      _db.getPendingOutboxEvents(limit: limit);

  /// Count of pending rows (capped by [limit] for performance).
  Future<int> pendingOutboxCount({int limit = 1000}) async {
    final rows = await getPendingOutboxEvents(limit: limit);
    return rows.length;
  }

  Future<void> markOutboxEventSynced(String uuid) =>
      _db.markOutboxEventSynced(uuid);

  Future<void> markOutboxEventFailed(String uuid, String error) =>
      _db.markOutboxEventFailed(uuid, error);
}

import 'dart:convert';

import 'activation_service.dart';
import 'api_client.dart';
import 'background_sync_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'secure_activation_token_store.dart';
import 'support_bundle_redaction.dart';
/// Builds a JSON bundle of sync/outbox diagnostics for support.
class SyncDiagnosticsExportService {
  SyncDiagnosticsExportService._();
  static final SyncDiagnosticsExportService instance =
      SyncDiagnosticsExportService._();

  Future<String> exportFailedOutboxJson() async {
    final db = DatabaseService.instance;
    final failed = await db.getAllFailedOutboxEvents();
    final backoff = BackgroundSyncService.instance;

    final payload = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'apiBaseUrl': ApiClient.instance.baseUrl,
      'connectivity': ConnectivityService.instance.isOnline ? 'online' : 'offline',
      'activation': {
        'isActivated': ActivationService.instance.isActivated,
        'businessId': ActivationService.instance.businessId,
        'branchId': ActivationService.instance.branchId,
        'deviceId': ActivationService.instance.serverDeviceId,
        'tokenStorage':
            SecureActivationTokenStore.instance.diagnosticsStorageLabel,
        'accessTokenPresent':
            await SecureActivationTokenStore.instance.readAccessToken() !=
                null,
        'refreshTokenPresent':
            await SecureActivationTokenStore.instance.readRefreshToken() !=
                null,
      },
      'syncMeta': {
        'sync_last_push_at': await db.getAppMeta('sync_last_push_at'),
        'sync_last_pull_at': await db.getAppMeta('sync_last_pull_at'),
        'sync_last_success_at': await db.getAppMeta('sync_last_success_at'),
        'sync_last_error': await db.getAppMeta('sync_last_error'),
        'sync_pull_cursor': await db.getPullCursor(),
      },
      'backoff': {
        'failureCount': backoff.backoffFailureCount,
        'exhausted': backoff.backoffExhausted,
        'nextRetryAt': backoff.nextRetryAt?.toIso8601String(),
        'remainingSeconds': backoff.retryBackoffRemaining?.inSeconds,
      },
      'outboxCounts': {
        'pending': await db.getPendingOutboxCount(),
        'failed': await db.getFailedOutboxCount(),
      },
      'failedEvents': failed.map(_mapOutboxRow).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(redactMap(payload));
  }

  Map<String, dynamic> _mapOutboxRow(Map<String, dynamic> row) {
    final payloadRaw = row['payloadJson'];
    dynamic payloadDecoded;
    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        payloadDecoded = jsonDecode(payloadRaw);
      } catch (_) {
        payloadDecoded = payloadRaw;
      }
    }

    return {
      'uuid': row['uuid'],
      'entityType': row['entityType'],
      'entityUuid': row['entityUuid'],
      'operation': row['operation'],
      'syncStatus': row['syncStatus'],
      'lastError': row['lastError'],
      'retryCount': row['retryCount'],
      'businessId': row['businessId'],
      'branchId': row['branchId'],
      'deviceId': row['deviceId'],
      'createdAt': row['createdAt'],
      'updatedAt': row['updatedAt'],
      'payload': payloadDecoded is Map
          ? redactMap(Map<String, dynamic>.from(payloadDecoded))
          : payloadDecoded,
    };
  }
}

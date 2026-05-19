import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_version_info.dart';
import '../manager/manager_data.dart';
import 'activation_service.dart';
import 'background_sync_service.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'printer_settings_store.dart';
import 'runtime_config_service.dart';
import 'secure_activation_token_store.dart';
import 'support_bundle_redaction.dart';

/// Builds and saves a non-sensitive JSON support bundle for remote troubleshooting.
class SupportBundleService {
  SupportBundleService._();
  static final SupportBundleService instance = SupportBundleService._();

  static const int _kSchemaVersion = 22;
  static const int _recentOutboxLimit = 20;
  static const int _recentAuditLimit = 20;

  /// Collects diagnostics, redacts secrets, returns indented JSON.
  Future<String> buildSupportBundleJson() async {
    final payload = await collectSupportBundle();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Builds the support bundle map (already redacted).
  Future<Map<String, dynamic>> collectSupportBundle() async {
    final db = DatabaseService.instance;
    final config = RuntimeConfigService.instance;
    final backoff = BackgroundSyncService.instance;
    final store = SecureActivationTokenStore.instance;
    final accessPresent = await store.readAccessToken();
    final refreshPresent = await store.readRefreshToken();
    final printerName = await PrinterSettingsStore.loadSelectedPrinterName();
    final data = ManagerData.instance;

    final failed = await db.getAllFailedOutboxEvents();
    final recentOutbox = await _fetchRecentOutbox(limit: _recentOutboxLimit);
    final recentAudit = await db.fetchAuditLogs(limit: _recentAuditLimit);

    final bundle = <String, dynamic>{
      'bundleVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': await _buildAppInfo(),
      'apiConfig': {
        'baseUrl': config.apiBaseUrl,
        'configSource': config.sourceLabel,
        'isUsingFallback': config.isUsingFallback,
        'isBlockedInRelease': config.isBlockedInRelease,
        'isLocalhost': config.isLocalhost,
      },
      'activation': {
        'activationCompleted':
            await db.getAppMeta('activation_completed') == 'true',
        'isActivated': ActivationService.instance.isActivated,
        'businessId': ActivationService.instance.businessId ??
            await db.getAppMeta(ActivationService.kMetaBusinessId),
        'branchId': ActivationService.instance.branchId ??
            await db.getAppMeta(ActivationService.kMetaBranchId),
        'deviceId': ActivationService.instance.serverDeviceId ??
            await db.getAppMeta(ActivationService.kMetaDeviceId),
        'businessName':
            await ActivationService.instance.activatedBusinessName(),
        'licenseExpiresAt':
            await db.getAppMeta('activation_license_expires_at'),
        'tokenStorage': store.diagnosticsStorageLabel,
        'accessTokenPresent':
            accessPresent != null && accessPresent.isNotEmpty,
        'refreshTokenPresent':
            refreshPresent != null && refreshPresent.isNotEmpty,
      },
      'sync': {
        'connectivity':
            ConnectivityService.instance.isOnline ? 'online' : 'offline',
        'pendingOutboxCount': await db.getPendingOutboxCount(),
        'failedOutboxCount': await db.getFailedOutboxCount(),
        'lastPushAt': await db.getAppMeta('sync_last_push_at'),
        'lastPullAt': await db.getAppMeta('sync_last_pull_at'),
        'lastSuccessAt': await db.getAppMeta('sync_last_success_at'),
        'lastError': await db.getAppMeta('sync_last_error'),
        'pullCursor': await db.getPullCursor(),
        'backoffFailureCount': backoff.backoffFailureCount,
        'backoffExhausted': backoff.backoffExhausted,
        'nextRetryAt': backoff.nextRetryAt?.toIso8601String(),
        'retryBackoffRemainingSeconds':
            backoff.retryBackoffRemaining?.inSeconds,
        'isSyncingPush': backoff.isSyncing,
        'isSyncingPull': backoff.isPulling,
        'pendingOutboxSampleCount': backoff.pendingCount,
      },
      'failedOutboxEvents': failed.map(_mapOutboxRow).toList(),
      'recentOutboxEvents': recentOutbox.map(_mapOutboxRow).toList(),
      'recentAuditLogs': recentAudit.map(_mapAuditRow).toList(),
      'rejectedReasons': _collectRejectedReasons(failed),
      'database': await _collectDatabaseHealth(),
      'printer': {
        'printerConfigured': printerName.trim().isNotEmpty,
        'printerName': printerName.trim().isEmpty ? null : printerName.trim(),
        'escPosEnabled': data.useEscPos,
        'cashDrawerEnabled': data.cashDrawerEnabled,
        'paperWidthMm': data.paperWidthMm,
      },
    };

    return redactMap(bundle);
  }

  /// Writes JSON to disk; returns absolute path.
  ///
  /// Uses [FilePicker.saveFile] when available; otherwise saves under app
  /// documents as `pos_support_bundle_YYYYMMDD_HHMMSS.json`.
  Future<String> exportSupportBundleToFile() async {
    final json = await buildSupportBundleJson();
    final fileName = _bundleFileName();

    try {
      final picked = await FilePicker.platform.saveFile(
        dialogTitle: 'Ruaj support bundle',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked != null && picked.isNotEmpty) {
        final path =
            picked.toLowerCase().endsWith('.json') ? picked : '$picked.json';
        await File(path).writeAsString(json);
        return path;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SupportBundleService: saveFile failed — $e');
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, fileName);
    await File(path).writeAsString(json);
    return path;
  }

  static String _bundleFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    return 'pos_support_bundle_$stamp.json';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<Map<String, dynamic>> _buildAppInfo() async {
    String osVersion = Platform.operatingSystem;
    try {
      osVersion = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {}

    return {
      'appName': 'pos_system',
      'version': AppVersionInfo.version,
      'buildNumber': AppVersionInfo.buildNumber,
      'flutterPlatform': defaultTargetPlatform.name,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': osVersion,
      'releaseMode': kReleaseMode,
      'debugMode': kDebugMode,
    };
  }

  Future<Map<String, dynamic>> _collectDatabaseHealth() async {
    final db = await DatabaseService.instance.database;
    final integrityRows = await db.rawQuery('PRAGMA integrity_check');
    final integrity = integrityRows
        .map((r) => r.values.first?.toString() ?? '')
        .toList();

    final dbPath = p.join(await getDatabasesPath(), 'pos_system.db');
    final file = File(dbPath);
    final exists = await file.exists();
    final sizeBytes = exists ? await file.length() : 0;

    int? userVersion;
    try {
      userVersion = await db.getVersion();
    } catch (_) {
      userVersion = _kSchemaVersion;
    }

    return {
      'integrityCheck': integrity,
      'integrityOk': integrity.length == 1 && integrity.first == 'ok',
      'schemaVersion': userVersion,
      'expectedSchemaVersion': _kSchemaVersion,
      'databaseFileName': p.basename(dbPath),
      'databaseSizeBytes': sizeBytes,
      'databaseExists': exists,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchRecentOutbox({required int limit}) async {
    final db = await DatabaseService.instance.database;
    return db.query(
      'outbox',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
  }

  List<String> _collectRejectedReasons(List<Map<String, dynamic>> failed) {
    final reasons = <String>{};
    for (final row in failed) {
      final err = row['lastError'] as String?;
      if (err != null && err.trim().isNotEmpty) {
        reasons.add(err.trim());
      }
    }
    return reasons.toList()..sort();
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
    if (payloadDecoded is Map) {
      payloadDecoded = redactMap(Map<String, dynamic>.from(payloadDecoded));
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
      'lastSyncedAt': row['lastSyncedAt'],
      'payload': payloadDecoded,
    };
  }

  Map<String, dynamic> _mapAuditRow(Map<String, dynamic> row) {
    dynamic details;
    final raw = row['detailsJson'];
    if (raw is String && raw.isNotEmpty) {
      try {
        details = jsonDecode(raw);
      } catch (_) {
        details = raw;
      }
    }
    if (details is Map) {
      details = redactMap(Map<String, dynamic>.from(details));
    }

    return {
      'id': row['id'],
      'actionType': row['actionType'],
      'performedBy': row['performedBy'],
      'performedRole': row['performedRole'],
      'shiftId': row['shiftId'],
      'saleId': row['saleId'],
      'tableId': row['tableId'],
      'createdAt': row['createdAt'],
      'details': details,
    };
  }
}

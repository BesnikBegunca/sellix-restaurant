import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/sellix_license.dart';
import 'activation_service.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'license_gate_service.dart';

/// Pushes Printo + Paguaj + live table occupancy to SelliX web.
class PortalSalesSyncService {
  PortalSalesSyncService._();
  static final PortalSalesSyncService instance = PortalSalesSyncService._();

  static const int _batchLimit = 200;

  bool _syncing = false;
  bool _queued = false;

  Future<void> triggerNow() async {
    if (_syncing) {
      _queued = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _queued = false;
        await _pushPending();
      } while (_queued);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushPending() async {
    if (!ActivationService.instance.isActivated) return;
    if (LicenseGateService.instance.isBlocked) return;
    if (!ConnectivityService.instance.isOnline) return;

    final key = await ActivationService.instance.storedLicenseKey();
    if (key == null || !isSellixLicenseKey(key)) return;

    final deviceId = await DatabaseService.instance.syncDeviceId();
    final pending = await DatabaseService.instance.fetchUnsyncedPortalSales(
      limit: _batchLimit,
    );
    final tables = await DatabaseService.instance.fetchPortalTableSnapshot();
    // Invoices the manager deleted / refunded here: the web must drop them too.
    final voids = await DatabaseService.instance.fetchUnsyncedPortalVoids(
      limit: _batchLimit,
    );

    final payload = <Map<String, dynamic>>[];
    for (final row in pending) {
      final mapped = _mapInvoice(row);
      if (mapped != null) payload.add(mapped);
    }
    final voidUids = <String>[];
    for (final row in voids) {
      final mapped = _mapVoid(row);
      if (mapped == null) continue;
      payload.add(mapped);
      voidUids.add(mapped['saleUid'] as String);
    }
    if (payload.isEmpty && tables.isEmpty) {
      await DatabaseService.instance.settlePortalSyncedOutbox();
      return;
    }

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        kEndpointSalesSync,
        data: {
          'licenseKey': normalizeSellixLicenseKey(key),
          'deviceId': deviceId,
          'sales': payload,
          'tables': tables,
        },
        options: Options(
          headers: {kHeaderLicenseKey: normalizeSellixLicenseKey(key)},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final data = response.data;
      if (response.statusCode != 200 || data == null || data['ok'] != true) {
        if (kDebugMode) {
          debugPrint(
            'PortalSalesSync: rejected status=${response.statusCode} '
            'reason=${data?['reason']}',
          );
        }
        return;
      }

      final rejectedUids = <String>{};
      final rejected = data['rejected'];
      if (rejected is List) {
        for (final item in rejected) {
          if (item is Map && item['saleUid'] != null) {
            rejectedUids.add(item['saleUid'].toString());
          }
        }
      }

      final acceptedUids = payload
          .map((e) => e['saleUid'] as String)
          .where((uid) => !rejectedUids.contains(uid))
          .toList();
      if (acceptedUids.isNotEmpty) {
        await DatabaseService.instance.markPortalSalesSynced(acceptedUids);
      }
      final acceptedVoids =
          voidUids.where((uid) => !rejectedUids.contains(uid)).toList();
      if (acceptedVoids.isNotEmpty) {
        await DatabaseService.instance.markPortalVoidsSynced(acceptedVoids);
      }
      await DatabaseService.instance.settlePortalSyncedOutbox();
      if (kDebugMode) {
        debugPrint(
          'PortalSalesSync: accepted=${acceptedUids.length} '
          'rejected=${rejectedUids.length} tables=${tables.length}',
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('PortalSalesSync: network/error $e');
      }
    }
  }

  /// A deleted / refunded invoice. Same uid as the original, status=void, so
  /// the server flips that row instead of adding a new one.
  Map<String, dynamic>? _mapVoid(Map<String, dynamic> row) {
    final uuid = (row['uuid'] as String?)?.trim();
    if (uuid == null || uuid.isEmpty) return null;
    final soldAtDt = parseStoredSaleTimestamp(row['soldAt'] as String?) ??
        DateTime.now();
    final tableName = (row['tableName'] as String?)?.trim() ?? '';
    final waiter = (row['waiterName'] as String?)?.trim() ?? '';
    return {
      'saleUid': uuid,
      'soldAt': toShopLocalSoldAt(soldAtDt),
      'total': row['total'] ?? 0,
      'tax': 0,
      'discount': 0,
      'paymentMethod': 'cash',
      'status': 'void',
      if (tableName.isNotEmpty) 'tableName': tableName,
      if (waiter.isNotEmpty) 'staffName': waiter,
    };
  }

  Map<String, dynamic>? _mapInvoice(Map<String, dynamic> row) {
    final uuid = (row['saleUid'] as String?)?.trim();
    if (uuid == null || uuid.isEmpty) return null;

    final soldAtDt = parseStoredSaleTimestamp(row['soldAtRaw'] as String?);
    if (soldAtDt == null) return null;

    final tableName = (row['tableName'] as String?)?.trim() ?? '';
    final waiter = (row['waiterName'] as String?)?.trim() ?? '';
    final orderNumber = row['orderNumber'];
    final items = <Map<String, dynamic>>[];
    final rawItems = row['items'];
    if (rawItems is List) {
      for (final line in rawItems) {
        if (line is! Map) continue;
        items.add({
          'name': (line['productName'] as String?)?.trim() ?? '',
          'quantity': line['qty'] ?? line['quantity'] ?? 1,
          'unitPrice': line['productPrice'] ?? 0,
          'total': line['lineTotal'] ?? 0,
          'category': (line['categoryName'] as String?) ?? '',
        });
      }
    }

    return {
      'saleUid': uuid,
      'soldAt': toShopLocalSoldAt(soldAtDt),
      'total': row['total'] ?? 0,
      'tax': 0,
      'discount': 0,
      'paymentMethod': 'cash',
      'status': (row['status'] as String?)?.trim() ?? 'paid',
      if (row['printDelta'] != null) 'printDelta': row['printDelta'],
      if (tableName.isNotEmpty) 'tableName': tableName,
      if (orderNumber != null) 'receiptNo': '$orderNumber',
      if (waiter.isNotEmpty) 'staffName': waiter,
      if (items.isNotEmpty) 'items': items,
    };
  }
}

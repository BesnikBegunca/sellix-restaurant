import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/sellix_license.dart';
import 'activation_service.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'database_service.dart';
import 'license_gate_service.dart';

/// Pushes closed / printed gjendja rows to SelliX web.
class PortalShiftsSyncService {
  PortalShiftsSyncService._();
  static final PortalShiftsSyncService instance = PortalShiftsSyncService._();

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
      var batches = 0;
      do {
        _queued = false;
        final pushed = await _pushPending();
        if (pushed && ++batches < 20) _queued = true;
      } while (_queued);
    } finally {
      _syncing = false;
    }
  }

  /// Returns true when a batch was accepted and more rows may remain.
  Future<bool> _pushPending() async {
    if (!ActivationService.instance.isActivated) return false;
    if (LicenseGateService.instance.isBlocked) return false;
    if (!ConnectivityService.instance.isOnline) return false;

    final key = await ActivationService.instance.storedLicenseKey();
    if (key == null || !isSellixLicenseKey(key)) return false;

    final deviceId = await DatabaseService.instance.syncDeviceId();
    final pending = await DatabaseService.instance.fetchUnsyncedPortalShifts(
      limit: _batchLimit,
    );
    if (pending.isEmpty) return false;

    final payload = <Map<String, dynamic>>[];
    for (final row in pending) {
      final mapped = _mapShift(row);
      if (mapped != null) payload.add(mapped);
    }
    if (payload.isEmpty) return false;

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        kEndpointShiftsSync,
        data: {
          'licenseKey': normalizeSellixLicenseKey(key),
          'deviceId': deviceId,
          'shifts': payload,
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
            'PortalShiftsSync: rejected status=${response.statusCode} '
            'reason=${data?['reason']}',
          );
        }
        return false;
      }

      final acceptedUids = payload
          .map((e) => e['eventUid'] as String)
          .toList();
      await DatabaseService.instance.markPortalShiftsSynced(acceptedUids);
      if (kDebugMode) {
        debugPrint('PortalShiftsSync: accepted=${acceptedUids.length}');
      }
      return pending.length >= _batchLimit;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('PortalShiftsSync: network/error $e');
      }
      return false;
    }
  }

  Map<String, dynamic>? _mapShift(Map<String, dynamic> row) {
    final uuid = (row['uuid'] as String?)?.trim() ?? '';
    if (uuid.isEmpty) return null;

    final kind = (row['kind'] as String?)?.trim() == 'printed' ? 'printed' : 'closed';
    final opened = parseStoredSaleTimestamp(row['openedAt'] as String?);
    final eventRaw = (row['eventAt'] as String?) ?? (row['closedAt'] as String?);
    final eventAt = parseStoredSaleTimestamp(eventRaw);
    if (opened == null || eventAt == null) return null;

    final snapshot = _waitersFromSnapshot(row['snapshotJson'] as String?);
    final total = (row['totalSales'] as num?)?.toDouble() ??
        (snapshot['grandTotal'] as num?)?.toDouble() ??
        0;
    final shiftUidRaw = (row['shiftUuid'] as String?)?.trim() ?? '';
    final closedBy = (row['closedBy'] as String?)?.trim() ?? '';
    final waiters = snapshot['waiters'];
    return {
      'eventUid': uuid,
      'shiftUid': shiftUidRaw.isNotEmpty ? shiftUidRaw : uuid,
      'kind': kind,
      'openedAt': toShopLocalSoldAt(opened),
      'closedAt': toShopLocalSoldAt(eventAt),
      'total': total,
      'paid': (row['paidTotal'] as num?)?.toDouble() ??
          (snapshot['grandPaid'] as num?)?.toDouble() ??
          0,
      'open': (row['openTotal'] as num?)?.toDouble() ??
          (snapshot['grandOpen'] as num?)?.toDouble() ??
          0,
      'expenses': (row['totalExpenses'] as num?)?.toDouble() ?? 0,
      if (closedBy.isNotEmpty) 'closedBy': closedBy,
      if (waiters is List && waiters.isNotEmpty) 'waiters': waiters,
    };
  }

  Map<String, dynamic> _waitersFromSnapshot(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final byWaiter = decoded['byWaiter'];
      final waiters = <Map<String, dynamic>>[];
      if (byWaiter is Map) {
        for (final entry in byWaiter.entries) {
          final w = entry.value;
          final map = w is Map ? Map<String, dynamic>.from(w) : <String, dynamic>{};
          waiters.add({
            'name': entry.key.toString(),
            'total': map['grandTotal'] ?? 0,
            'paid': map['paidTotal'] ?? 0,
            'open': map['openTotal'] ?? 0,
          });
        }
      }
      return {
        'waiters': waiters,
        'grandPaid': decoded['grandPaid'],
        'grandOpen': decoded['grandOpen'],
        'grandTotal': decoded['grandTotal'],
      };
    } catch (_) {
      return {};
    }
  }
}

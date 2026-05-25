import 'dart:convert';

/// Maps local outbox rows to pos_api [SyncPushEventDto] shape.
class SyncPushPayloadMapper {
  SyncPushPayloadMapper._();

  /// [payload] must already be normalized via [mapPayload] when needed.
  static Map<String, dynamic> buildEvent({
    required Map<String, dynamic> row,
    required Map<String, dynamic> payload,
  }) {
    return <String, dynamic>{
      'uuid': row['uuid'],
      'entityType': row['entityType'],
      'entityUuid': row['entityUuid'],
      'operation': row['operation'],
      'payload': payload,
    };
  }

  static Map<String, dynamic> decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Map<String, dynamic> mapPayload(
    String entityType,
    Map<String, dynamic> payload,
  ) {
    final normalized = entityType.replaceAll('-', '_');
    return switch (normalized) {
      'sale_lines' => _mapSaleLinePayload(payload),
      'sales' => _mapSalesPayload(payload),
      'sale_adjustments' => _mapSaleAdjustmentPayload(payload),
      'printed_orders' => _mapPrintedOrdersPayload(payload),
      'products' => _mapProductPayload(payload),
      _ => payload,
    };
  }

  static Map<String, dynamic> _mapSalesPayload(Map<String, dynamic> payload) {
    final out = Map<String, dynamic>.from(payload);
    _applySoldAtUtc(out);
    _normalizeSalesOrderMetadata(out);
    final status = out['status'];
    if (status == null || status.toString().isEmpty) {
      out['status'] = 'completed';
    }
    // ignore: avoid_print
    print(
      '[TimezoneFix] payloadSoldAt=${out['soldAt']} '
      'timestamp=${out['timestamp']} createdAt=${out['createdAt']}',
    );
    return out;
  }

  /// Ensures [soldAt] is UTC ISO-8601 (`…Z`) for pos_api / mobile dashboards.
  static void _applySoldAtUtc(Map<String, dynamic> out) {
    final existing = out['soldAt'];
    if (existing != null && existing.toString().trim().isNotEmpty) {
      final raw = existing.toString().trim();
      if (raw.endsWith('Z')) return;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        out['soldAt'] = parsed.toUtc().toIso8601String();
      }
      return;
    }

    final ts = out['timestamp'] ?? out['createdAt'];
    if (ts == null) return;
    final parsed = DateTime.tryParse(ts.toString());
    if (parsed != null) {
      out['soldAt'] = parsed.toUtc().toIso8601String();
    }
  }

  static Map<String, dynamic> _mapSaleLinePayload(Map<String, dynamic> payload) {
    // TEMP [SyncDiag] — log raw payload fields before stripping.
    // ignore: avoid_print
    print(
      '[SyncDiag] _mapSaleLinePayload input: '
      'keys=${payload.keys.toList()} '
      'saleUuid=${payload['saleUuid']} '
      'price=${payload['price'] ?? payload['productPrice']} '
      'qty=${payload['quantity']} '
      'lineTotal=${payload['lineTotal']} '
      'name=${payload['name'] ?? payload['productName']}',
    );

    final out = <String, dynamic>{};

    final saleUuid = payload['saleUuid'];
    if (saleUuid is String && saleUuid.trim().isNotEmpty) {
      out['saleUuid'] = saleUuid.trim();
    }

    final price = payload['price'] ?? payload['productPrice'];
    if (price != null) out['price'] = price;

    final quantity = payload['quantity'];
    if (quantity != null) out['quantity'] = quantity;

    final lineTotal = payload['lineTotal'];
    if (lineTotal != null) out['lineTotal'] = lineTotal;

    final name = payload['name'] ?? payload['productName'];
    if (name != null) out['name'] = name;

    // Order metadata belongs on sales only (not sent); strip if present on lines.
    out.remove('tableId');
    out.remove('table_id');
    out.remove('tableName');
    out.remove('table_name');
    out.remove('waiterName');
    out.remove('waiter_name');

    final saleUuidOut = out['saleUuid'];
    final saleUuidIsUuid = saleUuidOut is String &&
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(saleUuidOut);
    // ignore: avoid_print
    print(
      '[SyncDiag] _mapSaleLinePayload output: '
      'keys=${out.keys.toList()} '
      'saleUuidPresent=${out.containsKey('saleUuid')} '
      'saleUuidIsUuid=$saleUuidIsUuid',
    );

    return out;
  }

  static Map<String, dynamic> _mapSaleAdjustmentPayload(
    Map<String, dynamic> payload,
  ) {
    final out = Map<String, dynamic>.from(payload);
    if (out['type'] == null && out['adjustmentType'] != null) {
      out['type'] = out['adjustmentType'];
    }
    return out;
  }

  static Map<String, dynamic> _mapPrintedOrdersPayload(
    Map<String, dynamic> payload,
  ) {
    final out = <String, dynamic>{};

    final uuid = payload['uuid'];
    if (uuid is String && uuid.trim().isNotEmpty) {
      out['uuid'] = uuid.trim();
    }

    final orderNumber = payload['orderNumber'] ?? payload['order_number'];
    if (orderNumber is num && orderNumber > 0) {
      out['orderNumber'] = orderNumber.toInt();
    }

    final tableId = payload['tableId'] ?? payload['table_id'];
    if (tableId != null) {
      out['tableId'] = tableId is num ? tableId.toInt() : tableId;
    }

    final tableName = payload['tableName'] ?? payload['table_name'];
    if (tableName != null && tableName.toString().trim().isNotEmpty) {
      out['tableName'] = tableName.toString().trim();
    }

    final waiterName = payload['waiterName'] ?? payload['waiter_name'];
    if (waiterName != null && waiterName.toString().trim().isNotEmpty) {
      out['waiterName'] = waiterName.toString().trim();
    }

    final total = payload['total'];
    if (total != null) out['total'] = total;

    final itemsCount = payload['itemsCount'] ?? payload['items_count'];
    if (itemsCount != null) out['itemsCount'] = itemsCount;

    final status = payload['status'];
    if (status != null && status.toString().isNotEmpty) {
      out['status'] = status.toString();
    } else if (!_isPrintedOrderPaidLifecycleUpdate(payload)) {
      out['status'] = 'printed';
    }

    final printedAt = payload['printedAt'] ?? payload['printed_at'];
    if (printedAt != null && printedAt.toString().trim().isNotEmpty) {
      final raw = printedAt.toString().trim();
      if (raw.endsWith('Z')) {
        out['printedAt'] = raw;
      } else {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          out['printedAt'] = parsed.toUtc().toIso8601String();
        } else {
          out['printedAt'] = raw;
        }
      }
    }

    final saleUuid = payload['saleUuid'] ?? payload['sale_uuid'];
    if (saleUuid is String && saleUuid.trim().isNotEmpty) {
      out['saleUuid'] = saleUuid.trim();
    }

    return out;
  }

  /// Paid transition uses uuid + status + saleUuid only (no second row).
  static bool _isPrintedOrderPaidLifecycleUpdate(Map<String, dynamic> payload) {
    final status = payload['status']?.toString();
    final saleUuid = payload['saleUuid'] ?? payload['sale_uuid'];
    if (status != 'paid' || saleUuid == null) return false;
    return payload['orderNumber'] == null &&
        payload['order_number'] == null &&
        payload['tableId'] == null &&
        payload['table_id'] == null;
  }

  static Map<String, dynamic> _mapProductPayload(Map<String, dynamic> payload) {
    final out = Map<String, dynamic>.from(payload);
    if (out['categoryUuid'] == null && out['categoryId'] != null) {
      final categoryId = out['categoryId'];
      if (categoryId is String && _looksLikeUuid(categoryId)) {
        out['categoryUuid'] = categoryId;
      }
    }
    return out;
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _looksLikeUuid(String value) =>
      _uuidPattern.hasMatch(value.trim());

  /// Canonicalizes order metadata field names for pos_api (preserves values).
  static void _normalizeSalesOrderMetadata(Map<String, dynamic> out) {
    _copyAlias(out, 'waiterName', 'waiter_name');
    _copyAlias(out, 'tableName', 'table_name');
    _copyAlias(out, 'orderNumber', 'order_number');

    final tableId = out['tableId'] ?? out['table_id'];
    if (tableId != null && tableId.toString().trim().isNotEmpty) {
      out['tableId'] = tableId is num ? tableId.toInt() : tableId;
      out.remove('table_id');
    }

    final orderNumber = out['orderNumber'];
    if (orderNumber is num && orderNumber > 0) {
      out['orderNumber'] = orderNumber.toInt();
    }
  }

  static void _copyAlias(
    Map<String, dynamic> out,
    String canonical,
    String alias,
  ) {
    final current = out[canonical];
    if (current != null && current.toString().trim().isNotEmpty) {
      out.remove(alias);
      return;
    }
    final fromAlias = out[alias];
    if (fromAlias != null && fromAlias.toString().trim().isNotEmpty) {
      out[canonical] = fromAlias;
    }
    out.remove(alias);
  }
}

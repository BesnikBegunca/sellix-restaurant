import 'package:flutter/material.dart';

import 'mock_data.dart';

// ─────────────────────────────── models ───────────────────────────────────────

/// Expense / salary row persisted in the [expenses] SQLite table.
class ExpenseRow {
  ExpenseRow({
    this.dbId,
    required this.type,
    required this.description,
    required this.amount,
    DateTime? date,
    this.shiftId,
  }) : date = date ?? DateTime.now();

  /// Primary key from SQLite — null until after first DB insert.
  final int? dbId;

  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final int? shiftId;

  factory ExpenseRow.fromMap(Map<String, dynamic> m) => ExpenseRow(
    dbId: m['id'] as int?,
    type: m['type'] as String,
    description: m['description'] as String,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.parse(m['timestamp'] as String),
    shiftId: m['shiftId'] as int?,
  );
}

/// Archived shift record from the [shifts] SQLite table.
class ShiftRecord {
  const ShiftRecord({
    required this.id,
    required this.openedAt,
    this.closedAt,
    this.openedBy,
    this.closedBy,
    this.openingCash = 0,
    this.closingCash,
    required this.totalSales,
    required this.totalExpenses,
    required this.netProfit,
    required this.status,
  });

  final int id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? openedBy;
  final String? closedBy;
  final double openingCash;
  final double? closingCash;
  final double totalSales;
  final double totalExpenses;
  final double netProfit;
  final String status;

  bool get isOpen => status == 'open';

  factory ShiftRecord.fromMap(Map<String, dynamic> m) => ShiftRecord(
    id: (m['id'] as num).toInt(),
    openedAt: DateTime.parse(m['openedAt'] as String),
    closedAt: m['closedAt'] != null
        ? DateTime.tryParse(m['closedAt'] as String)
        : null,
    openedBy: m['openedBy'] as String?,
    closedBy: m['closedBy'] as String?,
    openingCash: (m['openingCash'] as num?)?.toDouble() ?? 0,
    closingCash: (m['closingCash'] as num?)?.toDouble(),
    totalSales: (m['totalSales'] as num?)?.toDouble() ?? 0,
    totalExpenses: (m['totalExpenses'] as num?)?.toDouble() ?? 0,
    netProfit: (m['netProfit'] as num?)?.toDouble() ?? 0,
    status: m['status'] as String? ?? 'open',
  );
}

/// A refund, void, or discount recorded against a sale, in [sale_adjustments].
class SaleAdjustmentRow {
  const SaleAdjustmentRow({
    required this.id,
    required this.saleId,
    this.saleLineId,
    required this.adjustmentType,
    this.productName,
    this.quantity,
    required this.amount,
    this.reason,
    this.createdBy,
    required this.createdAt,
  });

  final int id;
  final int saleId;
  final int? saleLineId;
  final String adjustmentType;
  final String? productName;
  final int? quantity;
  final double amount;
  final String? reason;
  final String? createdBy;
  final DateTime createdAt;

  factory SaleAdjustmentRow.fromMap(Map<String, dynamic> m) =>
      SaleAdjustmentRow(
        id: (m['id'] as num).toInt(),
        saleId: (m['saleId'] as num).toInt(),
        saleLineId: m['saleLineId'] != null
            ? (m['saleLineId'] as num).toInt()
            : null,
        adjustmentType: m['adjustmentType'] as String,
        productName: m['productName'] as String?,
        quantity: m['quantity'] != null ? (m['quantity'] as num).toInt() : null,
        amount: (m['amount'] as num).toDouble(),
        reason: m['reason'] as String?,
        createdBy: m['createdBy'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

/// Immutable snapshot of one ordered product, persisted in [sale_lines].
///
/// All fields are copied at payment time — future edits to the product
/// catalogue never alter historical records.
class SaleLineRow {
  const SaleLineRow({
    this.dbId,
    required this.saleId,
    this.productId,
    required this.productName,
    required this.productEmoji,
    this.productImagePath,
    required this.productPrice,
    required this.quantity,
    required this.lineTotal,
    this.categoryName,
    this.tableName,
    this.waiterName,
    required this.createdAt,
  });

  final int? dbId;
  final int saleId;
  final String? productId;
  final String productName;
  final String productEmoji;
  final String? productImagePath;
  final double productPrice;
  final int quantity;
  final double lineTotal;
  final String? categoryName;
  final String? tableName;
  final String? waiterName;
  final DateTime createdAt;

  factory SaleLineRow.fromMap(Map<String, dynamic> m) => SaleLineRow(
    dbId: m['id'] as int?,
    saleId: (m['saleId'] as num).toInt(),
    productId: m['productId'] as String?,
    productName: m['productName'] as String,
    productEmoji: m['productEmoji'] as String? ?? '☕',
    productImagePath: m['productImagePath'] as String?,
    productPrice: (m['productPrice'] as num).toDouble(),
    quantity: (m['quantity'] as num).toInt(),
    lineTotal: (m['lineTotal'] as num).toDouble(),
    categoryName: m['categoryName'] as String?,
    tableName: m['tableName'] as String?,
    waiterName: m['waiterName'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}

/// Single completed sale, persisted in the [sales] SQLite table.
class SaleRow {
  const SaleRow({
    this.dbId,
    required this.waiterName,
    required this.tableId,
    required this.total,
    required this.timestamp,
    this.shiftId,
    this.orderNumber,
    this.tableName,
  });

  final int? dbId;
  final String waiterName;
  final int tableId;
  final double total;
  final DateTime timestamp;
  final int? shiftId;
  final int? orderNumber;
  final String? tableName;

  factory SaleRow.fromMap(Map<String, dynamic> m) => SaleRow(
    dbId: m['id'] as int?,
    waiterName: m['waiterName'] as String,
    tableId: m['tableId'] as int,
    total: (m['total'] as num).toDouble(),
    timestamp: DateTime.parse(m['timestamp'] as String),
    shiftId: m['shiftId'] as int?,
    orderNumber: (m['orderNumber'] as num?)?.toInt(),
    tableName: m['tableName'] as String?,
  );
}

/// Shifra për një kamarier: shitje të paguara (në shift) + porosi të hapura në tavolina.
@immutable
class ShiftWorkerBreakdown {
  const ShiftWorkerBreakdown({
    required this.paidTotal,
    required this.openTotal,
    required this.paidOrderCount,
    required this.openOrderCount,
  });

  final double paidTotal;
  final double openTotal;
  final int paidOrderCount;
  final int openOrderCount;

  double get grandTotal => paidTotal + openTotal;

  Map<String, dynamic> toJson() => {
        'paidTotal': paidTotal,
        'openTotal': openTotal,
        'paidOrderCount': paidOrderCount,
        'openOrderCount': openOrderCount,
        'grandTotal': grandTotal,
      };
}

/// Raport i gjendjes për shift-in aktiv (print live ose snapshot para mbylljes).
@immutable
class ShiftStatusReport {
  const ShiftStatusReport({
    required this.shiftId,
    required this.generatedAt,
    required this.byWaiter,
  });

  final int? shiftId;
  final DateTime generatedAt;
  final Map<String, ShiftWorkerBreakdown> byWaiter;

  double get grandPaid =>
      byWaiter.values.fold<double>(0, (s, w) => s + w.paidTotal);

  double get grandOpen =>
      byWaiter.values.fold<double>(0, (s, w) => s + w.openTotal);

  double get grandTotal => grandPaid + grandOpen;

  /// Totali i përgjithshëm për kamarier (për printer / kolonë e njëtë).
  Map<String, double> waiterGrandTotalsForPrint() => {
        for (final e in byWaiter.entries) e.key: e.value.grandTotal,
      };

  Map<String, dynamic> toJson() => {
        'shiftId': shiftId,
        'generatedAt': generatedAt.toIso8601String(),
        'byWaiter': {
          for (final e in byWaiter.entries) e.key: e.value.toJson(),
        },
        'grandPaid': grandPaid,
        'grandOpen': grandOpen,
        'grandTotal': grandTotal,
      };
}

/// Advance (avans) given to a waiter, persisted in the [advances] SQLite table.
class AdvanceRow {
  AdvanceRow({
    this.dbId,
    required this.waiterName,
    required this.amount,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final int? dbId;
  final String waiterName;
  final double amount;
  final String note;
  final DateTime date;

  factory AdvanceRow.fromMap(Map<String, dynamic> m) => AdvanceRow(
    dbId: m['id'] as int?,
    waiterName: m['waiterName'] as String,
    amount: (m['amount'] as num).toDouble(),
    note: m['note'] as String? ?? '',
    date: DateTime.parse(m['timestamp'] as String),
  );
}

/// Waiter with name and hashed PIN, persisted in the [waiters] SQLite table.
class WaiterInfo {
  WaiterInfo({
    this.dbId,
    required this.name,
    this.pin = '',
    this.pinHash,
    this.pinSalt,
    this.pinUpdatedAt,
  });

  /// Primary key from SQLite — null until after first DB insert.
  final int? dbId;

  final String name;

  /// Legacy column kept for DB backward compatibility.
  /// Verification always uses [pinHash] + [pinSalt] when available.
  final String pin;

  final String? pinHash;
  final String? pinSalt;
  final String? pinUpdatedAt;

  /// True once a hashed PIN has been stored for this waiter.
  bool get isHashed => pinHash != null && pinSalt != null;

  factory WaiterInfo.fromMap(Map<String, dynamic> m) => WaiterInfo(
    dbId: m['id'] as int?,
    name: m['name'] as String,
    pin: (m['pin'] as String?) ?? '',
    pinHash: m['pinHash'] as String?,
    pinSalt: m['pinSalt'] as String?,
    pinUpdatedAt: m['pinUpdatedAt'] as String?,
  );
}

class CurrentOrderLine {
  const CurrentOrderLine({required this.product, required this.qty});

  final ProductItem product;
  final int qty;
}

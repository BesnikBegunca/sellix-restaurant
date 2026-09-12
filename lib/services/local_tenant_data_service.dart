import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../manager/manager_data.dart';
import '../models/open_tables_summary.dart';
import '../models/tenant_activation_gate_result.dart';
import '../models/tenant_data_conflict.dart';
import '../widgets/tenant_data_conflict_dialog.dart';
import 'database_schema.dart';
import 'database_service.dart';
import '../l10n/tr.dart';

/// Detects and clears local SQLite business data when the activated tenant changes.
class LocalTenantDataService {
  LocalTenantDataService._();
  static final LocalTenantDataService instance = LocalTenantDataService._();

  static const String kLastBusinessIdKey = 'activation_last_business_id';
  static const String kLastBusinessNameKey = 'activation_last_business_name';

  /// Production/release builds require wipe before activating a new business.
  static bool get isMandatoryWipeEnforced => kReleaseMode;

  /// Returns a conflict descriptor when local data may belong to another tenant.
  Future<TenantDataConflict?> detectConflict(String newBusinessId) async {
    if (newBusinessId.isEmpty) return null;

    final db = DatabaseService.instance;
    final previousId = await db.getAppMeta(kLastBusinessIdKey);
    final previousName = await db.getAppMeta(kLastBusinessNameKey);
    final hasForeign = await db.hasLocalDataForOtherBusiness(newBusinessId);
    final hasData = await db.hasMeaningfulLocalBusinessData();

    final differentPrevious =
        previousId != null &&
        previousId.isNotEmpty &&
        previousId != newBusinessId;

    final placeholderData =
        newBusinessId != DatabaseSchema.kLocalBusinessId &&
        await db.hasLocalDataForBusiness(DatabaseSchema.kLocalBusinessId);

    // Business change always requires a gate (wipe mandatory in release).
    if (differentPrevious) {
      return TenantDataConflict(
        newBusinessId: newBusinessId,
        previousBusinessId: previousId,
        previousBusinessName: previousName,
        hasMeaningfulLocalData: hasData,
        hasForeignScopedData: hasForeign || placeholderData,
        wipeRequired: true,
      );
    }

    if (!hasForeign && !placeholderData) return null;
    if (!hasData && !hasForeign && !placeholderData) return null;

    return TenantDataConflict(
      newBusinessId: newBusinessId,
      previousBusinessId: previousId,
      previousBusinessName: previousName,
      hasMeaningfulLocalData: hasData,
      hasForeignScopedData: hasForeign || placeholderData,
      wipeRequired: isMandatoryWipeEnforced,
    );
  }

  /// Shows conflict UI (if needed), wipes when required, and returns whether
  /// activation may continue.
  ///
  /// In release mode, activation cannot proceed without a successful wipe when
  /// [detectConflict] returns non-null.
  Future<TenantActivationGateResult> prepareForActivation({
    required BuildContext context,
    required String newBusinessId,
    bool forceAfterSafeClose = false,
  }) async {
    final conflict = await detectConflict(newBusinessId);
    if (conflict == null) {
      return TenantActivationGateResult.noConflict();
    }

    TenantConflictDialogChoice? choice;
    if (forceAfterSafeClose) {
      choice = TenantConflictDialogChoice.wipeAndContinue;
    } else {
      if (!context.mounted) {
        return TenantActivationGateResult.cancelled(conflict);
      }
      choice = await showTenantDataConflictDialog(context, conflict);
    }

    if (choice == null || choice == TenantConflictDialogChoice.cancelled) {
      return TenantActivationGateResult.cancelled(conflict);
    }

    if (choice == TenantConflictDialogChoice.keepLocalDebugOnly) {
      if (isMandatoryWipeEnforced) {
        if (kDebugMode) {
          debugPrint(
            'LocalTenantDataService: blocked keep-local in release mode',
          );
        }
        return TenantActivationGateResult.cancelled(conflict);
      }
      return TenantActivationGateResult.keepLocalDebugOnly(conflict);
    }

    // wipeAndContinue
    if (!forceAfterSafeClose &&
        await DatabaseService.instance.hasAnyOpenTableBusiness()) {
      final summary = await DatabaseService.instance.getOpenTablesSummary();
      return TenantActivationGateResult.openTablesBlocked(conflict, summary);
    }

    try {
      await clearLocalBusinessData(skipOpenTableCheck: forceAfterSafeClose);
      return TenantActivationGateResult.wipeCompleted(conflict);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('LocalTenantDataService: wipe failed: $e\n$st');
      }
      return TenantActivationGateResult.wipeFailed(conflict, e);
    }
  }

  /// Closes open tables preserving totals — see [DatabaseService.closeOpenTablesSafely].
  Future<void> closeOpenTablesSafely() async {
    await DatabaseService.instance.closeOpenTablesSafely();
    await ManagerData.instance.reload();
  }

  /// Summary for the activation open-tables dialog.
  Future<OpenTablesSummary> getOpenTablesSummary() =>
      DatabaseService.instance.getOpenTablesSummary();

  /// Wipes tenant-owned SQLite tables; preserves printer/company settings and
  /// immutable [audit_logs].
  Future<void> clearLocalBusinessData({bool skipOpenTableCheck = false}) async {
    await DatabaseService.instance.clearLocalBusinessData(
      skipOpenTableCheck: skipOpenTableCheck,
    );
    await ManagerData.instance.reload();
  }

  Future<void> recordActivatedTenant({
    required String businessId,
    String? businessName,
  }) async {
    final db = DatabaseService.instance;
    await db.setAppMeta(kLastBusinessIdKey, businessId);
    if (businessName != null && businessName.isNotEmpty) {
      await db.setAppMeta(kLastBusinessNameKey, businessName);
    }
  }

  /// True when activated tenant does not match rows still stored locally.
  Future<bool> localDataMayBeFromPreviousTenant() async {
    final activeId = await DatabaseService.instance.getAppMeta(
      'activation_business_id',
    );
    if (activeId == null || activeId.isEmpty) return false;
    return DatabaseService.instance.hasLocalDataForOtherBusiness(activeId);
  }

  /// Last business id stored after a successful activation (for diagnostics).
  Future<String?> lastActivatedBusinessId() =>
      DatabaseService.instance.getAppMeta(kLastBusinessIdKey);

  Future<String?> lastActivatedBusinessName() =>
      DatabaseService.instance.getAppMeta(kLastBusinessNameKey);

  /// Human-readable tenant isolation status for Sync Diagnostics.
  Future<String> diagnosticsTenantPolicyLabel() async {
    final lastId = await lastActivatedBusinessId();
    final activeId = await DatabaseService.instance.getAppMeta(
      'activation_business_id',
    );
    final foreign = activeId != null &&
        activeId.isNotEmpty &&
        await localDataMayBeFromPreviousTenant();

    if (foreign) {
      return tr.dhenaBiznesTjeterSqlite;
    }
    if (lastId != null &&
        activeId != null &&
        lastId.isNotEmpty &&
        activeId.isNotEmpty &&
        lastId != activeId) {
      return 'Biznesi aktiv ≠ biznesi i fundit lokal';
    }
    if (isMandatoryWipeEnforced) {
      return tr.pastrimDetyrueshemNdryshimBiznesiRelease;
    }
    return tr.pastrimOpsionalDebug;
  }
}

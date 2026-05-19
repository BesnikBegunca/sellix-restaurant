import '../manager/manager_data.dart';
import '../models/tenant_data_conflict.dart';
import 'database_schema.dart';
import 'database_service.dart';

/// Detects and clears local SQLite business data when the activated tenant changes.
class LocalTenantDataService {
  LocalTenantDataService._();
  static final LocalTenantDataService instance = LocalTenantDataService._();

  static const String kLastBusinessIdKey = 'activation_last_business_id';
  static const String kLastBusinessNameKey = 'activation_last_business_name';

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

    if (!differentPrevious && !hasForeign && !placeholderData) return null;
    if (!hasData && !hasForeign && !placeholderData) return null;

    return TenantDataConflict(
      newBusinessId: newBusinessId,
      previousBusinessId: previousId,
      previousBusinessName: previousName,
      hasMeaningfulLocalData: hasData,
      hasForeignScopedData: hasForeign || placeholderData,
    );
  }

  /// Wipes tenant-owned SQLite tables; preserves printer/company settings.
  Future<void> clearLocalBusinessData() async {
    await DatabaseService.instance.clearLocalBusinessData();
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

  Future<String?> lastActivatedBusinessName() =>
      DatabaseService.instance.getAppMeta(kLastBusinessNameKey);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/models/open_tables_summary.dart';
import 'package:pos_system/models/tenant_activation_gate_result.dart';
import 'package:pos_system/models/tenant_data_conflict.dart';
import 'package:pos_system/services/database_schema.dart';
import 'package:pos_system/services/local_tenant_data_service.dart';

void main() {
  group('TenantActivationGateResult', () {
    test('noConflict allows activation', () {
      expect(TenantActivationGateResult.noConflict().canProceedToActivation, isTrue);
    });

    test('wipeCompleted allows activation', () {
      const conflict = TenantDataConflict(
        newBusinessId: 'b2',
        previousBusinessId: 'b1',
        hasMeaningfulLocalData: true,
        hasForeignScopedData: true,
        wipeRequired: true,
      );
      expect(
        TenantActivationGateResult.wipeCompleted(conflict).canProceedToActivation,
        isTrue,
      );
    });

    test('cancelled blocks activation', () {
      const conflict = TenantDataConflict(
        newBusinessId: 'b2',
        hasMeaningfulLocalData: false,
        hasForeignScopedData: false,
      );
      expect(
        TenantActivationGateResult.cancelled(conflict).canProceedToActivation,
        isFalse,
      );
    });

    test('wipeFailed blocks activation', () {
      const conflict = TenantDataConflict(
        newBusinessId: 'b2',
        hasMeaningfulLocalData: true,
        hasForeignScopedData: false,
      );
      expect(
        TenantActivationGateResult.wipeFailed(conflict, 'err')
            .canProceedToActivation,
        isFalse,
      );
    });

    test('openTablesBlocked blocks activation', () {
      const conflict = TenantDataConflict(
        newBusinessId: 'b2',
        hasMeaningfulLocalData: true,
        hasForeignScopedData: true,
      );
      expect(
        TenantActivationGateResult.openTablesBlocked(
          conflict,
          const OpenTablesSummary(count: 1, totalAmount: 10),
        ).canProceedToActivation,
        isFalse,
      );
    });
  });

  group('tenant wipe schema', () {
    test('tenant reset does not delete audit_logs', () {
      expect(DatabaseSchema.tenantResetTables, isNot(contains('audit_logs')));
    });

    test('foreign-data check excludes audit_logs', () {
      expect(
        DatabaseSchema.tenantForeignDataCheckTables,
        isNot(contains('audit_logs')),
      );
    });
  });

  group('isMandatoryWipeEnforced', () {
    test('matches kReleaseMode in tests', () {
      // flutter test runs in debug profile — enforced is false here.
      expect(LocalTenantDataService.isMandatoryWipeEnforced, false);
    });
  });
}

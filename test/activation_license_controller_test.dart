import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/services/activation_license_controller.dart';
import 'package:pos_system/services/database_service.dart';
import 'package:pos_system/services/license_gate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.instance.database;
    await ActivationLicenseController.instance.setExpiresAt(null);
    await DatabaseService.instance.setAppMeta(
      LicenseGateService.kLicenseExpiresAtMeta,
      '',
    );
    ActivationLicenseController.instance.clearInMemory();
  });

  test('setExpiresAt notifies listeners and updates daysRemaining', () async {
  final past = DateTime.now().add(const Duration(days: 3));
  var notified = 0;
  void listener() => notified++;
  ActivationLicenseController.instance.addListener(listener);

  await ActivationLicenseController.instance.setExpiresAt(
    past.toUtc().toIso8601String(),
  );

  expect(notified, greaterThan(0));
  expect(ActivationLicenseController.instance.daysRemaining, 3);

  final renewed = DateTime.now().add(const Duration(days: 90));
  await ActivationLicenseController.instance.setExpiresAt(
    renewed.toUtc().toIso8601String(),
  );

  expect(ActivationLicenseController.instance.daysRemaining, 90);
  ActivationLicenseController.instance.removeListener(listener);
  });

  test('reloadFromStorage picks up app_meta changes', () async {
    final future = DateTime.now().add(const Duration(days: 14));
    await DatabaseService.instance.setAppMeta(
      LicenseGateService.kLicenseExpiresAtMeta,
      future.toUtc().toIso8601String(),
    );
    ActivationLicenseController.instance.clearInMemory();

    await ActivationLicenseController.instance.reloadFromStorage();
    expect(ActivationLicenseController.instance.daysRemaining, 14);
  });
}

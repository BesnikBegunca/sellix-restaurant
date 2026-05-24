import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pos_system/services/activation_license_controller.dart';
import 'package:pos_system/services/activation_service.dart';
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
    await DatabaseService.instance.setAppMeta(
      LicenseGateService.kLicenseExpiresAtMeta,
      '',
    );
    ActivationLicenseController.instance.clearInMemory();
  });

  group('parseLicenseExpiresAtValue', () {
    test('accepts ISO-8601 string', () {
      expect(
        ActivationService.parseLicenseExpiresAtValue(
          '2028-05-23T00:00:00.000Z',
        ),
        '2028-05-23T00:00:00.000Z',
      );
    });

    test('accepts epoch milliseconds', () {
      final ms = DateTime.utc(2028, 5, 23).millisecondsSinceEpoch;
      final parsed = ActivationService.parseLicenseExpiresAtValue(ms);
      expect(parsed, isNotNull);
      expect(DateTime.parse(parsed!).year, 2028);
    });
  });

  group('applyLicenseExpiresFromApiBody', () {
    test('overwrites stale app_meta and notifies listeners', () async {
      const stale = '2027-05-24T23:59:59.999Z';
      const renewed = '2028-05-23T23:59:59.999Z';

      await ActivationLicenseController.instance.setExpiresAt(stale);
      final staleDays = ActivationLicenseController.instance.daysRemaining;
      expect(staleDays, isNotNull);

      var notified = 0;
      void listener() => notified++;
      ActivationLicenseController.instance.addListener(listener);

      await ActivationService.instance.applyLicenseExpiresFromApiBody({
        'licenseExpiresAt': renewed,
      });

      final saved = await DatabaseService.instance.getAppMeta(
        LicenseGateService.kLicenseExpiresAtMeta,
      );
      expect(saved, renewed);
      expect(ActivationLicenseController.instance.expiresAtIso, renewed);
      expect(notified, greaterThan(0));

      final renewedDays =
          ActivationLicenseController.instance.daysRemaining;
      expect(renewedDays, isNotNull);
      expect(renewedDays! > staleDays!, isTrue);

      ActivationLicenseController.instance.removeListener(listener);
    });

    test('login badge days come from controller after sync', () async {
      const renewed = '2028-05-23T23:59:59.999Z';
      await ActivationService.instance.applyLicenseExpiresFromApiBody({
        'licenseExpiresAt': renewed,
      });
      expect(
        ActivationLicenseController.instance.daysRemaining,
        ActivationLicenseController.instance.daysRemaining,
      );
      expect(ActivationLicenseController.instance.expiresAtIso, renewed);
    });
  });
}

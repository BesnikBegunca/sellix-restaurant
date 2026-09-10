import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/services/local_license_service.dart';

void main() {
  test('generated license validates offline', () {
    final service = LocalLicenseService.instance;
    final code = service.generateLicense(ownerName: 'Cafe Test', days: 30);

    final license = service.validate(code);

    expect(license, isNotNull);
    expect(license!.ownerName, 'Cafe Test');
    expect(license.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
  });

  test('tampered license is rejected', () {
    final service = LocalLicenseService.instance;
    final code = service.generateLicense(ownerName: 'Cafe Test', days: 30);

    expect(service.validate('${code}x'), isNull);
  });

  test('invalid duration is rejected', () {
    expect(
      () => LocalLicenseService.instance.generateLicense(
        ownerName: 'Cafe Test',
        days: 0,
      ),
      throwsArgumentError,
    );
  });
}

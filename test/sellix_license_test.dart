import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/models/sellix_license.dart';

void main() {
  group('isRestaurantSector', () {
    test('accepts restaurant and table-service sectors', () {
      expect(isRestaurantSector('restaurant'), isTrue);
      expect(isRestaurantSector('Restorant'), isTrue);
      expect(isRestaurantSector('Bar & Grill'), isTrue);
      expect(isRestaurantSector('Kafene'), isTrue);
      expect(isRestaurantSector('Pizzeria'), isTrue);
    });

    test('rejects other shop types', () {
      expect(isRestaurantSector('market'), isFalse);
      expect(isRestaurantSector('boutique'), isFalse);
      expect(isRestaurantSector('pharmacy'), isFalse);
      expect(isRestaurantSector(''), isFalse);
      expect(isRestaurantSector(null), isFalse);
    });
  });

  group('license key helpers', () {
    test('normalizes and detects SLX keys', () {
      expect(
        normalizeSellixLicenseKey(' slx-3k5s2-kjh4d-4dxte-kk6cj '),
        'SLX-3K5S2-KJH4D-4DXTE-KK6CJ',
      );
      expect(isSellixLicenseKey('SLX-3K5S2-KJH4D-4DXTE-KK6CJ'), isTrue);
      expect(isSellixLicenseKey('POS-LOCAL-abc'), isFalse);
    });
  });

  group('soldAt formatting', () {
    test('formats local shop time as YYYY-MM-DD HH:MM:SS', () {
      final stamp = toShopLocalSoldAt(DateTime(2026, 9, 19, 20, 14, 3));
      expect(stamp, '2026-09-19 20:14:03');
    });

    test('parses UTC ISO sale timestamps', () {
      final parsed = parseStoredSaleTimestamp('2026-09-19T18:14:03.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
    });
  });

  group('parseSellixDateTime', () {
    test('accepts SQL datetime as UTC', () {
      expect(
        parseSellixDateTime('2027-09-18 14:08:04'),
        '2027-09-18T14:08:04.000Z',
      );
    });
  });

  test('business JSON round-trip keeps fiscal fields', () {
    const original = SellixBusinessProfile(
      nui: '810123456',
      name: 'Restorant Test',
      fiscalNumber: '600123456',
      vatNumber: '330123456',
      address: 'Rr. Nëna Terezë 12',
      city: 'Prishtinë',
      sector: 'restaurant',
      phone: '044123456',
    );
    final restored = SellixBusinessProfile.fromJson(original.toJson());
    expect(restored.name, 'Restorant Test');
    expect(restored.nui, '810123456');
    expect(restored.sector, 'restaurant');
    expect(isRestaurantSector(restored.sector), isTrue);
  });
}

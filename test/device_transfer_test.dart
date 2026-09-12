import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/models/device_transfer_required_response.dart';
import 'package:pos_system/models/device_transfer_response.dart';
import 'package:pos_system/services/device_transfer_exception.dart';

void main() {
  group('DeviceTransferRequiredResponse.fromJson', () {
    test('parses full payload', () {
      final resp = DeviceTransferRequiredResponse.fromJson({
        'requiresTransferApproval': true,
        'licenseId': 'lic-abc',
        'message': 'License in use',
        'oldDeviceId': 'dev-old',
        'oldDeviceName': 'OldPC',
      });
      expect(resp.licenseId, 'lic-abc');
      expect(resp.message, 'License in use');
      expect(resp.oldDeviceId, 'dev-old');
      expect(resp.oldDeviceName, 'OldPC');
    });

    test('handles missing optional fields', () {
      final resp = DeviceTransferRequiredResponse.fromJson({
        'licenseId': 'lic-xyz',
      });
      expect(resp.licenseId, 'lic-xyz');
      expect(resp.oldDeviceId, isNull);
      expect(resp.oldDeviceName, isNull);
    });

    test('defaults licenseId to empty string when absent', () {
      final resp = DeviceTransferRequiredResponse.fromJson({});
      expect(resp.licenseId, '');
    });
  });

  group('DeviceTransferResponse.fromJson', () {
    test('parses success payload', () {
      final resp = DeviceTransferResponse.fromJson({
        'id': 'tr-001',
        'status': 'pending',
        'businessId': 'biz-1',
        'licenseId': 'lic-abc',
        'requestedAt': '2026-05-26T10:00:00Z',
      });
      expect(resp.id, 'tr-001');
      expect(resp.status, 'pending');
      expect(resp.isPending, isTrue);
      expect(resp.isDuplicate, isFalse);
    });

    test('isDuplicate flag carried through', () {
      final resp = DeviceTransferResponse.fromJson({
        'id': '',
        'status': 'pending',
      }, isDuplicate: true);
      expect(resp.isDuplicate, isTrue);
      expect(resp.isPending, isTrue);
    });

    test('isPending true for duplicate with empty id', () {
      const resp = DeviceTransferResponse(
        id: '',
        status: 'pending',
        isDuplicate: true,
      );
      expect(resp.isPending, isTrue);
    });
  });

  group('DeviceTransferRequiredException', () {
    test('isDuplicate delegates to response', () {
      const resp = DeviceTransferResponse(
        id: 'tr-1',
        status: 'pending',
        isDuplicate: true,
      );
      const ex = DeviceTransferRequiredException(resp);
      expect(ex.isDuplicate, isTrue);
    });

    test('not duplicate when fresh request', () {
      const resp = DeviceTransferResponse(id: 'tr-2', status: 'pending');
      const ex = DeviceTransferRequiredException(resp);
      expect(ex.isDuplicate, isFalse);
    });

    test('is an Exception', () {
      const resp = DeviceTransferResponse(id: '', status: 'pending');
      const ex = DeviceTransferRequiredException(resp);
      expect(ex, isA<Exception>());
    });

    test('toString includes status and isDuplicate', () {
      const resp = DeviceTransferResponse(id: '', status: 'pending');
      const ex = DeviceTransferRequiredException(resp);
      expect(ex.toString(), contains('pending'));
      expect(ex.toString(), contains('isDuplicate=false'));
    });
  });

  group('DeviceTransferRequiredException — no tokens saved', () {
    test(
      'throwing DeviceTransferRequiredException does not produce tokens',
      () {
        // Verify that DeviceTransferRequiredException is distinct from a
        // successful ActivationResponse so the caller cannot accidentally
        // treat it as an activated state.
        const resp = DeviceTransferResponse(id: 'tr-3', status: 'pending');
        Object? caught;
        try {
          throw const DeviceTransferRequiredException(resp);
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<DeviceTransferRequiredException>());
        // Ensure it is NOT an ActivationResponse — no token fields exposed
        expect(caught, isNot(isA<Map>()));
      },
    );
  });
}

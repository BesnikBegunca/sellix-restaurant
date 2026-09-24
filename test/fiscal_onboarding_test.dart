import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_system/services/fiscal/fiscal_onboarding.dart';
import 'package:pos_system/services/fiscal/fiscal_signer.dart';

/// The key and CSR produced in-app must be byte-compatible with ATK's Go CA.
/// These tests check what Dart can check; the openssl cross-check that proves
/// interop is run separately against the files written by the last test.
void main() {
  test('generates a usable P-256 key pair', () {
    final pair = FiscalOnboardingService.generateKeyPair();
    final domain = pair.privateKey.parameters!;
    expect(pair.privateKey.d, isNotNull);
    expect(pair.privateKey.d! > BigInt.zero, isTrue);
    expect(pair.privateKey.d! < domain.n, isTrue);
    // The public key must actually be d·G, not an unrelated point.
    expect(pair.publicKey.Q, (domain.G * pair.privateKey.d!));
  });

  test('the exported PEM round-trips through the signer', () {
    final pair = FiscalOnboardingService.generateKeyPair();
    final pem = FiscalOnboardingService.encodeSec1PrivateKeyPem(pair.privateKey);

    expect(pem, startsWith('-----BEGIN EC PRIVATE KEY-----'));
    expect(pem.trimRight(), endsWith('-----END EC PRIVATE KEY-----'));

    // The signer is what issues real coupons — it must read our own key.
    final parsed = FiscalSigner.parsePrivateKeyPem(pem);
    expect(parsed.d, pair.privateKey.d);

    final signature = FiscalSigner(pem).signBase64Payload('test-payload');
    expect(signature, isNotEmpty);
  });

  test('builds a PEM CSR with the subject ATK prescribes', () {
    final pair = FiscalOnboardingService.generateKeyPair();
    final csr = FiscalOnboardingService.buildCsrPem(
      privateKey: pair.privateKey,
      publicKey: pair.publicKey,
      businessId: 12345678910,
      posId: 1,
      branchId: 2,
      commonName: 'Friends SHPK',
    );
    expect(csr, startsWith('-----BEGIN CERTIFICATE REQUEST-----'));
    expect(csr.trimRight(), endsWith('-----END CERTIFICATE REQUEST-----'));
  });

  test('writes key and CSR for the openssl cross-check', () {
    final pair = FiscalOnboardingService.generateKeyPair();
    final dir = Directory.systemTemp.createTempSync('fiscal_onboard');
    File('${dir.path}/key.pem').writeAsStringSync(
      FiscalOnboardingService.encodeSec1PrivateKeyPem(pair.privateKey),
    );
    File('${dir.path}/csr.pem').writeAsStringSync(
      FiscalOnboardingService.buildCsrPem(
        privateKey: pair.privateKey,
        publicKey: pair.publicKey,
        businessId: 12345678910,
        posId: 1,
        branchId: 2,
        commonName: 'Friends SHPK',
      ),
    );
    // ignore: avoid_print
    print('ONBOARDDIR=${dir.path}');
    expect(File('${dir.path}/csr.pem').existsSync(), isTrue);
  });
}

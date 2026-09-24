import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

import 'package:pos_system/services/fiscal/fiscal_signer.dart';

/// The key pair below was generated with
/// `openssl ecparam -name prime256v1 -genkey`. It exists only for this test.
const _sec1Pem = '''
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIBIRE6WMnPli1D/SVrucTX+w5JPV2BTsE9T6Qm2DBCwPoAoGCCqGSM49
AwEHoUQDQgAE2NQZYHG9O5fAg3e0Dught5JB9RlwfD1fXMld9FvCDp+0GtDJ5lvI
F/GujF6jmnTBeKHZ+YCEcTRIxFz1knY0Tw==
-----END EC PRIVATE KEY-----
''';

const _pkcs8Pem = '''
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgEhETpYyc+WLUP9JW
u5xNf7Dkk9XYFOwT1PpCbYMELA+hRANCAATY1Blgcb07l8CDd7QO6CG3kkH1GXB8
PV9cyV30W8IOn7Qa0MnmW8gX8a6MXqOadMF4odn5gIRxNEjEXPWSdjRP
-----END PRIVATE KEY-----
''';

const _expectedScalarHex =
    '121113a58c9cf962d43fd256bb9c4d7fb0e493d5d814ec13d4fa426d83042c0f';

void main() {
  test('parses a SEC1 "EC PRIVATE KEY" PEM', () {
    final key = FiscalSigner.parsePrivateKeyPem(_sec1Pem);
    expect(key.d!.toRadixString(16).padLeft(64, '0'), _expectedScalarHex);
  });

  test('parses a PKCS#8 "PRIVATE KEY" PEM to the same scalar', () {
    final key = FiscalSigner.parsePrivateKeyPem(_pkcs8Pem);
    expect(key.d!.toRadixString(16).padLeft(64, '0'), _expectedScalarHex);
  });

  test('rejects a key that is not a usable P-256 PEM', () {
    expect(
      () => FiscalSigner.parsePrivateKeyPem('not a pem at all'),
      throwsA(isA<FiscalKeyException>()),
    );
    expect(
      () => FiscalSigner.parsePrivateKeyPem(''),
      throwsA(isA<FiscalKeyException>()),
    );
  });

  test('signature is DER SEQUENCE{r,s} and verifies against the public key',
      () {
    final signer = FiscalSigner(_sec1Pem);
    final payload = 'CIHI0p4CENIJGAEgATABOJy/w64GQJwO';
    final sigB64 = signer.signBase64Payload(payload);

    final der = base64.decode(sigB64);
    expect(der[0], 0x30, reason: 'DER SEQUENCE tag — not raw r||s');

    // Verify with the matching public key, the way ATK's service does.
    final priv = FiscalSigner.parsePrivateKeyPem(_sec1Pem);
    final domain = ECDomainParameters('prime256v1');
    final pub = ECPublicKey(domain.G * priv.d, domain);

    final r = _derInt(der, 0);
    final s = _derInt(der, 1);
    final verifier = ECDSASigner(SHA256Digest())
      ..init(false, PublicKeyParameter<ECPublicKey>(pub));
    expect(
      verifier.verifySignature(
        Uint8List.fromList(utf8.encode(payload)),
        ECSignature(r, s),
      ),
      isTrue,
    );
  });

  test('signing is deterministic (RFC 6979), so a retry is byte-identical', () {
    final signer = FiscalSigner(_sec1Pem);
    final a = signer.signBase64Payload('abc');
    final b = FiscalSigner(_sec1Pem).signBase64Payload('abc');
    expect(a, b);
  });

}

/// Minimal DER reader for SEQUENCE { INTEGER r, INTEGER s }.
BigInt _derInt(List<int> der, int index) {
  var offset = 2; // skip SEQUENCE tag + length
  for (var i = 0; i < index; i++) {
    offset += 2 + der[offset + 1];
  }
  final len = der[offset + 1];
  final bytes = der.sublist(offset + 2, offset + 2 + len);
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  return v;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

/// Thrown when the configured private key cannot be used for signing.
class FiscalKeyException implements Exception {
  FiscalKeyException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Signs fiscal coupons exactly the way ATK's reference implementations do
/// (`SignBytes` in pos-golang, `Signer.SignBytes` in pos-csharp):
///
/// 1. serialize the coupon to protobuf,
/// 2. base64-encode those bytes,
/// 3. SHA-256 the **UTF-8 bytes of that base64 string** (not the raw proto),
/// 4. sign the hash with the ECDSA P-256 private key,
/// 5. base64-encode the **DER/ASN.1** signature.
///
/// Step 5 is easy to get wrong: Go's `ecdsa.SignASN1` — which produced the
/// reference payloads and which the shipped `signer.dll` wraps — emits DER
/// `SEQUENCE { r, s }`, not the raw r‖s concatenation.
class FiscalSigner {
  FiscalSigner(this.privateKeyPem);

  final String privateKeyPem;

  ECPrivateKey? _cached;

  /// Signs [data] and returns the base64 DER signature.
  String signBytes(Uint8List data) {
    final key = _key();
    // RFC 6979 deterministic nonces: no dependence on a seeded RNG, and the
    // same coupon always yields the same signature, which makes a retry of a
    // failed submission byte-identical instead of a second distinct coupon.
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(key));
    final sig = signer.generateSignature(data) as ECSignature;

    final seq = ASN1Sequence()
      ..add(ASN1Integer(sig.r))
      ..add(ASN1Integer(sig.s));
    return base64.encode(seq.encodedBytes);
  }

  /// Signs the base64 form of a coupon, as ATK expects.
  String signBase64Payload(String base64Payload) =>
      signBytes(Uint8List.fromList(utf8.encode(base64Payload)));

  ECPrivateKey _key() {
    final cached = _cached;
    if (cached != null) return cached;
    final parsed = parsePrivateKeyPem(privateKeyPem);
    _cached = parsed;
    return parsed;
  }

  /// Accepts both PEM shapes the ATK onboarder can hand out:
  /// `EC PRIVATE KEY` (SEC1, RFC 5915) and `PRIVATE KEY` (PKCS#8).
  static ECPrivateKey parsePrivateKeyPem(String pem) {
    final der = _derFromPem(pem);
    final BigInt d;
    try {
      d = _scalarFromDer(der);
    } on FiscalKeyException {
      rethrow;
    } catch (e) {
      throw FiscalKeyException('Çelësi privat nuk u lexua dot: $e');
    }

    final domain = ECDomainParameters('prime256v1');
    if (d <= BigInt.zero || d >= domain.n) {
      throw FiscalKeyException(
        'Çelësi privat nuk i përket kurbës P-256 (prime256v1).',
      );
    }
    return ECPrivateKey(d, domain);
  }

  static Uint8List _derFromPem(String pem) {
    final lines = pem
        .split(RegExp(r'\r\n|\r|\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    if (lines.isEmpty) {
      throw FiscalKeyException('Çelësi privat është bosh.');
    }
    try {
      return Uint8List.fromList(base64.decode(lines));
    } catch (_) {
      throw FiscalKeyException(
        'Çelësi privat nuk është PEM i vlefshëm (base64 i dëmtuar).',
      );
    }
  }

  /// Extracts the private scalar `d` from either SEC1 or PKCS#8 DER.
  static BigInt _scalarFromDer(Uint8List der) {
    final root = ASN1Parser(der).nextObject();
    if (root is! ASN1Sequence || root.elements.isEmpty) {
      throw FiscalKeyException('Struktura e çelësit privat nuk u njoh.');
    }

    // SEC1: SEQUENCE { INTEGER 1, OCTET STRING d, ... }
    final second = root.elements.length > 1 ? root.elements[1] : null;
    if (second is ASN1OctetString) {
      return _bigIntFromBytes(second.octets);
    }

    // PKCS#8: SEQUENCE { INTEGER 0, SEQUENCE alg, OCTET STRING <SEC1 DER> }
    final third = root.elements.length > 2 ? root.elements[2] : null;
    if (second is ASN1Sequence && third is ASN1OctetString) {
      final inner = ASN1Parser(third.octets).nextObject();
      if (inner is ASN1Sequence && inner.elements.length > 1) {
        final key = inner.elements[1];
        if (key is ASN1OctetString) {
          return _bigIntFromBytes(key.octets);
        }
      }
    }

    throw FiscalKeyException(
      'Çelësi privat nuk është as SEC1 (EC PRIVATE KEY) as PKCS#8 (PRIVATE KEY).',
    );
  }

  static BigInt _bigIntFromBytes(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }
}

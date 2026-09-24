import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import 'fiscal_settings.dart';

/// Result of a successful onboarding run.
class FiscalOnboardingResult {
  const FiscalOnboardingResult({
    required this.businessName,
    required this.privateKeyPem,
    required this.certificatePem,
  });

  final String businessName;
  final String privateKeyPem;
  final String certificatePem;
}

class FiscalOnboardingException implements Exception {
  FiscalOnboardingException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : 'ATK $statusCode: $message';
}

/// Does in-app what ATK's `onboarder.exe` does, using the documented API:
///
/// 1. generate an ECDSA P-256 key pair **on this machine**,
/// 2. `POST /ca/verify/{nui}` → business name + verification code,
/// 3. build and self-sign a PKCS#10 CSR,
/// 4. `POST /ca/signcsr` → the certificate signed by ATK's CA.
///
/// The private key is produced locally and is never sent anywhere: only the
/// CSR — which carries the *public* key — leaves the machine.
class FiscalOnboardingService {
  FiscalOnboardingService._();
  static final FiscalOnboardingService instance = FiscalOnboardingService._();

  // ── OIDs ─────────────────────────────────────────────────────────────────
  static const _oidCountry = '2.5.4.6';
  static const _oidLocality = '2.5.4.7';
  static const _oidOrganization = '2.5.4.10';
  static const _oidOrganizationUnit = '2.5.4.11';
  static const _oidCommonName = '2.5.4.3';
  static const _oidEcPublicKey = '1.2.840.10045.2.1';
  static const _oidPrime256v1 = '1.2.840.10045.3.1.7';
  static const _oidEcdsaWithSha256 = '1.2.840.10045.4.3.2';

  Dio _dio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: const {'Content-Type': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

  /// Runs the whole flow and returns the key and certificate.
  Future<FiscalOnboardingResult> onboard({
    required FiscalEnvironment environment,
    required int businessId,
    required String fiscalizationNo,
    required int posId,
    required int branchId,
    required int applicationId,
  }) async {
    if (businessId <= 0) {
      throw FiscalOnboardingException('Mungon NUI i biznesit.');
    }
    if (fiscalizationNo.trim().isEmpty) {
      throw FiscalOnboardingException('Mungon numri i fiskalizimit.');
    }
    if (posId <= 0 || branchId <= 0 || applicationId <= 0) {
      throw FiscalOnboardingException(
        'POS ID, Branch ID dhe Application ID duhet të jenë numra pozitivë.',
      );
    }

    final keyPair = generateKeyPair();
    final verified = await _verifyBusiness(
      environment: environment,
      businessId: businessId,
      fiscalizationNo: fiscalizationNo.trim(),
      posId: posId,
      branchId: branchId,
      applicationId: applicationId,
    );

    final csrPem = buildCsrPem(
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      businessId: businessId,
      posId: posId,
      branchId: branchId,
      commonName: verified.businessName,
    );

    final certificate = await _signCsr(
      environment: environment,
      businessName: verified.businessName,
      businessId: businessId,
      branchId: branchId,
      verificationCode: verified.verificationCode,
      posId: posId,
      applicationId: applicationId,
      csrPem: csrPem,
    );

    return FiscalOnboardingResult(
      businessName: verified.businessName,
      privateKeyPem: encodeSec1PrivateKeyPem(keyPair.privateKey),
      certificatePem: certificate,
    );
  }

  // ── Key generation ───────────────────────────────────────────────────────

  /// A fresh P-256 key pair from a Fortuna CSPRNG seeded with
  /// [math.Random.secure].
  static AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair() {
    final secure = math.Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => secure.nextInt(256)),
    );
    final rnd = FortunaRandom()..seed(KeyParameter(seed));

    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(ECDomainParameters('prime256v1')),
          rnd,
        ),
      );
    final pair = generator.generateKeyPair();
    return AsymmetricKeyPair<ECPublicKey, ECPrivateKey>(
      pair.publicKey as ECPublicKey,
      pair.privateKey as ECPrivateKey,
    );
  }

  // ── ATK calls ────────────────────────────────────────────────────────────

  Future<({String businessName, String verificationCode})> _verifyBusiness({
    required FiscalEnvironment environment,
    required int businessId,
    required String fiscalizationNo,
    required int posId,
    required int branchId,
    required int applicationId,
  }) async {
    final response = await _dio().post<dynamic>(
      '${environment.baseUrl}/ca/verify/$businessId',
      data: {
        'fiscalization_no': fiscalizationNo,
        'pos_id': posId,
        'branch_id': branchId,
        'application_id': applicationId,
      },
    );
    final body = response.data;
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw FiscalOnboardingException(_errorText(body), statusCode: status);
    }
    if (body is! Map) {
      throw FiscalOnboardingException('Përgjigje e papritur nga ATK.');
    }
    final name = '${body['business_name'] ?? ''}'.trim();
    final code = '${body['verification_code'] ?? ''}'.trim();
    if (name.isEmpty || code.isEmpty) {
      throw FiscalOnboardingException(
        'ATK nuk ktheu emrin e biznesit dhe kodin e verifikimit.',
      );
    }
    return (businessName: name, verificationCode: code);
  }

  Future<String> _signCsr({
    required FiscalEnvironment environment,
    required String businessName,
    required int businessId,
    required int branchId,
    required String verificationCode,
    required int posId,
    required int applicationId,
    required String csrPem,
  }) async {
    final response = await _dio().post<dynamic>(
      '${environment.baseUrl}/ca/signcsr',
      data: {
        'business_name': businessName,
        'business_id': businessId,
        'branch_id': branchId,
        'verification_code': verificationCode,
        'pos_id': posId,
        'application_id': applicationId,
        'csr': csrPem,
      },
    );
    final body = response.data;
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw FiscalOnboardingException(_errorText(body), statusCode: status);
    }
    final cert = body is Map ? '${body['signed_certificate'] ?? ''}'.trim() : '';
    if (cert.isEmpty) {
      throw FiscalOnboardingException('ATK nuk ktheu certifikatën e nënshkruar.');
    }
    return cert;
  }

  static String _errorText(dynamic body) {
    if (body is Map) {
      return '${body['error'] ?? body['message'] ?? body}';
    }
    return '$body';
  }

  // ── PKCS#10 CSR ──────────────────────────────────────────────────────────

  /// Builds the CSR ATK expects.
  ///
  /// Subject fields are prescribed by ATK's documentation:
  /// Country `RKS`, Organization = business id, Organizational Unit = POS id,
  /// Locality = branch id, Common Name = the business name returned by
  /// `/ca/verify`.
  static String buildCsrPem({
    required ECPrivateKey privateKey,
    required ECPublicKey publicKey,
    required int businessId,
    required int posId,
    required int branchId,
    required String commonName,
  }) {
    final info = _certificationRequestInfo(
      publicKey: publicKey,
      businessId: businessId,
      posId: posId,
      branchId: branchId,
      commonName: commonName,
    );
    final infoDer = info.encodedBytes;

    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(true, PrivateKeyParameter<ECPrivateKey>(privateKey));
    final sig = signer.generateSignature(infoDer) as ECSignature;
    final sigDer = (ASN1Sequence()
          ..add(ASN1Integer(sig.r))
          ..add(ASN1Integer(sig.s)))
        .encodedBytes;

    final request = ASN1Sequence()
      ..add(info)
      ..add(ASN1Sequence()..add(ASN1ObjectIdentifier.fromComponentString(_oidEcdsaWithSha256)))
      ..add(ASN1BitString(sigDer));

    return _pem('CERTIFICATE REQUEST', request.encodedBytes);
  }

  static ASN1Sequence _certificationRequestInfo({
    required ECPublicKey publicKey,
    required int businessId,
    required int posId,
    required int branchId,
    required String commonName,
  }) {
    final subject = ASN1Sequence()
      ..add(_rdn(_oidCountry, 'RKS'))
      ..add(_rdn(_oidOrganization, '$businessId'))
      ..add(_rdn(_oidOrganizationUnit, '$posId'))
      ..add(_rdn(_oidLocality, '$branchId'))
      ..add(_rdn(_oidCommonName, commonName));

    final algorithm = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString(_oidEcPublicKey))
      ..add(ASN1ObjectIdentifier.fromComponentString(_oidPrime256v1));

    final spki = ASN1Sequence()
      ..add(algorithm)
      ..add(ASN1BitString(_uncompressedPoint(publicKey)));

    final info = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero)) // version 0
      ..add(subject)
      ..add(spki)
      // [0] attributes — empty, but the tag must be present.
      ..add(ASN1Object.preEncoded(0xA0, Uint8List(0)));
    return info;
  }

  /// One RelativeDistinguishedName: SET { SEQUENCE { OID, value } }.
  static ASN1Set _rdn(String oid, String value) {
    final pair = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString(oid))
      ..add(_stringValue(oid, value));
    return ASN1Set()..add(pair);
  }

  /// Country must be PrintableString; the rest tolerate UTF8String, which the
  /// business name may well need.
  static ASN1Object _stringValue(String oid, String value) {
    if (oid == _oidCountry) return ASN1PrintableString(value);
    return ASN1UTF8String(value);
  }

  /// SEC1 uncompressed point: 0x04 ‖ X ‖ Y, each coordinate 32 bytes.
  static Uint8List _uncompressedPoint(ECPublicKey key) {
    final q = key.Q!;
    final x = _fixed32(q.x!.toBigInteger()!);
    final y = _fixed32(q.y!.toBigInteger()!);
    return Uint8List.fromList([0x04, ...x, ...y]);
  }

  static Uint8List _fixed32(BigInt v) {
    final out = Uint8List(32);
    var n = v;
    for (var i = 31; i >= 0; i--) {
      out[i] = (n & BigInt.from(0xff)).toInt();
      n = n >> 8;
    }
    return out;
  }

  // ── SEC1 private key PEM ─────────────────────────────────────────────────

  /// Writes the key in the same `EC PRIVATE KEY` shape ATK's Go tooling reads
  /// (`x509.ParseECPrivateKey`), so a key generated here and one exported by
  /// the onboarder are interchangeable.
  static String encodeSec1PrivateKeyPem(ECPrivateKey key) {
    final d = _fixed32(key.d!);
    final domain = ECDomainParameters('prime256v1');
    final q = domain.G * key.d!;
    final point = Uint8List.fromList([
      0x04,
      ..._fixed32(q!.x!.toBigInteger()!),
      ..._fixed32(q.y!.toBigInteger()!),
    ]);

    final seq = ASN1Sequence()
      ..add(ASN1Integer(BigInt.one))
      ..add(ASN1OctetString(d))
      ..add(
        ASN1Object.preEncoded(
          0xA0,
          ASN1ObjectIdentifier.fromComponentString(_oidPrime256v1).encodedBytes,
        ),
      )
      ..add(ASN1Object.preEncoded(0xA1, ASN1BitString(point).encodedBytes));

    return _pem('EC PRIVATE KEY', seq.encodedBytes);
  }

  static String _pem(String label, Uint8List der) {
    final b64 = base64.encode(der);
    final buffer = StringBuffer('-----BEGIN $label-----\n');
    for (var i = 0; i < b64.length; i += 64) {
      buffer.writeln(b64.substring(i, math.min(i + 64, b64.length)));
    }
    buffer.write('-----END $label-----\n');
    return buffer.toString();
  }
}

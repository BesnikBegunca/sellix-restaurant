/// Business + license payload from SelliX web (`POST /api/license/*`).
class SellixBusinessProfile {
  const SellixBusinessProfile({
    this.nui = '',
    this.name = '',
    this.fiscalNumber = '',
    this.vatNumber = '',
    this.address = '',
    this.city = '',
    this.zipCode = '',
    this.country = '',
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.sector = '',
    this.notes = '',
  });

  final String nui;
  final String name;
  final String fiscalNumber;
  final String vatNumber;
  final String address;
  final String city;
  final String zipCode;
  final String country;
  final String contactPerson;
  final String phone;
  final String email;
  final String sector;
  final String notes;

  factory SellixBusinessProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SellixBusinessProfile();
    String read(String key) => (json[key] as String?)?.trim() ?? '';
    return SellixBusinessProfile(
      nui: read('nui'),
      name: read('name'),
      fiscalNumber: read('fiscalNumber'),
      vatNumber: read('vatNumber'),
      address: read('address'),
      city: read('city'),
      zipCode: read('zipCode'),
      country: read('country'),
      contactPerson: read('contactPerson'),
      phone: read('phone'),
      email: read('email'),
      sector: read('sector'),
      notes: read('notes'),
    );
  }

  Map<String, dynamic> toJson() => {
    'nui': nui,
    'name': name,
    'fiscalNumber': fiscalNumber,
    'vatNumber': vatNumber,
    'address': address,
    'city': city,
    'zipCode': zipCode,
    'country': country,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'sector': sector,
    'notes': notes,
  };

  String get formattedAddress {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (zipCode.isNotEmpty || city.isNotEmpty)
        [zipCode, city].where((e) => e.isNotEmpty).join(' '),
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }
}

class SellixLicenseInfo {
  const SellixLicenseInfo({
    this.status = '',
    this.expiresAt = '',
    this.seats = 0,
    this.devicesUsed = 0,
  });

  final String status;
  final String expiresAt;
  final int seats;
  final int devicesUsed;

  factory SellixLicenseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SellixLicenseInfo();
    return SellixLicenseInfo(
      status: (json['status'] as String?)?.trim() ?? '',
      expiresAt: (json['expiresAt'] as String?)?.trim() ?? '',
      seats: _asInt(json['seats']),
      devicesUsed: _asInt(json['devicesUsed']),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'expiresAt': expiresAt,
    'seats': seats,
    'devicesUsed': devicesUsed,
  };

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SellixLicenseResponse {
  const SellixLicenseResponse({
    required this.valid,
    this.reason,
    this.business = const SellixBusinessProfile(),
    this.license = const SellixLicenseInfo(),
  });

  final bool valid;
  final String? reason;
  final SellixBusinessProfile business;
  final SellixLicenseInfo license;

  factory SellixLicenseResponse.fromJson(Map<String, dynamic> json) {
    return SellixLicenseResponse(
      valid: json['valid'] == true,
      reason: (json['reason'] as String?)?.trim(),
      business: SellixBusinessProfile.fromJson(
        json['business'] is Map<String, dynamic>
            ? json['business'] as Map<String, dynamic>
            : null,
      ),
      license: SellixLicenseInfo.fromJson(
        json['license'] is Map<String, dynamic>
            ? json['license'] as Map<String, dynamic>
            : null,
      ),
    );
  }
}

/// Same table-service sectors as the web portal Tables tab.
final _restaurantSectorPattern = RegExp(
  r'restaurant|restorant|bar|kafe|caf|pub|bistro|pizzer',
  caseSensitive: false,
);

bool isRestaurantSector(String? sector) {
  final value = sector?.trim() ?? '';
  if (value.isEmpty) return false;
  return _restaurantSectorPattern.hasMatch(value);
}

String normalizeSellixLicenseKey(String raw) =>
    raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

bool isSellixLicenseKey(String raw) =>
    normalizeSellixLicenseKey(raw).startsWith('SLX-');

/// Converts SelliX `YYYY-MM-DD HH:MM:SS` (UTC) into an ISO-8601 string.
String? parseSellixDateTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final isoLike = trimmed.contains('T')
      ? trimmed
      : trimmed.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(isoLike.endsWith('Z') ? isoLike : '${isoLike}Z') ??
      DateTime.tryParse(isoLike);
  return parsed?.toUtc().toIso8601String();
}

/// Shop-local `YYYY-MM-DD HH:MM:SS` for `POST /api/sales/sync`.
String toShopLocalSoldAt(DateTime when) {
  final local = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

DateTime? parseStoredSaleTimestamp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final trimmed = raw.trim();
  return DateTime.tryParse(trimmed) ??
      DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
}

String sellixLicenseReasonMessage(String? reason) {
  switch (reason) {
    case 'not_found':
      return 'Çelësi nuk u gjet. Kontrolloni që ta keni shkruar saktë, '
          'ose që administratori të mos e ketë rigjeneruar.';
    case 'revoked':
      return 'Licenca është revokuar. Kontaktoni SelliX.';
    case 'expired':
      return 'Licenca ka skaduar. Kontaktoni administratorin për rinovim.';
    case 'seat_limit':
      return 'Të gjitha pajisjet e lejuara janë në përdorim. '
          'Administratori duhet të lirojë një pajisje te Businesses → Devices.';
    case 'not_activated':
      return 'Kjo pajisje nuk është aktivizuar. Vendosni çelësin përsëri.';
    case 'rate_limited':
      return 'Shumë përpjekje. Provoni përsëri pas pak minutash.';
    case 'network':
      return 'Nuk ka lidhje me internet. Për aktivizimin e parë duhet rrjet; '
          'pas kësaj aplikacioni punon edhe offline.';
    case 'missing_license_key':
    case 'missing_device_id':
      return 'Kërkesa e aktivizimit është e paplotë. Provoni përsëri.';
    case 'not_restaurant':
      return 'Ky çelës nuk i përket një restoranti. '
          'Ky aplikacion punon vetëm me kategori restaurant / bar / kafene.';
    default:
      return 'Çelësi i aktivizimit nuk është i vlefshëm.';
  }
}

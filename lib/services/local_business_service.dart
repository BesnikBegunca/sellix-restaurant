import 'dart:convert';

import 'database_service.dart';

class LocalBusiness {
  const LocalBusiness({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.branch,
    required this.licenseKey,
    required this.expiresAt,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String branch;
  final String licenseKey;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalBusiness &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'branch': branch,
    'licenseKey': licenseKey,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory LocalBusiness.fromJson(Map<String, dynamic> json) => LocalBusiness(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String? ?? '',
    address: json['address'] as String? ?? '',
    branch: json['branch'] as String? ?? 'MAIN',
    licenseKey: json['licenseKey'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}

class LocalBusinessService {
  LocalBusinessService._();
  static final instance = LocalBusinessService._();
  static const _metaKey = 'local_developer_businesses';

  Future<List<LocalBusiness>> list() async {
    final raw = await DatabaseService.instance.getAppMeta(_metaKey);
    if (raw == null || raw.isEmpty) return [];
    final values = jsonDecode(raw) as List;
    return values
        .map((value) => LocalBusiness.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(LocalBusiness business) async {
    final businesses = await list();
    final index = businesses.indexWhere((item) => item.id == business.id);
    if (index >= 0) {
      businesses[index] = business;
    } else {
      businesses.add(business);
    }
    await DatabaseService.instance.setAppMeta(
      _metaKey,
      jsonEncode(businesses.map((item) => item.toJson()).toList()),
    );
  }
}

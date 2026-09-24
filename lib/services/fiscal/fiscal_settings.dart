import 'package:flutter/foundation.dart';

import '../database_service.dart';
import 'fiscal_models.dart';

/// Which ATK environment the coupons go to.
enum FiscalEnvironment {
  test('TEST', 'https://fiskalizimi-test.atk-ks.org'),
  production('PROD', 'https://fiskalizimi.atk-ks.org');

  const FiscalEnvironment(this.code, this.baseUrl);
  final String code;
  final String baseUrl;

  String get posCouponUrl => '$baseUrl/pos/coupon';

  static FiscalEnvironment fromCode(String? code) =>
      code == 'PROD' ? FiscalEnvironment.production : FiscalEnvironment.test;
}

/// Everything the fiscal coupon needs that is not part of the order itself.
///
/// [businessId], [branchId], [posId] and [applicationId] come from the ATK
/// onboarding; [privateKeyPem] is produced by the ATK onboarder tool and must
/// never leave this machine.
@immutable
class FiscalSettings {
  const FiscalSettings({
    this.enabled = false,
    this.environment = FiscalEnvironment.test,
    this.businessId = 0,
    this.branchId = 0,
    this.posId = 0,
    this.applicationId = 0,
    this.location = '',
    this.taxRate = FiscalTaxRate.e,
    this.pricesIncludeVat = true,
    this.privateKeyPem = '',
    this.certificatePem = '',
    this.unit = 'cope',
    this.itemType = 'TT',
  });

  final bool enabled;
  final FiscalEnvironment environment;

  /// The business NUI.
  final int businessId;
  final int branchId;
  final int posId;

  /// Issued by ATK when the POS software is certified.
  final int applicationId;

  /// City of the sale point, printed on the coupon.
  final String location;

  /// Single VAT rate applied to every item.
  final FiscalTaxRate taxRate;

  /// True when menu prices already contain VAT — the normal Kosovo retail
  /// case. The VAT is then extracted from the gross total rather than added
  /// on top of it.
  final bool pricesIncludeVat;

  final String privateKeyPem;
  final String certificatePem;

  /// Unit of measure sent for every line.
  final String unit;

  /// Article category sent for every line.
  final String itemType;

  /// Whether a coupon can actually be issued right now.
  bool get isConfigured =>
      enabled &&
      businessId > 0 &&
      branchId > 0 &&
      posId > 0 &&
      applicationId > 0 &&
      privateKeyPem.trim().isNotEmpty;

  /// A human-readable reason why [isConfigured] is false, for the UI.
  String? get configurationProblem {
    if (!enabled) return 'Fiskalizimi nuk është i aktivizuar.';
    if (businessId <= 0) return 'Mungon NUI i biznesit (Business ID).';
    if (branchId <= 0) return 'Mungon ID e njësisë (Branch ID).';
    if (posId <= 0) return 'Mungon ID e arkës (POS ID).';
    if (applicationId <= 0) return 'Mungon ID e aplikacionit (Application ID).';
    if (privateKeyPem.trim().isEmpty) {
      return 'Mungon çelësi privat. Ekzekuto mjetin e onboarding-ut të ATK-së.';
    }
    return null;
  }

  FiscalSettings copyWith({
    bool? enabled,
    FiscalEnvironment? environment,
    int? businessId,
    int? branchId,
    int? posId,
    int? applicationId,
    String? location,
    FiscalTaxRate? taxRate,
    bool? pricesIncludeVat,
    String? privateKeyPem,
    String? certificatePem,
    String? unit,
    String? itemType,
  }) {
    return FiscalSettings(
      enabled: enabled ?? this.enabled,
      environment: environment ?? this.environment,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      posId: posId ?? this.posId,
      applicationId: applicationId ?? this.applicationId,
      location: location ?? this.location,
      taxRate: taxRate ?? this.taxRate,
      pricesIncludeVat: pricesIncludeVat ?? this.pricesIncludeVat,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      certificatePem: certificatePem ?? this.certificatePem,
      unit: unit ?? this.unit,
      itemType: itemType ?? this.itemType,
    );
  }
}

/// Loads and stores [FiscalSettings] in `app_meta`.
class FiscalSettingsStore extends ChangeNotifier {
  FiscalSettingsStore._();
  static final FiscalSettingsStore instance = FiscalSettingsStore._();

  static const _kEnabled = 'fiscal_enabled';
  static const _kEnv = 'fiscal_environment';
  static const _kBusinessId = 'fiscal_business_id';
  static const _kBranchId = 'fiscal_branch_id';
  static const _kPosId = 'fiscal_pos_id';
  static const _kApplicationId = 'fiscal_application_id';
  static const _kLocation = 'fiscal_location';
  static const _kTaxRate = 'fiscal_tax_rate';
  static const _kPricesIncludeVat = 'fiscal_prices_include_vat';
  static const _kPrivateKey = 'fiscal_private_key_pem';
  static const _kCertificate = 'fiscal_certificate_pem';
  static const _kUnit = 'fiscal_unit';
  static const _kItemType = 'fiscal_item_type';

  /// Keys wiped together with the rest of the tenant data — a new business
  /// must not inherit the previous one's fiscal identity or private key.
  static const List<String> resetKeys = <String>[
    _kEnabled,
    _kEnv,
    _kBusinessId,
    _kBranchId,
    _kPosId,
    _kApplicationId,
    _kLocation,
    _kTaxRate,
    _kPricesIncludeVat,
    _kPrivateKey,
    _kCertificate,
    _kUnit,
    _kItemType,
  ];

  FiscalSettings _settings = const FiscalSettings();
  bool _loaded = false;

  FiscalSettings get settings => _settings;
  bool get isLoaded => _loaded;

  Future<FiscalSettings> load() async {
    final db = DatabaseService.instance;
    final enabled = await db.getAppMeta(_kEnabled);
    final env = await db.getAppMeta(_kEnv);
    final businessId = await db.getAppMeta(_kBusinessId);
    final branchId = await db.getAppMeta(_kBranchId);
    final posId = await db.getAppMeta(_kPosId);
    final applicationId = await db.getAppMeta(_kApplicationId);
    final location = await db.getAppMeta(_kLocation);
    final taxRate = await db.getAppMeta(_kTaxRate);
    final includeVat = await db.getAppMeta(_kPricesIncludeVat);
    final privateKey = await db.getAppMeta(_kPrivateKey);
    final certificate = await db.getAppMeta(_kCertificate);
    final unit = await db.getAppMeta(_kUnit);
    final itemType = await db.getAppMeta(_kItemType);

    _settings = FiscalSettings(
      enabled: enabled == '1',
      environment: FiscalEnvironment.fromCode(env),
      businessId: int.tryParse(businessId ?? '') ?? 0,
      branchId: int.tryParse(branchId ?? '') ?? 0,
      posId: int.tryParse(posId ?? '') ?? 0,
      applicationId: int.tryParse(applicationId ?? '') ?? 0,
      location: location ?? '',
      taxRate: FiscalTaxRate.fromCode(taxRate),
      // Default true: Kosovo menu prices include VAT.
      pricesIncludeVat: includeVat != '0',
      privateKeyPem: privateKey ?? '',
      certificatePem: certificate ?? '',
      unit: (unit == null || unit.isEmpty) ? 'cope' : unit,
      itemType: (itemType == null || itemType.isEmpty) ? 'TT' : itemType,
    );
    _loaded = true;
    notifyListeners();
    return _settings;
  }

  Future<void> save(FiscalSettings next) async {
    final db = DatabaseService.instance;
    await db.setAppMeta(_kEnabled, next.enabled ? '1' : '0');
    await db.setAppMeta(_kEnv, next.environment.code);
    await db.setAppMeta(_kBusinessId, next.businessId.toString());
    await db.setAppMeta(_kBranchId, next.branchId.toString());
    await db.setAppMeta(_kPosId, next.posId.toString());
    await db.setAppMeta(_kApplicationId, next.applicationId.toString());
    await db.setAppMeta(_kLocation, next.location);
    await db.setAppMeta(_kTaxRate, next.taxRate.code);
    await db.setAppMeta(_kPricesIncludeVat, next.pricesIncludeVat ? '1' : '0');
    await db.setAppMeta(_kPrivateKey, next.privateKeyPem);
    await db.setAppMeta(_kCertificate, next.certificatePem);
    await db.setAppMeta(_kUnit, next.unit);
    await db.setAppMeta(_kItemType, next.itemType);
    _settings = next;
    _loaded = true;
    notifyListeners();
  }
}

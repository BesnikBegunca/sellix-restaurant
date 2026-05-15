import 'database_service.dart';

/// Menaxhon skadimin e licencës së aplikacionit (ruhet në `app_meta`).
class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  static const metaKey = 'license_expires_at';
  static const devUsername = 'admin';
  static const devPassword = 'admin';

  /// Kohëzgjatjet e zgjatjes së licencës.
  static const extensionOptions = <({String label, Duration duration})>[
    (label: '1 minutë', duration: Duration(minutes: 1)),
    (label: '1 orë', duration: Duration(hours: 1)),
    (label: '1 javë', duration: Duration(days: 7)),
    (label: '3 muaj', duration: Duration(days: 90)),
    (label: '6 muaj', duration: Duration(days: 182)),
    (label: '1 vit', duration: Duration(days: 365)),
    (label: '2 vite', duration: Duration(days: 730)),
  ];

  bool validateDevCredentials(String username, String password) {
    return username.trim() == devUsername && password == devPassword;
  }

  Future<DateTime?> getExpiresAt() async {
    final raw = await DatabaseService.instance.getAppMeta(metaKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  Future<bool> isLicenseValid() async {
    final exp = await getExpiresAt();
    if (exp == null) return false;
    return DateTime.now().isBefore(exp);
  }

  /// Zgjat nga data aktuale e skadimit (nëse ende e vlefshme), përndryshe nga tani.
  Future<DateTime> extendLicense(Duration extension) async {
    final now = DateTime.now();
    final current = await getExpiresAt();
    final base =
        (current != null && current.isAfter(now)) ? current : now;
    final newExpiry = base.add(extension);
    await DatabaseService.instance.setAppMeta(
      metaKey,
      newExpiry.toIso8601String(),
    );
    return newExpiry;
  }

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nuk është aktivizuar';
    final local = dt.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(local.day)}.${p(local.month)}.${local.year} '
        '${p(local.hour)}:${p(local.minute)}';
  }

  static String statusLabel(bool valid, DateTime? exp) {
    if (exp == null) return 'Licenca nuk është aktivizuar';
    if (valid) return 'Aktive deri më ${formatDateTime(exp)}';
    return 'Skaduar më ${formatDateTime(exp)}';
  }
}

import '../manager/manager_data.dart';
import '../services/database_service.dart';

/// Ruajtja / leximi i emrit të printerit të zgjedhur.
///
/// Shënim: kërkon që DatabaseService të ketë fushën `company.printerName`
/// (do ta shtojmë gjatë integrimit të printimit).
class PrinterSettingsStore {
  static const String _defaultPrinterName = '';

  static Future<String> loadSelectedPrinterName() async {
    final m = ManagerData.instance;
    if (m.selectedPrinterName != null) return m.selectedPrinterName!;

    final company = await DatabaseService.instance.fetchCompany();
    final name = (company?['printerName'] as String?) ?? _defaultPrinterName;
    m.selectedPrinterName = name;
    return name;
  }

  static Future<void> saveSelectedPrinterName(String name) async {
    final n = name.trim();
    ManagerData.instance.selectedPrinterName = n;
    await DatabaseService.instance.updateCompanyPrinterName(n);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/activation_service.dart';
import '../services/local_business_service.dart';
import '../services/local_license_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gg_header.dart';
import '../l10n/tr.dart';

class DeveloperLoginScreen extends StatefulWidget {
  const DeveloperLoginScreen({super.key});

  @override
  State<DeveloperLoginScreen> createState() => _DeveloperLoginScreenState();
}

class _DeveloperLoginScreenState extends State<DeveloperLoginScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _branch = TextEditingController(text: 'MAIN');
  final _days = TextEditingController(text: '30');
  List<LocalBusiness> _businesses = [];
  LocalBusiness? _selected;
  bool _english = true;
  bool _busy = false;
  String? _error;

  String t(String en, String sq) => _english ? en : sq;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    final businesses = await LocalBusinessService.instance.list();
    if (!mounted) return;
    setState(() => _businesses = businesses);
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _address, _branch, _days]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createBusiness() async {
    final name = _name.text.trim();
    final days = int.tryParse(_days.text.trim());
    if (name.isEmpty || days == null) {
      setState(
        () => _error = t(
          'Business name and valid license days are required.',
          tr.emriBiznesitDitetLicencesJaneDetyrueshme,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = LocalLicenseService.instance.generateLicense(
        ownerName: name,
        days: days,
      );
      final license = LocalLicenseService.instance.validate(key)!;
      final business = LocalBusiness(
        id: license.licenseId,
        name: name,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        branch: _branch.text.trim().isEmpty ? 'MAIN' : _branch.text.trim(),
        licenseKey: key,
        expiresAt: license.expiresAt,
      );
      await LocalBusinessService.instance.save(business);
      await _loadBusinesses();
      if (!mounted) return;
      setState(() => _selected = business);
      await _showCode(key);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extendSelected() async {
    final business = _selected;
    final days = int.tryParse(_days.text.trim());
    if (business == null || days == null) {
      setState(
        () => _error = t(
          'Select a business and enter valid days.',
          tr.zgjidhniBiznesinVendosniDiteVlefshme,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = LocalLicenseService.instance.validate(
        business.licenseKey,
      );
      if (current == null) throw StateError('Licenca aktuale ka skaduar.');
      final key = LocalLicenseService.instance.generateLicense(
        ownerName: business.name,
        days: days,
        startsAt: current.expiresAt,
      );
      final license = LocalLicenseService.instance.validate(key)!;
      final updated = LocalBusiness(
        id: business.id,
        name: business.name,
        phone: business.phone,
        address: business.address,
        branch: business.branch,
        licenseKey: key,
        expiresAt: license.expiresAt,
      );
      await LocalBusinessService.instance.save(updated);
      final activeLicenseUpdated = await ActivationService.instance
          .extendActiveLocalLicenseForBusiness(
            businessId: business.id,
            replacementKey: key,
          );
      await _loadBusinesses();
      if (!mounted) return;
      setState(() => _selected = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              activeLicenseUpdated
                  ? 'License extended until ${license.expiresAt.toLocal().toString().split('.').first}.'
                  : 'License extended locally. The client must enter the new key.',
              activeLicenseUpdated
                  ? trf.licenceExtendedUntil(
                      license.expiresAt.toLocal().toString().split('.').first,
                    )
                  : tr.licencaUVazhduaLokalishtKlientiDuhet,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCode(String key) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('License key ready', tr.celesiEshteGati)),
        content: SelectableText(key),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(t('Copy', 'Kopjo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(tr.close, tr.mbyll)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF111817),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6FCF97),
          secondary: const Color(0xFF9ADBB4),
          surface: const Color(0xFF1B2925),
          error: AppColors.softRed,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1B2925),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23332E),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF3B5149)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF3B5149)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF6FCF97), width: 2),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('Developer dashboard', 'Dashboard i developer-it')),
          actions: [
            TextButton(
              onPressed: () => setState(() => _english = !_english),
              child: Text(_english ? 'SQ' : 'EN'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 20),
              if (_businesses.isNotEmpty)
                DropdownButtonFormField<LocalBusiness>(
                  initialValue: selected,
                  decoration: InputDecoration(
                    labelText: t('Select business', 'Zgjidh biznesin'),
                    prefixIcon: const Icon(Icons.storefront_rounded),
                  ),
                  items: _businesses
                      .map(
                        (business) => DropdownMenuItem(
                          value: business,
                          child: Text(business.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selected = value),
                ),
              const SizedBox(height: 16),
              if (selected != null) _businessCard(selected),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        selected == null
                            ? t('Create business', 'Krijo biznes')
                            : t(
                                'Create another business',
                                tr.krijoBiznesTjeter,
                              ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _field(
                        _name,
                        t('Business name', 'Emri i biznesit'),
                        Icons.business_rounded,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _phone,
                        t('Phone', 'Telefoni'),
                        Icons.phone_rounded,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _address,
                        t('Address', 'Adresa'),
                        Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _branch,
                        t('Branch code', tr.kodiDeges2),
                        Icons.account_tree_rounded,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _days,
                        t('Days to add', tr.diteTUShtuar),
                        Icons.calendar_month_rounded,
                        numeric: true,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: AppColors.softRed),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _createBusiness,
                              icon: const Icon(Icons.add_business_rounded),
                              label: Text(
                                t(
                                  'Create and issue key',
                                  'Krijo dhe gjenero key',
                                ),
                              ),
                            ),
                          ),
                          if (selected != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _extendSelected,
                                icon: const Icon(Icons.autorenew_rounded),
                                label: Text(
                                  t('Extend license', tr.vazhdoLicencen),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(t('Back', tr.kthehu)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Card(
    color: AppColors.primaryGreen,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const GgLogoBox(size: 58, radius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              t(
                'Manage local businesses and licenses',
                'Menaxho bizneset dhe licencat lokale',
              ),
              style: TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _businessCard(LocalBusiness business) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.storefront_rounded)),
      title: Text(business.name),
      subtitle: Text(
        '${business.branch}  •  Skadon: ${business.expiresAt.toLocal().toString().split('.').first}',
      ),
      trailing: Icon(
        Icons.verified_rounded,
        color: AppColors.successGreen,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool numeric = false,
  }) => TextField(
    controller: controller,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}

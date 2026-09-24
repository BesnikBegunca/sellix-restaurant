import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/fiscal/fiscal_models.dart';
import '../../../services/fiscal/fiscal_service.dart';
import '../../../services/fiscal/fiscal_settings.dart';
import '../../../services/fiscal/fiscal_signer.dart';
import '../../../theme/app_colors.dart';

/// Configuration for ATK fiscalisation ("Kupon Fiskal").
///
/// Everything here comes from the ATK onboarding: the identifiers from the SEF
/// application and the EDI fiscalisation number, and the private key produced
/// by ATK's onboarder tool.
class FiscalSettingsPanel extends StatefulWidget {
  const FiscalSettingsPanel({super.key});

  @override
  State<FiscalSettingsPanel> createState() => _FiscalSettingsPanelState();
}

class _FiscalSettingsPanelState extends State<FiscalSettingsPanel> {
  final _businessId = TextEditingController();
  final _branchId = TextEditingController();
  final _posId = TextEditingController();
  final _applicationId = TextEditingController();
  final _location = TextEditingController();
  final _unit = TextEditingController();
  final _itemType = TextEditingController();
  final _privateKey = TextEditingController();
  final _certificate = TextEditingController();

  bool _enabled = false;
  bool _pricesIncludeVat = true;
  FiscalEnvironment _environment = FiscalEnvironment.test;
  FiscalTaxRate _taxRate = FiscalTaxRate.e;

  bool _loading = true;
  bool _saving = false;
  String? _keyStatus;
  bool _keyOk = false;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _businessId,
      _branchId,
      _posId,
      _applicationId,
      _location,
      _unit,
      _itemType,
      _privateKey,
      _certificate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await FiscalSettingsStore.instance.load();
    final pending = await FiscalService.instance.pendingCount();
    if (!mounted) return;
    setState(() {
      _enabled = s.enabled;
      _environment = s.environment;
      _businessId.text = s.businessId > 0 ? s.businessId.toString() : '';
      _branchId.text = s.branchId > 0 ? s.branchId.toString() : '';
      _posId.text = s.posId > 0 ? s.posId.toString() : '';
      _applicationId.text =
          s.applicationId > 0 ? s.applicationId.toString() : '';
      _location.text = s.location;
      _unit.text = s.unit;
      _itemType.text = s.itemType;
      _privateKey.text = s.privateKeyPem;
      _certificate.text = s.certificatePem;
      _taxRate = s.taxRate;
      _pricesIncludeVat = s.pricesIncludeVat;
      _pending = pending;
      _loading = false;
    });
    _validateKey();
  }

  void _validateKey() {
    final pem = _privateKey.text.trim();
    if (pem.isEmpty) {
      setState(() {
        _keyOk = false;
        _keyStatus = null;
      });
      return;
    }
    try {
      FiscalSigner.parsePrivateKeyPem(pem);
      setState(() {
        _keyOk = true;
        _keyStatus = 'Çelësi P-256 u lexua me sukses.';
      });
    } on FiscalKeyException catch (e) {
      setState(() {
        _keyOk = false;
        _keyStatus = e.message;
      });
    } catch (e) {
      setState(() {
        _keyOk = false;
        _keyStatus = 'Çelësi nuk u lexua: $e';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final next = FiscalSettings(
      enabled: _enabled,
      environment: _environment,
      businessId: int.tryParse(_businessId.text.trim()) ?? 0,
      branchId: int.tryParse(_branchId.text.trim()) ?? 0,
      posId: int.tryParse(_posId.text.trim()) ?? 0,
      applicationId: int.tryParse(_applicationId.text.trim()) ?? 0,
      location: _location.text.trim(),
      taxRate: _taxRate,
      pricesIncludeVat: _pricesIncludeVat,
      privateKeyPem: _privateKey.text.trim(),
      certificatePem: _certificate.text.trim(),
      unit: _unit.text.trim().isEmpty ? 'cope' : _unit.text.trim(),
      itemType: _itemType.text.trim().isEmpty ? 'TT' : _itemType.text.trim(),
    );
    await FiscalSettingsStore.instance.save(next);
    if (!mounted) return;
    setState(() => _saving = false);
    final problem = next.configurationProblem;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          problem == null
              ? 'Cilësimet fiskale u ruajtën. Butoni "Kupon Fiskal" është aktiv.'
              : 'U ruajt, por ende mungon diçka: $problem',
        ),
        backgroundColor:
            problem == null ? AppColors.primaryGreen : AppColors.negativeText,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _retryPending() async {
    final sent = await FiscalService.instance.retryPending();
    final pending = await FiscalService.instance.pendingCount();
    if (!mounted) return;
    setState(() => _pending = pending);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent == 0
              ? 'Asnjë kupon nuk u dërgua. Mbeten $pending në pritje.'
              : 'U dërguan $sent kuponë. Mbeten $pending në pritje.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            title: 'Fiskalizimi (ATK)',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text('Aktivizo butonin "Kupon Fiskal"'),
                subtitle: const Text(
                  'Kur është i fikur, butoni nuk shfaqet fare te porosia.',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FiscalEnvironment>(
                      initialValue: _environment,
                      decoration: const InputDecoration(
                        labelText: 'Mjedisi',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FiscalEnvironment.test,
                          child: Text('TEST — fiskalizimi-test.atk-ks.org'),
                        ),
                        DropdownMenuItem(
                          value: FiscalEnvironment.production,
                          child: Text('PROD — fiskalizimi.atk-ks.org'),
                        ),
                      ],
                      onChanged: (v) => setState(
                        () => _environment = v ?? FiscalEnvironment.test,
                      ),
                    ),
                  ),
                ],
              ),
              if (_environment == FiscalEnvironment.production) ...[
                const SizedBox(height: 10),
                _warning(
                  'Në PROD çdo kupon është dokument tatimor real. '
                  'Testo së pari në TEST.',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Identifikuesit e ATK-së',
            subtitle:
                'Nga aplikimi SEF dhe numri i fiskalizimit nga EDI. Këto duhet '
                'të jenë saktësisht si te certifikata.',
            children: [
              _numberField(_businessId, 'NUI i biznesit (Business ID)'),
              const SizedBox(height: 12),
              _numberField(_branchId, 'ID e njësisë (Branch ID)'),
              const SizedBox(height: 12),
              _numberField(
                _posId,
                'ID e arkës (POS ID) — unike për çdo kompjuter',
              ),
              const SizedBox(height: 12),
              _numberField(
                _applicationId,
                'ID e aplikacionit (Application ID)',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Vendi i pikës së shitjes (p.sh. Kacanik)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: 'TVSH',
            subtitle:
                'Një normë e vetme aplikohet për çdo artikull të kuponit.',
            children: [
              DropdownButtonFormField<FiscalTaxRate>(
                initialValue: _taxRate,
                decoration: const InputDecoration(
                  labelText: 'Norma e TVSH-së',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final r in FiscalTaxRate.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() => _taxRate = v ?? _taxRate),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pricesIncludeVat,
                onChanged: (v) => setState(() => _pricesIncludeVat = v),
                title: const Text('Çmimet e menusë e përfshijnë TVSH-në'),
                subtitle: Text(
                  _pricesIncludeVat
                      ? 'TVSH-ja nxirret nga totali që paguan klienti '
                          '(rasti i zakonshëm në Kosovë).'
                      : 'TVSH-ja shtohet mbi çmimet e menusë — totali i '
                          'kuponit do të jetë më i lartë se ai në ekran.',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Njësia matëse',
                        hintText: 'cope',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _itemType,
                      decoration: const InputDecoration(
                        labelText: 'Kategoria e artikullit',
                        hintText: 'TT',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Çelësi privat (PKI)',
            subtitle:
                'Gjenerohet nga mjeti "onboarder" i ATK-së dhe nuk duhet të '
                'largohet kurrë nga ky kompjuter.',
            children: [
              TextField(
                controller: _privateKey,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                onChanged: (_) => _validateKey(),
                decoration: const InputDecoration(
                  labelText: 'private-key.pem',
                  hintText: '-----BEGIN EC PRIVATE KEY-----',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_keyStatus != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _keyOk ? Icons.check_circle_outline : Icons.error_outline,
                      size: 18,
                      color: _keyOk
                          ? AppColors.primaryGreen
                          : AppColors.negativeText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _keyStatus!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _keyOk
                              ? AppColors.primaryGreen
                              : AppColors.negativeText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _certificate,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'signed-certificate.pem (opsionale, për referencë)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Kuponët në pritje',
            subtitle:
                'Kuponë të lëshuar e të printuar që ATK ende nuk i ka pranuar '
                '(p.sh. pa internet). Ridërgohen automatikisht.',
            children: [
              Row(
                children: [
                  Text(
                    '$_pending',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: _pending == 0
                          ? AppColors.primaryGreen
                          : AppColors.negativeText,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _pending == 0
                          ? 'Të gjithë kuponët janë dërguar.'
                          : 'Ka kuponë që presin dërgim.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _retryPending,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Ridërgo tani'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Duke ruajtur...' : 'Ruaj cilësimet'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _warning(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negativeText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.negativeText.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 20, color: AppColors.negativeText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.negativeText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/developer_auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gg_header.dart';

/// Developer-only portal for extending an owner's license through the API.
class DeveloperLoginScreen extends StatefulWidget {
  const DeveloperLoginScreen({super.key});

  @override
  State<DeveloperLoginScreen> createState() => _DeveloperLoginScreenState();
}

class _DeveloperLoginScreenState extends State<DeveloperLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _licenseKey = TextEditingController();
  final _days = TextEditingController(text: '30');
  bool _english = true;
  bool _busy = false;
  String? _error;

  String t(String en, String sq) => _english ? en : sq;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _licenseKey.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final key = _licenseKey.text.trim();
    final days = int.tryParse(_days.text.trim());
    if (email.isEmpty || password.isEmpty || key.isEmpty || days == null) {
      setState(
        () => _error = t(
          'Enter email, password, license key and a valid number of days.',
          'Plotësoni email-in, fjalëkalimin, çelësin dhe ditët.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DeveloperAuthService.instance.login(
        email: email,
        password: password,
      );
      final result = await DeveloperAuthService.instance.extendLicense(
        licenseKey: key,
        days: days,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('License extended', 'Licenca u zgjat')),
          content: Text(
            '${t('New expiry', 'Skadimi i ri')}: ${result.licenseExpiresAt}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('Close', 'Mbyll')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _message(error));
      DeveloperAuthService.instance.logout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return t(
          'Invalid developer credentials or insufficient permissions.',
          'Kredenciale të pasakta ose pa leje të mjaftueshme.',
        );
      }
      if (status == 404) {
        return t('License key was not found.', 'Çelësi i licencës nuk u gjet.');
      }
      return t(
        'The licensing API is unavailable (HTTP ${status ?? '—'}).',
        'API-ja e licencimit nuk është e disponueshme (HTTP ${status ?? '—'}).',
      );
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final label = _english ? 'SQ' : 'EN';
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        title: Text(t('Developer license access', 'Hyrje për developer')),
        actions: [
          TextButton(
            onPressed: () => setState(() => _english = !_english),
            child: Text(label),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: GgLogoBox(size: 56, radius: 14)),
                    const SizedBox(height: 20),
                    Text(
                      t('Extend owner license', 'Zgjatni licencën e pronarit'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(
                        'Use your developer account to renew a customer license.',
                        'Përdorni llogarinë e developer-it për të rinovuar licencën.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: t('Developer email', 'Email i developer-it'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: t('Password', 'Fjalëkalimi'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _licenseKey,
                      decoration: InputDecoration(
                        labelText: t(
                          'Owner license key',
                          'Çelësi i licencës së pronarit',
                        ),
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _days,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('Days to add', 'Ditë për t’u shtuar'),
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.softRed),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              t(
                                'Login and extend license',
                                'Hyr dhe zgjat licencën',
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(t('Cancel', 'Anulo')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

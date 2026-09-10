import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/local_license_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gg_header.dart';

/// Developer-only portal for extending an owner's license through the API.
class DeveloperLoginScreen extends StatefulWidget {
  const DeveloperLoginScreen({super.key});

  @override
  State<DeveloperLoginScreen> createState() => _DeveloperLoginScreenState();
}

class _DeveloperLoginScreenState extends State<DeveloperLoginScreen> {
  final _ownerName = TextEditingController();
  final _days = TextEditingController(text: '30');
  bool _english = true;
  bool _busy = false;
  String? _error;

  String t(String en, String sq) => _english ? en : sq;

  @override
  void dispose() {
    _ownerName.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final owner = _ownerName.text.trim();
    final days = int.tryParse(_days.text.trim());
    if (owner.isEmpty || days == null) {
      setState(
        () => _error = t(
          'Enter the owner name and a valid number of days.',
          'Plotësoni emrin e pronarit dhe ditët.',
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
        ownerName: owner,
        days: days,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            t('Local license generated', 'Licenca lokale u gjenerua'),
          ),
          content: SelectableText(
            '${t('Give this code to the owner', 'Jepjani këtë kod pronarit')}:\n\n$key',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: key));
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(t('Copy code', 'Kopjo kodin')),
            ),
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
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _english ? 'SQ' : 'EN';
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        title: Text(t('Developer mode (offline)', 'Developer mode (offline)')),
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
                      t(
                        'Generate owner license code',
                        'Gjeneroni kodin e licencës',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(
                        'This works fully offline. Generate a code and give it to the owner.',
                        'Punon komplet offline. Gjeneroni kodin dhe jepjani pronarit.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ownerName,
                      decoration: InputDecoration(
                        labelText: t(
                          'Owner / business name',
                          'Emri i pronarit / biznesit',
                        ),
                        prefixIcon: const Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _days,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t(
                          'License duration in days',
                          'Kohëzgjatja në ditë',
                        ),
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
                                'Generate license code',
                                'Gjenero kodin e licencës',
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

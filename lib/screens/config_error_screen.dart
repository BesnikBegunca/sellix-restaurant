import 'package:flutter/material.dart';

import '../services/runtime_config_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// Full-screen blocker when release mode has no valid production API URL.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  void _showInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Si ta konfiguroni API-n'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr.configStep1,
              ),
              SizedBox(height: 12),
              Text('2. Vendosni URL-n e production (pa localhost), p.sh.:'),
              SizedBox(height: 8),
              SelectableText(
                '{\n'
                '  "apiBaseUrl": "https://your-api.example.com"\n'
                '}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(tr.configStep2),
              SizedBox(height: 12),
              Text(
                tr.instaluesiWindowsMundKopjojeAppConfig + tr.folderinInstalimitMosVendosniSekreteKete,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr.mbyll),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = RuntimeConfigService.instance;

    return Material(
      color: AppColors.beige,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.mutedOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 40,
                      color: AppColors.mutedOrange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    RuntimeConfigService.productionConfigErrorTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    RuntimeConfigService.productionConfigErrorBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.charcoalText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InfoCard(label: tr.burimi, value: config.sourceLabel),
                  const SizedBox(height: 8),
                  _InfoCard(
                    label: tr.urlAktuale,
                    value: config.apiBaseUrl,
                    monospace: true,
                  ),
                  const SizedBox(height: 8),
                  _InfoCard(
                    label: tr.skedariPritur,
                    value: config.expectedConfigFilePath,
                    monospace: true,
                  ),
                  const SizedBox(height: 8),
                  _InfoCard(
                    label: tr.skedariEkziston,
                    value: config.configFileExists
                        ? 'po'
                        : tr.joKopjoniAppConfigJsonKetu,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => onRetry(),
                      child: const Text('Riprovo konfigurimin'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _showInstructions(context),
                      child: Text(tr.shikoUdhezimet),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGreenBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGreenText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: monospace ? 12 : 14,
              fontFamily: monospace ? 'monospace' : null,
              color: AppColors.darkGreenText,
            ),
          ),
        ],
      ),
    );
  }
}

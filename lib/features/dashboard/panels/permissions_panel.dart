import 'package:flutter/material.dart';

import '../../../manager/manager_data.dart';
import '../../../services/app_language_service.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../widgets/settings/settings_card.dart';
import '../widgets/settings/settings_check_tile.dart';

class PermissionsPanel extends StatelessWidget {
  const PermissionsPanel({super.key, required this.m});

  final ManagerData m;

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.lock_outline_rounded,
          title: lang.t('Permissions', 'Permissions'),
          subtitle: lang.t(
            'Çfarë sheh kamarieri në ekranin e tavolinave. Menaxheri i sheh gjithmonë totalet.',
            'What waiters see on the tables screen. Managers always see totals.',
          ),
        ),
        SettingsCard(
          icon: Icons.visibility_off_outlined,
          title: lang.t('Totalet e tavolinave', 'Table totals'),
          subtitle: lang.t(
            'Fsheh shumat nga kamarieri. Printimi i faturës mbetet i njëjtë.',
            'Hide amounts from waiters. Printed receipts stay the same.',
          ),
          child: Column(
            children: [
              SettingsCheckTile(
                label: lang.t(
                  'Fsheh totalin e të gjitha tavolinave',
                  'Hide the total of all tables',
                ),
                description: lang.t(
                  'Kamarieri nuk e sheh shumën e përgjithshme në krye të ekranit.',
                  'Waiters will not see the grand total at the top of the floor.',
                ),
                value: m.hideWaiterGrandTotal,
                onChanged: (v) =>
                    m.saveWaiterVisibilitySettings(hideWaiterGrandTotal: v),
              ),
              const SizedBox(height: 8),
              SettingsCheckTile(
                label: lang.t(
                  'Fsheh totalin e çdo tavoline',
                  'Hide each table total',
                ),
                description: lang.t(
                  'Kamarieri nuk e sheh shumën në kartën e tavolinës, as te porosia.',
                  'Waiters will not see the amount on a table card or in the order.',
                ),
                value: m.hideWaiterTableTotals,
                onChanged: (v) =>
                    m.saveWaiterVisibilitySettings(hideWaiterTableTotals: v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

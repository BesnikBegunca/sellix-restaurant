import 'package:flutter/material.dart';

import '../screens/license_suspended_screen.dart';
import '../services/license_gate_service.dart';

/// Covers the app when [LicenseGateService] is blocked.
class LicenseBlockedOverlay extends StatelessWidget {
  const LicenseBlockedOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LicenseGateService.instance,
      builder: (context, _) {
        final blocked = LicenseGateService.instance.isBlocked;
        return Stack(
          children: [
            child,
            if (blocked) ...[
              const ModalBarrier(dismissible: false, color: Colors.black54),
              const Positioned.fill(child: LicenseSuspendedScreen()),
            ],
          ],
        );
      },
    );
  }
}

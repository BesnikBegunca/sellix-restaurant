import 'package:flutter/material.dart';

import '../services/activation_service.dart';
import '../services/activation_state_controller.dart';
import '../theme/app_colors.dart';
/// Full-screen state after SuperAdmin (or API) revokes this device.
///
/// Shown when [ActivationStateController.serverRevoked] is true.
/// Local SQLite business data is untouched.
class DeviceRevokedScreen extends StatelessWidget {
  const DeviceRevokedScreen({
    super.key,
    this.message,
  });

  final String? message;

  void _goToActivation() {
    ActivationStateController.instance.clearServerRevoked();
  }

  @override
  Widget build(BuildContext context) {
    final body =
        message ?? ActivationService.kDefaultServerRevokeMessage;

    return Material(
      color: AppColors.beige,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.negativeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.phonelink_erase_rounded,
                      size: 40,
                      color: AppColors.softRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pajisja u çaktivizua',
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
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.charcoalText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _goToActivation,
                      child: const Text('Shko te aktivizimi'),
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

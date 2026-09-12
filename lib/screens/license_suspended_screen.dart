import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/activation_service.dart';
import '../services/api_enforcement_parser.dart';
import '../services/license_gate_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// Full-screen block shown when the tenant license/business is suspended.
class LicenseSuspendedScreen extends StatefulWidget {
  const LicenseSuspendedScreen({super.key});

  @override
  State<LicenseSuspendedScreen> createState() => _LicenseSuspendedScreenState();
}

class _LicenseSuspendedScreenState extends State<LicenseSuspendedScreen> {
  bool _checking = false;
  String? _statusMessage;

  Future<void> _retryStatusCheck() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _statusMessage = null;
    });

    try {
      await ActivationService.instance.refreshActivationToken();
      final ok = await ActivationService.instance.verifyActivation();
      if (!mounted) return;

      if (ok && !LicenseGateService.instance.isBlocked) {
        await LicenseGateService.instance.unblock();
        return;
      }

      setState(() {
        _statusMessage =
            tr.licencaEshteEndePezulluarKontaktoniAdministratorin;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (await LicenseGateService.instance.handleDioException(e)) {
        setState(() {
          _statusMessage =
              tr.licencaEshteEndePezulluarKontaktoniAdministratorin;
        });
      } else if (ApiEnforcementParser.requiresDeviceRevoke(e)) {
        await ActivationService.instance.handleRevokedByServer(
          reason: ActivationService.messageForRevocation(e),
        );
        if (!mounted) return;
        return;
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        setState(() {
          _statusMessage = tr.nukKaLidhjeServerinProvoniSerish;
        });
      } else {
        setState(() {
          _statusMessage = tr.kontrolliDeshtoiProvoniSerish;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = tr.kontrolliDeshtoiProvoniSerish;
      });
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason =
        LicenseGateService.instance.reason ??
        tr.licencaEshtePezulluarKontaktoniAdministratorin;

    return Material(
      color: AppColors.beige,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                    child: Icon(
                      Icons.pause_circle_filled_rounded,
                      size: 40,
                      color: AppColors.softRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Aksesi i pezulluar',
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
                    reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.charcoalText,
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _checking ? null : _retryStatusCheck,
                      child: _checking
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Riprovo'),
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

import 'tenant_data_conflict.dart';

/// User choice from [showTenantDataConflictDialog].
enum TenantConflictDialogChoice {
  cancelled,
  wipeAndContinue,
  /// Debug/profile only — must not be offered in [kReleaseMode].
  keepLocalDebugOnly,
}

/// Result of [LocalTenantDataService.prepareForActivation].
class TenantActivationGateResult {
  const TenantActivationGateResult._({
    required this.action,
    this.conflict,
    this.error,
  });

  final TenantActivationGateAction action;
  final TenantDataConflict? conflict;
  final Object? error;

  /// Safe to call [ActivationService.activateDesktop] after this result.
  bool get canProceedToActivation =>
      action == TenantActivationGateAction.noConflict ||
      action == TenantActivationGateAction.wipeCompleted ||
      action == TenantActivationGateAction.keepLocalDebugOnly;

  factory TenantActivationGateResult.noConflict() =>
      const TenantActivationGateResult._(
        action: TenantActivationGateAction.noConflict,
      );

  factory TenantActivationGateResult.cancelled(TenantDataConflict conflict) =>
      TenantActivationGateResult._(
        action: TenantActivationGateAction.cancelled,
        conflict: conflict,
      );

  factory TenantActivationGateResult.wipeCompleted(TenantDataConflict conflict) =>
      TenantActivationGateResult._(
        action: TenantActivationGateAction.wipeCompleted,
        conflict: conflict,
      );

  factory TenantActivationGateResult.keepLocalDebugOnly(
    TenantDataConflict conflict,
  ) =>
      TenantActivationGateResult._(
        action: TenantActivationGateAction.keepLocalDebugOnly,
        conflict: conflict,
      );

  factory TenantActivationGateResult.wipeFailed(
    TenantDataConflict conflict,
    Object error,
  ) =>
      TenantActivationGateResult._(
        action: TenantActivationGateAction.wipeFailed,
        conflict: conflict,
        error: error,
      );
}

enum TenantActivationGateAction {
  noConflict,
  cancelled,
  wipeCompleted,
  wipeFailed,
  keepLocalDebugOnly,
}

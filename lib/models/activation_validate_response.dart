/// Deserialized response from POST /activation/validate-key.
class ActivationValidateResponse {
  const ActivationValidateResponse({
    required this.valid,
    this.businessId,
    this.businessName,
    this.branchId,
    this.branchName,
    this.branchCode,
    this.licenseStatus,
    this.licenseExpiresAt,
    this.message,
  });

  final bool valid;
  final String? businessId;
  final String? businessName;
  final String? branchId;
  final String? branchName;

  /// Present when the backend includes it; otherwise enter branch code manually.
  final String? branchCode;
  final String? licenseStatus;
  final String? licenseExpiresAt;
  final String? message;

  factory ActivationValidateResponse.fromJson(Map<String, dynamic> json) {
    return ActivationValidateResponse(
      valid: json['valid'] as bool? ?? false,
      businessId: json['businessId'] as String?,
      businessName: json['businessName'] as String?,
      branchId: json['branchId'] as String?,
      branchName: json['branchName'] as String?,
      branchCode: json['branchCode'] as String?,
      licenseStatus: json['licenseStatus'] as String?,
      licenseExpiresAt: json['licenseExpiresAt'] as String?,
      message: json['message'] as String?,
    );
  }
}

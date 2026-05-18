/// Deserialized response from POST /activation/desktop.
class ActivationResponse {
  const ActivationResponse({
    required this.businessId,
    required this.branchId,
    required this.deviceId,
    required this.accessToken,
    this.refreshToken,
    this.licenseExpiresAt,
  });

  final String businessId;
  final String branchId;

  /// Server-assigned device record ID (not the local device UUID).
  final String deviceId;

  final String accessToken;
  final String? refreshToken;

  /// ISO-8601 string or null if the license has no expiry.
  final String? licenseExpiresAt;

  factory ActivationResponse.fromJson(Map<String, dynamic> json) {
    return ActivationResponse(
      businessId: json['businessId'] as String,
      branchId: json['branchId'] as String,
      deviceId: json['deviceId'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      licenseExpiresAt: json['licenseExpiresAt'] as String?,
    );
  }
}

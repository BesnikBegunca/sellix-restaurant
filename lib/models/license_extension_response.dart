/// Result returned after a developer extends an owner's license.
class LicenseExtensionResponse {
  const LicenseExtensionResponse({
    required this.licenseExpiresAt,
    this.licenseKey,
  });

  final String licenseExpiresAt;
  final String? licenseKey;

  factory LicenseExtensionResponse.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['licenseExpiresAt'];
    if (expiresAt is! String || expiresAt.trim().isEmpty) {
      throw const FormatException(
        'License extension response has no expiry date',
      );
    }
    return LicenseExtensionResponse(
      licenseExpiresAt: expiresAt,
      licenseKey: json['licenseKey'] as String?,
    );
  }
}

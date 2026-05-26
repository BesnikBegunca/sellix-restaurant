/// Response from POST /activation/desktop when the license is already bound
/// to another device and transfer approval is required.
class DeviceTransferRequiredResponse {
  const DeviceTransferRequiredResponse({
    required this.licenseId,
    this.message,
    this.oldDeviceId,
    this.oldDeviceName,
  });

  final String licenseId;
  final String? message;

  /// Server-assigned device ID of the currently active device, if provided.
  final String? oldDeviceId;
  final String? oldDeviceName;

  factory DeviceTransferRequiredResponse.fromJson(Map<String, dynamic> json) {
    return DeviceTransferRequiredResponse(
      licenseId: json['licenseId'] as String? ?? '',
      message: json['message'] as String?,
      oldDeviceId: json['oldDeviceId'] as String?,
      oldDeviceName: json['oldDeviceName'] as String?,
    );
  }
}

/// Response from POST /licenses/request-transfer.
///
/// When [isDuplicate] is true, the server indicated a pending request already
/// exists for this license — the UI should show the same "pending" message.
class DeviceTransferResponse {
  const DeviceTransferResponse({
    required this.id,
    required this.status,
    this.businessId,
    this.licenseId,
    this.requestedAt,
    this.isDuplicate = false,
  });

  final String id;
  final String status;
  final String? businessId;
  final String? licenseId;
  final String? requestedAt;

  /// True when the server returned 409 (a pending request already exists).
  final bool isDuplicate;

  bool get isPending => status == 'pending' || isDuplicate;

  factory DeviceTransferResponse.fromJson(
    Map<String, dynamic> json, {
    bool isDuplicate = false,
  }) {
    return DeviceTransferResponse(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      businessId: json['businessId'] as String?,
      licenseId: json['licenseId'] as String?,
      requestedAt: json['requestedAt'] as String?,
      isDuplicate: isDuplicate,
    );
  }
}

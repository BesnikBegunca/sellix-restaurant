import '../models/device_transfer_response.dart';

/// Thrown by [ActivationService.activateDesktop] when the license is already
/// bound to another device and a transfer request has been sent to the server.
///
/// This is not an error — it means the request was submitted successfully.
/// The UI should show a pending-approval message and NOT persist any tokens.
class DeviceTransferRequiredException implements Exception {
  const DeviceTransferRequiredException(this.transferResponse);

  final DeviceTransferResponse transferResponse;

  /// True when the server reported a pending request already exists (409).
  bool get isDuplicate => transferResponse.isDuplicate;

  @override
  String toString() =>
      'DeviceTransferRequiredException(status=${transferResponse.status}, '
      'isDuplicate=$isDuplicate)';
}

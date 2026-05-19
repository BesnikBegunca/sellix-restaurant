import 'package:flutter/foundation.dart';

/// Global activation gate for [MaterialApp] home routing.
///
/// Updated by [ActivationService] when tokens are cleared or restored.
/// Unlike a one-shot `activated` flag at startup, this allows the app to
/// return to [ActivationScreen] (or [DeviceRevokedScreen]) without restart
/// when the server revokes the device mid-session.
class ActivationStateController extends ChangeNotifier {
  ActivationStateController._();
  static final ActivationStateController instance = ActivationStateController._();

  bool _isActivated = false;

  /// When true, show [DeviceRevokedScreen] before [ActivationScreen].
  bool _serverRevoked = false;
  String? _serverRevokeMessage;

  bool get isActivated => _isActivated;
  bool get serverRevoked => _serverRevoked;
  String? get serverRevokeMessage => _serverRevokeMessage;

  void setActivated(bool value) {
    if (_isActivated == value && !value && !_serverRevoked) return;
    _isActivated = value;
    if (value) {
      _serverRevoked = false;
      _serverRevokeMessage = null;
    }
    notifyListeners();
  }

  /// Called after [ActivationService.handleRevokedByServer] clears tokens.
  void notifyServerRevoked(String message) {
    _isActivated = false;
    _serverRevoked = true;
    _serverRevokeMessage = message;
    notifyListeners();
  }

  /// User chose to continue to activation from [DeviceRevokedScreen].
  void clearServerRevoked() {
    _serverRevoked = false;
    _serverRevokeMessage = null;
    notifyListeners();
  }
}

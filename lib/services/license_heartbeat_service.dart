import 'dart:async';

import 'package:flutter/foundation.dart';

import 'activation_service.dart';
import 'connectivity_service.dart';
import 'license_gate_service.dart';

/// Live license watchdog.
///
/// Polls `POST /api/license/check` on a short timer while the app runs, so the
/// portal and the till never drift apart:
///
/// * revoked / expired / suspended → [LicenseGateService] blocks within
///   seconds and [LicenseBlockedOverlay] covers the whole app;
/// * re-activated or extended → the next tick lifts the block and writes the
///   new expiry, so work continues with no restart and no key re-entry;
/// * offline → falls back to the locally stored expiry, so a license that runs
///   out with no connection still stops the app on time.
class LicenseHeartbeatService extends ChangeNotifier {
  LicenseHeartbeatService._();
  static final LicenseHeartbeatService instance = LicenseHeartbeatService._();

  /// Cadence while the license is healthy.
  static const Duration kActiveInterval = Duration(seconds: 15);

  /// Cadence while the app is blocked — a re-activation must land fast.
  static const Duration kBlockedInterval = Duration(seconds: 8);

  /// Cadence after a network failure (cheap retry, no hammering).
  static const Duration kOfflineInterval = Duration(seconds: 30);

  /// Cadence after the server answered `rate_limited`.
  static const Duration kThrottledInterval = Duration(minutes: 2);

  Timer? _timer;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  bool _running = false;
  bool _inFlight = false;
  Duration _interval = kActiveInterval;
  DateTime? _lastCheckAt;
  DateTime? _lastOkAt;

  /// `true` between [start] and [stop].
  bool get isRunning => _running;

  /// `true` while a check is in flight (drives the retry spinner).
  bool get isChecking => _inFlight;

  /// Current poll cadence.
  Duration get interval => _interval;

  DateTime? get lastCheckAt => _lastCheckAt;

  /// Last time the server confirmed the license was valid.
  DateTime? get lastOkAt => _lastOkAt;

  /// Starts polling. Safe to call twice.
  ///
  /// Keeps running while the gate is blocked — that is what makes a
  /// re-activation resume the app on its own. Pass
  /// [checkImmediately] `false` when the caller has just run a check itself
  /// (startup, first activation) so the first beat waits out the interval.
  void start({bool checkImmediately = true}) {
    if (_running) return;
    _running = true;
    _connectivitySub ??= ConnectivityService.instance.onStatusChanged.listen((
      status,
    ) {
      if (status == ConnectivityStatus.online) unawaited(checkNow());
    });
    _reschedule();
    if (checkImmediately) unawaited(checkNow());
    if (kDebugMode) {
      debugPrint('LicenseHeartbeatService: started (every ${_interval.inSeconds}s)');
    }
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = null;
    notifyListeners();
    if (kDebugMode) debugPrint('LicenseHeartbeatService: stopped');
  }

  /// Runs one license check now.
  ///
  /// Returns `true` when the license is serving. [manual] lets the blocked
  /// screen's retry button run a check even if the heartbeat was stopped.
  Future<bool> checkNow({bool manual = false}) async {
    if (!_running && !manual) return false;
    if (_inFlight) return false;

    if (!ActivationService.instance.isActivated) {
      stop();
      return false;
    }

    if (!ConnectivityService.instance.isOnline) {
      // No server to ask — enforce the expiry we already know about.
      await LicenseGateService.instance.checkAndBlockIfLocallyExpired();
      _lastCheckAt = DateTime.now();
      _reschedule();
      notifyListeners();
      return !LicenseGateService.instance.isBlocked;
    }

    _inFlight = true;
    notifyListeners();

    var ok = false;
    try {
      ok = await ActivationService.instance.verifyActivation(force: true);
    } catch (e) {
      if (kDebugMode) debugPrint('LicenseHeartbeatService: check failed — $e');
    } finally {
      _inFlight = false;
      _lastCheckAt = DateTime.now();
      if (ok) _lastOkAt = _lastCheckAt;
      _reschedule();
      notifyListeners();
    }
    return ok;
  }

  void _reschedule() {
    _timer?.cancel();
    if (!_running) return;
    _interval = nextInterval();
    _timer = Timer(_interval, () => unawaited(checkNow()));
  }

  /// Cadence for the next beat: fast while blocked, slow while throttled.
  @visibleForTesting
  Duration nextInterval() {
    final reason = ActivationService.instance.lastCheckReason;
    if (reason == 'rate_limited') return kThrottledInterval;
    if (LicenseGateService.instance.isBlocked) return kBlockedInterval;
    if (reason == 'network') return kOfflineInterval;
    return kActiveInterval;
  }

  @visibleForTesting
  void debugReset() {
    stop();
    _inFlight = false;
    _interval = kActiveInterval;
    _lastCheckAt = null;
    _lastOkAt = null;
  }
}

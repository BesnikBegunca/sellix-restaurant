/// Tracks admin session idle time and locks the dashboard after inactivity.
///
/// State is in-memory only — not persisted to SQLite.
/// Call [reset] when the dashboard is first opened, [recordActivity] on every
/// user interaction, and [checkAndLock] on a periodic timer to detect expiry.
class AdminSessionService {
  AdminSessionService._();
  static final AdminSessionService instance = AdminSessionService._();

  static const Duration idleTimeout = Duration(minutes: 10);

  DateTime _lastActivity = DateTime.now();
  bool _locked = false;

  bool get isLocked => _locked;

  /// Record a user interaction — resets the idle clock.
  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  /// Returns true if the session is (or just became) locked.
  /// Sets the internal locked flag on first expiry.
  bool checkAndLock() {
    if (_locked) return true;
    if (DateTime.now().difference(_lastActivity) >= idleTimeout) {
      _locked = true;
      return true;
    }
    return false;
  }

  /// Unlock and reset the idle clock after successful re-authentication.
  void unlock() {
    _locked = false;
    _lastActivity = DateTime.now();
  }

  /// Full reset — call when opening the dashboard (fresh login) or on logout.
  void reset() {
    _locked = false;
    _lastActivity = DateTime.now();
  }
}

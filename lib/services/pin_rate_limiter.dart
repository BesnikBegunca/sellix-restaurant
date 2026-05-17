/// In-memory PIN attempt rate limiter shared across all login screens.
/// State persists for the lifetime of the app session; not written to SQLite.
class PinRateLimiter {
  PinRateLimiter._();
  static final PinRateLimiter instance = PinRateLimiter._();

  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 60);

  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  /// True while the lockout window is active. Auto-resets when the window expires.
  bool get isLocked {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isBefore(_lockedUntil!)) return true;
    _lockedUntil = null;
    _failedAttempts = 0;
    return false;
  }

  /// Attempts remaining before lockout triggers (0 during lockout).
  int get remainingAttempts => (maxAttempts - _failedAttempts).clamp(0, maxAttempts);

  /// Whole seconds remaining in the current lockout window (0 if not locked).
  int get lockoutSecondsRemaining {
    if (_lockedUntil == null) return 0;
    final diff = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  /// Record one failed attempt. Returns true if this attempt triggered a lockout.
  bool recordFailure() {
    if (isLocked) return false;
    _failedAttempts++;
    if (_failedAttempts >= maxAttempts) {
      _lockedUntil = DateTime.now().add(lockoutDuration);
      return true;
    }
    return false;
  }

  /// Reset on successful authentication.
  void reset() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}

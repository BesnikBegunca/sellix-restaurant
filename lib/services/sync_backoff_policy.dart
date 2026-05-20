import 'dart:math' as math;

/// Exponential backoff with jitter for background sync retries.
class SyncBackoffPolicy {
  SyncBackoffPolicy({math.Random? random}) : _random = random ?? math.Random();

  static const int maxAttempts = 8;
  static const Duration baseDelay = Duration(seconds: 2);
  static const Duration maxDelay = Duration(minutes: 5);

  /// Fast retries before exponential backoff (2s → 5s → 10s).
  static const List<Duration> fastRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  final math.Random _random;

  int _failureCount = 0;
  DateTime? _nextRetryAt;

  int get failureCount => _failureCount;

  DateTime? get nextRetryAt => _nextRetryAt;

  bool get exhausted => _failureCount >= maxAttempts;

  /// Delay before next retry: [fastRetryDelays] first, then exponential (capped).
  Duration get currentDelay {
    if (_failureCount <= 0) return Duration.zero;
    if (_failureCount <= fastRetryDelays.length) {
      return fastRetryDelays[_failureCount - 1];
    }
    final exponent = math.min(_failureCount - fastRetryDelays.length, 10);
    var delay = baseDelay * (1 << exponent);
    if (delay > maxDelay) delay = maxDelay;
    return delay;
  }

  /// Full jitter: random in [50%, 100%] of [currentDelay].
  Duration get delayWithJitter {
    final base = currentDelay;
    if (base <= Duration.zero) return Duration.zero;
    final ms = base.inMilliseconds;
    final low = (ms * 0.5).round();
    final span = ms - low;
    return Duration(milliseconds: low + _random.nextInt(span + 1));
  }

  /// `true` when no backoff is active or the wait window has elapsed.
  bool get isReady {
    if (_failureCount <= 0) return true;
    if (_nextRetryAt == null) return true;
    return DateTime.now().isAfter(_nextRetryAt!);
  }

  Duration? get remainingDelay {
    if (_nextRetryAt == null) return null;
    final rem = _nextRetryAt!.difference(DateTime.now());
    if (rem.isNegative) return Duration.zero;
    return rem;
  }

  /// Increments failure count and schedules [nextRetryAt].
  void recordFailure() {
    if (_failureCount < maxAttempts) {
      _failureCount++;
    }
    final wait = delayWithJitter;
    _nextRetryAt = DateTime.now().add(wait);
  }

  void reset() {
    _failureCount = 0;
    _nextRetryAt = null;
  }
}

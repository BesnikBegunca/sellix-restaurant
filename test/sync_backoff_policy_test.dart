import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/services/sync_backoff_policy.dart';

void main() {
  group('SyncBackoffPolicy', () {
    test('currentDelay grows exponentially and caps', () {
      final policy = SyncBackoffPolicy(random: _FakeRandom(0.9));
      expect(policy.currentDelay, Duration.zero);

      policy.recordFailure();
      expect(policy.currentDelay, const Duration(seconds: 2));

      for (var i = 0; i < 7; i++) {
        policy.recordFailure();
      }
      // failures 1–3: fast tier; 4+ exponential from baseDelay
      expect(policy.failureCount, SyncBackoffPolicy.maxAttempts);
      expect(policy.currentDelay, const Duration(seconds: 64));
    });

    test('delayWithJitter is within 50-100% of base', () {
      final policy = SyncBackoffPolicy(random: _FakeRandom(0.0));
      policy.recordFailure();
      final baseMs = policy.currentDelay.inMilliseconds;
      final jitterMs = policy.delayWithJitter.inMilliseconds;
      expect(jitterMs, greaterThanOrEqualTo((baseMs * 0.5).round()));
      expect(jitterMs, lessThanOrEqualTo(baseMs));
    });

    test('fast first retry is 2 seconds', () {
      final policy = SyncBackoffPolicy(random: _FakeRandom(0.0));
      policy.recordFailure();
      expect(policy.currentDelay, const Duration(seconds: 2));
    });

    test('isReady false until nextRetryAt elapses', () async {
      final policy = SyncBackoffPolicy(random: _FakeRandom(0.0));
      policy.recordFailure();
      expect(policy.isReady, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(policy.isReady, isTrue);
    });

    test('reset clears backoff', () {
      final policy = SyncBackoffPolicy(random: _FakeRandom(0.0));
      policy.recordFailure();
      expect(policy.isReady, isFalse);
      policy.reset();
      expect(policy.isReady, isTrue);
      expect(policy.failureCount, 0);
    });
  });
}

/// Deterministic random for jitter tests.
class _FakeRandom implements Random {
  _FakeRandom(this._value);
  final double _value;

  @override
  double nextDouble() => _value;

  @override
  int nextInt(int max) =>
      (max * _value).floor().clamp(0, max > 0 ? max - 1 : 0);

  @override
  bool nextBool() => _value >= 0.5;
}

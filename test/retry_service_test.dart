import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/core/network/retry_service.dart';
import 'dart:async';

void main() {
  group('Retry Service', () {
    test(
      'Successful operation on first attempt returns result immediately',
      () async {
        int calls = 0;
        final result = await withRetry(() async {
          calls++;
          return 'success';
        });
        expect(result, 'success');
        expect(calls, 1);
      },
    );

    test('Failed operation retries maxAttempts before throwing', () async {
      int calls = 0;
      final config = RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 10),
      );

      try {
        await withRetry(() async {
          calls++;
          throw Exception('fail');
        }, config: config);
        fail('Should have thrown');
      } catch (e) {
        expect(e.toString(), contains('fail'));
      }
      expect(calls, 3);
    });

    test('Exponential backoff increases delay', () async {
      final List<Duration> delays = [];
      final config = RetryConfig(
        maxAttempts: 4,
        initialDelay: Duration(milliseconds: 100),
        multiplier: 2.0,
        jitterFactor: 0.0, // Disable jitter for predictable test
      );

      try {
        await withRetry(
          () async => throw Exception('fail'),
          config: config,
          onRetry: (attempt, error, nextDelay) {
            delays.add(nextDelay);
          },
        );
      } catch (_) {}

      expect(delays.length, 3);
      expect(delays[0].inMilliseconds, closeTo(100, 1));
      expect(delays[1].inMilliseconds, closeTo(200, 1));
      expect(delays[2].inMilliseconds, closeTo(400, 1));
    });

    test('Non-retryable errors fail immediately', () async {
      int calls = 0;
      final config = RetryConfig(
        isRetryable: (e) => e.toString().contains('retryable'),
      );

      try {
        await withRetry(() async {
          calls++;
          throw Exception('permanent failure');
        }, config: config);
        fail('Should have thrown');
      } catch (_) {}

      expect(calls, 1);
    });
  });
}

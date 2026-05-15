import 'dart:async';
import 'dart:math';

/// Configuration for retry behavior
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;
  final double jitterFactor;
  final bool Function(Object error)? isRetryable;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 32),
    this.multiplier = 2.0,
    this.jitterFactor = 0.25,
    this.isRetryable,
  });

  /// Default isRetryable logic: retry on TimeoutException or common network errors
  bool shouldRetry(Object error) {
    if (isRetryable != null) return isRetryable!(error);
    return error is Exception || error is TimeoutException;
  }
}

/// Execute operation with exponential backoff retry
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
  void Function(int attempt, Object error, Duration nextDelay)? onRetry,
}) async {
  int attempt = 0;
  final random = Random();

  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= config.maxAttempts || !config.shouldRetry(e)) {
        rethrow;
      }

      // Calculate delay: initialDelay * (multiplier ^ (attempt - 1))
      final baseDelayMs =
          config.initialDelay.inMilliseconds *
          pow(config.multiplier, attempt - 1);

      // Apply jitter: ±jitterFactor * baseDelay
      final jitterRange = baseDelayMs * config.jitterFactor;
      final jitter = (random.nextDouble() * 2 - 1) * jitterRange;

      final finalDelayMs = (baseDelayMs + jitter).round().clamp(
        0,
        config.maxDelay.inMilliseconds,
      );

      final nextDelay = Duration(milliseconds: finalDelayMs);

      if (onRetry != null) {
        onRetry(attempt, e, nextDelay);
      }

      await Future.delayed(nextDelay);
    }
  }
}

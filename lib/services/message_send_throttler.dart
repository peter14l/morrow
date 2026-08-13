import 'dart:async';

/// Serializes `send_message_v3` RPC calls app-wide so the server-side
/// rate limit (1 message per second per user) is never exceeded.
///
/// The server enforces this via
/// `check_rate_limit(user_id, 'send_message', 1, '1 second')`, keyed on the
/// *sender* (not the conversation), so every send path must share a single
/// [MessageSendThrottler] instance.
class MessageSendThrottler {
  MessageSendThrottler({
    this.minInterval = const Duration(milliseconds: 1200),
  });

  /// Shared app-wide instance used by all send paths.
  static final MessageSendThrottler instance = MessageSendThrottler();

  /// Minimum gap enforced between the start of consecutive sends.
  final Duration minInterval;

  Future<void> _tail = Future<void>.value();
  DateTime _nextAvailable = DateTime.fromMillisecondsSinceEpoch(0);

  /// Runs [task] when its turn arrives, keeping at least [minInterval]
  /// between consecutive send starts.
  ///
  /// Tasks are serialized: a send never overlaps another, and each send
  /// starts no sooner than [minInterval] after the previous one.
  Future<T> enqueue<T>(Future<T> Function() task) {
    final completer = Completer<void>();
    final previous = _tail;
    _tail = completer.future;

    return previous.then((_) async {
      final now = DateTime.now();
      final wait = _nextAvailable.difference(now);
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
      _nextAvailable = DateTime.now().add(minInterval);
      try {
        return await task();
      } finally {
        completer.complete();
      }
    });
  }
}

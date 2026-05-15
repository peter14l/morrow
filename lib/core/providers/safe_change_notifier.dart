import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// A mixin that adds a disposal check and build-phase safety to [ChangeNotifier.notifyListeners].
/// This prevents "A ... was used after being disposed" and
/// "setState() or markNeedsBuild() called when widget tree was locked" errors.
mixin SafeChangeNotifier on ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  @mustCallSuper
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;

    // Check if we are in a phase where we can't notify listeners (e.g. during build or finalizeTree)
    final scheduler = WidgetsBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // Defer notification to the end of the frame
      scheduler.addPostFrameCallback((_) {
        if (!_isDisposed) {
          super.notifyListeners();
        }
      });
    } else {
      super.notifyListeners();
    }
  }

  /// A helper to run async tasks only if the provider is still active.
  Future<void> runSafe(AsyncCallback task) async {
    if (_isDisposed) return;
    await task();
  }
}

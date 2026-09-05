import 'dart:async';
import 'package:flutter/foundation.dart';

/// Power profile mode for adaptive CPU/GPU optimization.
enum PowerMode {
  normal,
  lowPower,
  thermalThrottled,
}

/// System-wide coordinator to throttle heavy background timers, animations,
/// WebRTC simulcast layers, and mesh gradients to conserve device battery and maintain smoothness.
class PowerManager extends ChangeNotifier {
  static final PowerManager instance = PowerManager._internal();
  factory PowerManager() => instance;
  PowerManager._internal();

  PowerMode _mode = PowerMode.normal;
  bool _isBackgrounded = false;
  bool _isScrolling = false;

  PowerMode get mode => _mode;
  bool get isBackgrounded => _isBackgrounded;
  bool get isScrolling => _isScrolling;

  /// Whether animations and heavy GPU shaders should pause/throttle
  bool get shouldThrottleEffects =>
      _mode != PowerMode.normal || _isBackgrounded || _isScrolling;

  /// Target FPS recommendation based on current power mode
  int get recommendedFps {
    if (_isBackgrounded) return 0;
    switch (_mode) {
      case PowerMode.thermalThrottled:
        return 30;
      case PowerMode.lowPower:
        return 45;
      case PowerMode.normal:
        return 60;
    }
  }

  void setPowerMode(PowerMode mode) {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
  }

  void setBackgrounded(bool isBackgrounded) {
    if (_isBackgrounded != isBackgrounded) {
      _isBackgrounded = isBackgrounded;
      notifyListeners();
    }
  }

  void setScrolling(bool isScrolling) {
    if (_isScrolling != isScrolling) {
      _isScrolling = isScrolling;
      notifyListeners();
    }
  }
}

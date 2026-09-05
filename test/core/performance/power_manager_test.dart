import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/core/performance/power_manager.dart';

void main() {
  group('PowerManager Battery & Thermal Optimization Tests', () {
    late PowerManager powerManager;

    setUp(() {
      powerManager = PowerManager();
      powerManager.setPowerMode(PowerMode.normal);
      powerManager.setBackgrounded(false);
      powerManager.setScrolling(false);
    });

    test('Initial normal power state recommends 60fps and does not throttle', () {
      expect(powerManager.mode, equals(PowerMode.normal));
      expect(powerManager.isBackgrounded, isFalse);
      expect(powerManager.isScrolling, isFalse);
      expect(powerManager.shouldThrottleEffects, isFalse);
      expect(powerManager.recommendedFps, equals(60));
    });

    test('Low power mode reduces recommendation to 45fps and throttles effects', () {
      powerManager.setPowerMode(PowerMode.lowPower);
      expect(powerManager.shouldThrottleEffects, isTrue);
      expect(powerManager.recommendedFps, equals(45));
    });

    test('Thermal throttled mode drops fps recommendation to 30fps', () {
      powerManager.setPowerMode(PowerMode.thermalThrottled);
      expect(powerManager.shouldThrottleEffects, isTrue);
      expect(powerManager.recommendedFps, equals(30));
    });

    test('Backgrounding pauses fps and throttles heavy background effects immediately', () {
      powerManager.setBackgrounded(true);
      expect(powerManager.isBackgrounded, isTrue);
      expect(powerManager.shouldThrottleEffects, isTrue);
      expect(powerManager.recommendedFps, equals(0));
    });

    test('Fast scrolling throttles heavy background shaders to preserve 120/60fps frame rate', () {
      powerManager.setScrolling(true);
      expect(powerManager.isScrolling, isTrue);
      expect(powerManager.shouldThrottleEffects, isTrue);
    });
  });
}

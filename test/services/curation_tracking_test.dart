import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:oasis/services/curation_tracking_service.dart';

void main() {
  // Initialize ffi for sqflite in tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('CurationTrackingService', () {
    late CurationTrackingService service;

    setUp(() async {
      service = CurationTrackingService();
      // Ensure we start with a clean state for each test if possible,
      // but since we are using the service's internal DB, we'll just clear it.
      await service.clearAllData();
    });

    test('should track category interactions', () async {
      await service.trackCategoryInteraction('tech');
      await service.trackCategoryInteraction('tech');

      final top = await service.getTopCategories();
      expect(top, contains('tech'));
    });

    test('should track post likes', () async {
      await service.trackPostLike('art', 'post_1');

      final top = await service.getTopCategories();
      expect(top, contains('art'));
    });

    test('should track time spent', () async {
      await service.trackTimeSpent('music', 120);

      final summary = await service.getTrackingSummary();
      expect(summary['total_time_seconds'], equals(120));
    });

    test('should calculate top categories based on multiple factors', () async {
      // Art: 1 like (2.0) + 1 interaction (1.0) = 3.0
      await service.trackPostLike('art', 'p1');

      // Tech: 4 interactions (4.0) = 4.0
      await service.trackCategoryInteraction('tech', weight: 4);

      // Music: 50 seconds (5.0) = 5.0
      await service.trackTimeSpent('music', 50);

      final top = await service.getTopCategories(limit: 3);
      expect(top[0], equals('music')); // 5.0
      expect(top[1], equals('tech')); // 4.0
      expect(top[2], equals('art')); // 3.0
    });

    test('should clear all data', () async {
      await service.trackCategoryInteraction('news');
      await service.clearAllData();

      final top = await service.getTopCategories();
      expect(top, isEmpty);
    });
  });
}

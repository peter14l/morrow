import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/services/screen_time_service.dart';

void main() {
  group('ScreenTimeService', () {
    late ScreenTimeService screenTimeService;

    setUp(() async {
      // Set up mock shared preferences
      SharedPreferences.setMockInitialValues({});
      screenTimeService = await ScreenTimeService.init();
    });

    tearDown(() {
      screenTimeService.dispose();
    });

    group('Initialization', () {
      test('should initialize with empty usage data', () async {
        final usage = screenTimeService.getDailyUsage(DateTime.now());
        expect(usage['totalMinutes'], equals(0));
        expect(usage['hourlyBreakdown'], isA<List<int>>());
        expect((usage['hourlyBreakdown'] as List).length, equals(24));
      });

      test('should create service successfully', () async {
        expect(screenTimeService, isNotNull);
      });
    });

    group('Tracking', () {
      test('should start tracking without error', () {
        expect(() => screenTimeService.startTracking(), returnsNormally);
      });

      test('should stop tracking without error', () async {
        screenTimeService.startTracking();
        await screenTimeService.stopTracking();
        // No exception means success
      });

      test('should handle stopping without starting', () async {
        // Should not throw when stopping without starting
        await screenTimeService.stopTracking();
      });
    });

    group('Daily Usage', () {
      test('should return zero usage for a day with no data', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 30));
        final usage = screenTimeService.getDailyUsage(pastDate);
        expect(usage['totalMinutes'], equals(0));
      });

      test('should return hourly breakdown with 24 entries', () {
        final usage = screenTimeService.getDailyUsage(DateTime.now());
        final hourlyBreakdown = usage['hourlyBreakdown'] as List<int>;
        expect(hourlyBreakdown.length, equals(24));
      });
    });

    group('Weekly Data', () {
      test('should return 7 days of data', () {
        final weeklyData = screenTimeService.getWeeklyData();
        expect(weeklyData.length, equals(7));
      });

      test('should include day names', () {
        final weeklyData = screenTimeService.getWeeklyData();
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

        for (final entry in weeklyData) {
          expect(dayNames, contains(entry['day']));
        }
      });

      test('should include date objects', () {
        final weeklyData = screenTimeService.getWeeklyData();

        for (final entry in weeklyData) {
          expect(entry['date'], isA<DateTime>());
        }
      });
    });

    group('Weekly Average', () {
      test('should return zero when no data exists', () {
        final average = screenTimeService.getWeeklyAverage();
        expect(average, equals(0));
      });
    });

    group('Category Usage', () {
      test('should return empty list for zero minutes', () {
        final categories = screenTimeService.getCategoryUsage(0);
        expect(categories, isEmpty);
      });

      test('should return 5 categories for non-zero usage', () {
        final categories = screenTimeService.getCategoryUsage(100);
        expect(categories.length, equals(5));
      });

      test('should include expected category names', () {
        final categories = screenTimeService.getCategoryUsage(100);
        final categoryNames = categories.map((c) => c['name']).toList();

        expect(categoryNames, contains('Feed'));
        expect(categoryNames, contains('Messages'));
        expect(categoryNames, contains('Communities'));
        expect(categoryNames, contains('Profile'));
        expect(categoryNames, contains('Other'));
      });

      test('should distribute minutes across categories', () {
        const totalMinutes = 100;
        final categories = screenTimeService.getCategoryUsage(totalMinutes);

        int sum = 0;
        for (final category in categories) {
          sum += category['minutes'] as int;
        }

        expect(sum, equals(totalMinutes));
      });
    });
  });
}

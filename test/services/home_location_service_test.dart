import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/services/home_location_service.dart';
import 'package:oasis/core/storage/prefs_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsStorage.init();
  });

  group('HomeLocationService', () {
    late HomeLocationService service;
    late PrefsStorage prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PrefsStorage.init();
      prefs = PrefsStorage();
      service = HomeLocationService(prefs);
    });

    test('getHomeLocation returns null when no location set', () async {
      final result = await service.getHomeLocation();
      expect(result, isNull);
    });

    test('setHomeLocation stores and retrieves correctly', () async {
      await service.setHomeLocation(
        37.7749,
        -122.4194,
        address: 'San Francisco',
      );

      final result = await service.getHomeLocation();

      expect(result, isNotNull);
      expect(result!.latitude, equals(37.7749));
      expect(result.longitude, equals(-122.4194));
      expect(result.address, equals('San Francisco'));
    });

    test('setHomeLocation without address stores correctly', () async {
      await service.setHomeLocation(34.0522, -118.2437);

      final result = await service.getHomeLocation();

      expect(result, isNotNull);
      expect(result!.latitude, equals(34.0522));
      expect(result.longitude, equals(-118.2437));
      expect(result.address, isNull);
    });

    test('clearHomeLocation removes stored location', () async {
      await service.setHomeLocation(37.7749, -122.4194);
      await service.clearHomeLocation();

      final result = await service.getHomeLocation();
      expect(result, isNull);
    });

    test('hasHomeLocation returns false when no location set', () async {
      final hasLocation = await service.hasHomeLocation();
      expect(hasLocation, isFalse);
    });

    test('hasHomeLocation returns true when location is set', () async {
      await service.setHomeLocation(37.7749, -122.4194);

      final hasLocation = await service.hasHomeLocation();
      expect(hasLocation, isTrue);
    });

    test('setHomeLocation with same coordinates updates timestamp', () async {
      await service.setHomeLocation(37.7749, -122.4194);
      final first = await service.getHomeLocation();
      expect(first, isNotNull);

      // Wait a small amount to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 10));

      await service.setHomeLocation(37.7749, -122.4194);
      final second = await service.getHomeLocation();
      expect(second, isNotNull);

      expect(second!.timestamp.isAfter(first!.timestamp), isTrue);
    });

    test('setHomeLocation validates latitude range', () async {
      expect(
        () => service.setHomeLocation(91.0, -122.4194),
        throwsA(isA<AssertionError>()),
      );
    });

    test('setHomeLocation validates longitude range', () async {
      expect(
        () => service.setHomeLocation(37.7749, 181.0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

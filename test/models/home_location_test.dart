import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/models/home_location.dart';

void main() {
  group('HomeLocation', () {
    test('creates with required parameters', () {
      final homeLocation = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15, 10, 30),
      );

      expect(homeLocation.latitude, equals(37.7749));
      expect(homeLocation.longitude, equals(-122.4194));
      expect(homeLocation.timestamp, equals(DateTime(2024, 1, 15, 10, 30)));
      expect(homeLocation.address, isNull);
    });

    test('creates with optional address', () {
      final homeLocation = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15),
        address: '123 Main St, San Francisco, CA',
      );

      expect(homeLocation.address, equals('123 Main St, San Francisco, CA'));
    });

    test('serializes to JSON correctly', () {
      final homeLocation = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15, 10, 30),
        address: 'Test Address',
      );

      final json = homeLocation.toJson();

      expect(json['latitude'], equals(37.7749));
      expect(json['longitude'], equals(-122.4194));
      expect(json['timestamp'], equals('2024-01-15T10:30:00.000'));
      expect(json['address'], equals('Test Address'));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'latitude': 37.7749,
        'longitude': -122.4194,
        'timestamp': '2024-01-15T10:30:00.000',
        'address': 'Test Address',
      };

      final homeLocation = HomeLocation.fromJson(json);

      expect(homeLocation.latitude, equals(37.7749));
      expect(homeLocation.longitude, equals(-122.4194));
      expect(homeLocation.timestamp, equals(DateTime(2024, 1, 15, 10, 30)));
      expect(homeLocation.address, equals('Test Address'));
    });

    test('round-trips through JSON serialization', () {
      final original = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15),
        address: '123 Main St',
      );

      final restored = HomeLocation.fromJson(original.toJson());

      expect(restored.latitude, equals(original.latitude));
      expect(restored.longitude, equals(original.longitude));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.address, equals(original.address));
    });

    test('distanceTo calculates correct Haversine distance', () {
      final sanFrancisco = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15),
      );
      final losAngeles = HomeLocation(
        latitude: 34.0522,
        longitude: -118.2437,
        timestamp: DateTime(2024, 1, 15),
      );

      final distance = sanFrancisco.distanceTo(losAngeles);

      // San Francisco to Los Angeles is approximately 559 km
      expect(distance, closeTo(559, 10)); // Allow 10km tolerance
    });

    test('distanceTo same location returns zero', () {
      final location = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15),
      );

      final distance = location.distanceTo(location);

      expect(distance, equals(0));
    });

    test('copyWith creates new instance with updated values', () {
      final original = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15),
        address: 'Original Address',
      );

      final updated = original.copyWith(address: 'New Address');

      expect(updated.latitude, equals(original.latitude));
      expect(updated.longitude, equals(original.longitude));
      expect(updated.timestamp, equals(original.timestamp));
      expect(updated.address, equals('New Address'));
      expect(
        original.address,
        equals('Original Address'),
      ); // Original unchanged
    });

    test('copyWith with no parameters returns equivalent copy', () {
      final original = HomeLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime(2024, 1, 15),
        address: 'Test',
      );

      final copy = original.copyWith();

      expect(copy.latitude, equals(original.latitude));
      expect(copy.longitude, equals(original.longitude));
      expect(copy.timestamp, equals(original.timestamp));
      expect(copy.address, equals(original.address));
    });

    test('throws when latitude is out of valid range', () {
      expect(
        () => HomeLocation(
          latitude: 91.0,
          longitude: -122.4194,
          timestamp: DateTime(2024, 1, 15),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('throws when longitude is out of valid range', () {
      expect(
        () => HomeLocation(
          latitude: 37.7749,
          longitude: 181.0,
          timestamp: DateTime(2024, 1, 15),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

import 'dart:convert';

import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/models/home_location.dart';

/// Service for managing home location in local storage.
///
/// Uses SharedPreferences via PrefsStorage for local-only persistence -
/// never sends data to server (privacy-first design).
class HomeLocationService {
  static const String _key = 'home_location';

  final PrefsStorage _prefs;

  HomeLocationService(this._prefs);

  /// Get the stored home location, or null if not set.
  Future<HomeLocation?> getHomeLocation() async {
    final jsonString = _prefs.readString(_key);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return HomeLocation.fromJson(json);
    } catch (e) {
      // If data is corrupted, clear it
      await clearHomeLocation();
      return null;
    }
  }

  /// Set the home location.
  ///
  /// [latitude] and [longitude] are required.
  /// [address] is optional reverse-geocoded address.
  Future<void> setHomeLocation(
    double latitude,
    double longitude, {
    String? address,
  }) async {
    // Validate coordinates
    assert(latitude >= -90 && latitude <= 90, 'Latitude must be between -90 and 90');
    assert(longitude >= -180 && longitude <= 180, 'Longitude must be between -180 and 180');

    final homeLocation = HomeLocation(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      address: address,
    );

    final jsonString = jsonEncode(homeLocation.toJson());
    await _prefs.writeString(_key, jsonString);
  }

  /// Clear the stored home location.
  Future<void> clearHomeLocation() async {
    await _prefs.delete(_key);
  }

  /// Check if a home location is stored.
  Future<bool> hasHomeLocation() async {
    return _prefs.contains(_key);
  }

  /// Get distance from current location to home in kilometers.
  ///
  /// Returns null if home location is not set.
  Future<double?> distanceToHome(double currentLat, double currentLon) async {
    final home = await getHomeLocation();
    if (home == null) return null;

    final currentLocation = HomeLocation(
      latitude: currentLat,
      longitude: currentLon,
      timestamp: DateTime.now(),
    );

    return currentLocation.distanceTo(home);
  }
}
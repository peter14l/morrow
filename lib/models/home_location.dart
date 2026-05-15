import 'dart:math' as math;

/// Home location model for safe check-in feature.
///
/// Stores user's home location locally via SharedPreferences only -
/// never sent to server for privacy.
class HomeLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;

  HomeLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
  }) : assert(
         latitude >= -90 && latitude <= 90,
         'Latitude must be between -90 and 90',
       ),
       assert(
         longitude >= -180 && longitude <= 180,
         'Longitude must be between -180 and 180',
       );

  factory HomeLocation.fromJson(Map<String, dynamic> json) {
    return HomeLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
    };
  }

  HomeLocation copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? address,
  }) {
    return HomeLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
    );
  }

  /// Calculate distance to another location using Haversine formula.
  /// Returns distance in kilometers.
  double distanceTo(HomeLocation other) {
    const double earthRadius = 6371; // km

    final lat1 = latitude * (math.pi / 180);
    final lat2 = other.latitude * (math.pi / 180);
    final dLat = (other.latitude - latitude) * (math.pi / 180);
    final dLon = (other.longitude - longitude) * (math.pi / 180);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Get display string for the location.
  String getDisplayString() {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HomeLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp &&
        other.address == address;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude, timestamp, address);
  }

  @override
  String toString() {
    return 'HomeLocation(lat: $latitude, lon: $longitude, address: $address)';
  }
}

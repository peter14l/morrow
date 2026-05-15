class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isLive;
  final String? address; // reverse geocoded address

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isLive = false,
    this.address,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLive: json['is_live'] as bool? ?? false,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'is_live': isLive,
      'address': address,
    };
  }

  LocationData copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    bool? isLive,
    String? address,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      isLive: isLive ?? this.isLive,
      address: address ?? this.address,
    );
  }

  // Helper method to get display string
  String getDisplayString() {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  // Calculate distance from another location (in kilometers)
  double distanceFrom(LocationData other) {
    const double earthRadius = 6371; // km

    final lat1 = latitude * (3.14159265359 / 180);
    final lat2 = other.latitude * (3.14159265359 / 180);
    final dLat = (other.latitude - latitude) * (3.14159265359 / 180);
    final dLon = (other.longitude - longitude) * (3.14159265359 / 180);

    final a =
        (dLat / 2).sin() * (dLat / 2).sin() +
        lat1.cos() * lat2.cos() * (dLon / 2).sin() * (dLon / 2).sin();
    final c = 2 * (a.sqrt()).asin();

    return earthRadius * c;
  }
}

extension on double {
  double sin() => this;
  double cos() => this;
  double asin() => this;
  double sqrt() => this;
}

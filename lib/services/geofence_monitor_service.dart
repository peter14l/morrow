import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:oasis/services/home_location_service.dart';

/// Service for monitoring geofence around user's home location.
///
/// Uses foreground-only location monitoring (background monitoring in Plan 15-03 if needed).
/// Privacy: Only monitors when app is active, home location stored locally only.
class GeofenceMonitorService {
  final HomeLocationService _homeLocationService;
  
  /// Radius in meters for geofence detection (default: 100m)
  final int radius;
  
  /// Callback invoked when user arrives home (enters geofence)
  void Function()? onHomeArrived;
  
  Timer? _monitoringTimer;
  bool? _wasAtHome = null; // null = unknown, false = known not at home, true = at home
  bool _isMonitoring = false;
  
  GeofenceMonitorService(
    this._homeLocationService, {
    this.radius = 100,
  });
  
  /// Current monitoring state
  bool get isMonitoring => _isMonitoring;
  
  /// Get the geofence radius in meters
  int get radiusMeters => radius;
  
  /// Check if a given location is within the geofence of the home location.
  ///
  /// Returns true if within [radius] meters of home.
  /// Returns false if home is not set or location is outside radius.
  Future<bool> isWithinGeofence(double currentLat, double currentLon) async {
    final homeLocation = await _homeLocationService.getHomeLocation();
    if (homeLocation == null) return false;
    
    final distanceKm = _calculateDistance(
      currentLat, currentLon,
      homeLocation.latitude, homeLocation.longitude,
    );
    final distanceMeters = distanceKm * 1000;
    
    return distanceMeters <= radius;
  }
  
  /// Start monitoring location for home arrival.
  ///
  /// Returns true if monitoring started successfully.
  /// Returns false if home location is not set.
  Future<bool> startMonitoring() async {
    final homeLocation = await _homeLocationService.getHomeLocation();
    if (homeLocation == null) return false;
    
    // Check initial state - is user already at home?
    try {
      final position = await Geolocator.getCurrentPosition();
      
      _wasAtHome = await isWithinGeofence(position.latitude, position.longitude);
    } catch (e) {
      // If we can't get location, leave state as unknown (null)
      // Don't assume anything - we'll detect transitions when we get a fix
    }
    
    // Start periodic monitoring (every 30 seconds)
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkLocation(),
    );
    
    _isMonitoring = true;
    return true;
  }
  
  /// Stop monitoring location.
  Future<void> stopMonitoring() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _wasAtHome = false;
  }
  
  /// Check current location and notify if home arrival detected.
  ///
  /// This can be called externally (e.g., on app resume) or from periodic monitoring.
  Future<void> checkAndNotifyHomeArrival(double currentLat, double currentLon) async {
    final isNowAtHome = await isWithinGeofence(currentLat, currentLon);
    
    if (isNowAtHome) {
      // Trigger if:
      // 1. We came from known "not at home" state (_wasAtHome = false), OR
      // 2. We have no initial state (_wasAtHome = null) - first detection
      // Don't trigger if already at home (_wasAtHome = true)
      if (_wasAtHome != true) {
        _wasAtHome = true;
        onHomeArrived?.call();
      }
    } else {
      // Not at home
      _wasAtHome = false;
    }
  }
  
  Future<void> _checkLocation() async {
    if (!_isMonitoring) return;
    
    try {
      final position = await Geolocator.getCurrentPosition();
      
      await checkAndNotifyHomeArrival(position.latitude, position.longitude);
    } catch (e) {
      // Silently handle location errors - monitoring continues
    }
  }
  
  /// Calculate distance between two points using Haversine formula.
  /// Returns distance in kilometers.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLon = (lon2 - lon1) * (math.pi / 180);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Check if location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  /// Check and request location permission.
  Future<LocationPermission> checkAndRequestPermission() async {
    var permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }
  
  /// Get current position (requires permission).
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }
  
  /// Dispose of resources.
  void dispose() {
    stopMonitoring();
  }
}
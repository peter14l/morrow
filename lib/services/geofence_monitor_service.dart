import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oasis/services/home_location_service.dart';

/// Service for monitoring geofence around user's home location using native OS APIs.
///
/// Native implementation (Plan 15-03) provides high reliability and low battery usage.
class GeofenceMonitorService {
  static const MethodChannel _channel = MethodChannel('oasis/geofence');
  final HomeLocationService _homeLocationService;
  
  /// Radius in meters for geofence detection (default: 100m)
  final int radius;
  
  /// Callback invoked when user arrives home (enters geofence)
  void Function()? onHomeArrived;

  /// Callback invoked when user leaves home (exits geofence)
  void Function()? onHomeLeft;
  
  bool _isMonitoring = false;
  
  GeofenceMonitorService(
    this._homeLocationService, {
    this.radius = 100,
  }) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onEnterRegion':
        final String id = call.arguments['id'];
        if (id == 'home_geofence') {
          debugPrint('[Geofence] User entered home region');
          onHomeArrived?.call();
        }
        break;
      case 'onExitRegion':
        final String id = call.arguments['id'];
        if (id == 'home_geofence') {
          debugPrint('[Geofence] User left home region');
          onHomeLeft?.call();
        }
        break;
    }
  }
  
  /// Current monitoring state
  bool get isMonitoring => _isMonitoring;
  
  /// Get the geofence radius in meters
  int get radiusMeters => radius;
  
  /// Start monitoring location for home arrival using native OS Geofencing.
  Future<bool> startMonitoring() async {
    final homeLocation = await _homeLocationService.getHomeLocation();
    if (homeLocation == null) {
      debugPrint('[Geofence] Cannot start: Home location not set');
      return false;
    }
    
    try {
      // 1. Check/Request Permissions
      final permission = await checkAndRequestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('[Geofence] Cannot start: Permission denied');
        return false;
      }

      // 2. Add native geofence
      await _channel.invokeMethod('addGeofence', {
        'id': 'home_geofence',
        'lat': homeLocation.latitude,
        'lon': homeLocation.longitude,
        'radius': radius.toDouble(),
      });
      
      _isMonitoring = true;
      debugPrint('[Geofence] Native monitoring started for (${homeLocation.latitude}, ${homeLocation.longitude})');
      return true;
    } catch (e) {
      debugPrint('[Geofence] Error starting native monitoring: $e');
      return false;
    }
  }
  
  /// Stop monitoring location.
  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('removeGeofence', {'id': 'home_geofence'});
      _isMonitoring = false;
      debugPrint('[Geofence] Native monitoring stopped');
    } catch (e) {
      debugPrint('[Geofence] Error stopping native monitoring: $e');
    }
  }
  
  /// Check if location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  /// Check and request location permission.
  /// Note: Native geofencing often requires background permission on Android 10+.
  Future<LocationPermission> checkAndRequestPermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // For background geofencing, we MUST have LocationPermission.always on Android 10+ and iOS
    if (permission == LocationPermission.whileInUse) {
      debugPrint('[Geofence] Requesting background location permission...');
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
    _channel.setMethodCallHandler(null);
  }
}

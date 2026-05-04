import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/services/geofence_monitor_service.dart';
import 'package:oasis/services/home_location_service.dart';

/// Service that monitors app lifecycle and detects home arrival.
///
/// On app resume, checks if user is now at home and triggers callback
/// if they transitioned from "not at home" to "at home".
class HomeArrivalService with WidgetsBindingObserver {
  static final HomeArrivalService _instance = HomeArrivalService._internal();
  factory HomeArrivalService() => _instance;
  HomeArrivalService._internal();

  static const String _keyWasAtHome = 'home_arrival_was_at_home';
  
  GeofenceMonitorService? _geofenceService;
  HomeLocationService? _homeLocationService;
  PrefsStorage? _prefs;
  bool _isInitialized = false;
  
  /// Callback when user arrives home (transitions from not at home to at home)
  void Function()? onHomeArrived;

  /// Initialize the service with required dependencies.
  void initialize() {
    if (_isInitialized) return;
    
    _prefs = PrefsStorage();
    _homeLocationService = HomeLocationService(_prefs!);
    _geofenceService = GeofenceMonitorService(_homeLocationService!);
    
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    _isInitialized = true;
  }

  /// Dispose of resources.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geofenceService?.dispose();
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  /// Called when app resumes from background.
  Future<void> _onAppResumed() async {
    if (!_isInitialized) return;
    
    // Check location and detect home arrival
    final position = await _geofenceService?.getCurrentPosition();
    if (position != null) {
      await _checkHomeArrival(position.latitude, position.longitude);
    }
  }

  /// Check if user has arrived home and trigger callback if transitioned.
  Future<void> _checkHomeArrival(double lat, double lon) async {
    if (!_isInitialized || _geofenceService == null) return;
    
    final isNowAtHome = await _geofenceService!.isWithinGeofence(lat, lon);
    final wasAtHome = _prefs?.readBool(_keyWasAtHome) ?? false;
    
    // If now at home and wasn't before, trigger callback
    if (isNowAtHome && !wasAtHome) {
      // Update state
      await _prefs?.writeBool(_keyWasAtHome, true);
      
      // Trigger callback
      onHomeArrived?.call();
    } else if (!isNowAtHome) {
      // Update state - not at home
      await _prefs?.writeBool(_keyWasAtHome, false);
    }
  }

  /// Manually check home arrival (useful for testing or manual trigger).
  Future<void> checkNow() async {
    if (!_isInitialized) return;
    
    final position = await _geofenceService?.getCurrentPosition();
    if (position != null) {
      await _checkHomeArrival(position.latitude, position.longitude);
    }
  }

  /// Get the geofence service for external use.
  GeofenceMonitorService? get geofenceService => _geofenceService;
}
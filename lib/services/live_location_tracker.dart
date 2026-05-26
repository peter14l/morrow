import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oasis/models/location_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocationTracker {
  static final LiveLocationTracker _instance = LiveLocationTracker._internal();
  factory LiveLocationTracker() => _instance;
  LiveLocationTracker._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _expiryTimer;
  String? _activeMessageId;
  DateTime? _expiresAt;

  bool get isSharing => _activeMessageId != null;
  String? get activeMessageId => _activeMessageId;

  Future<void> startSharing(String messageId, Duration duration) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // Stop existing sharing if any
    await stopSharing();

    _activeMessageId = messageId;
    _expiresAt = DateTime.now().add(duration);

    // Initial position
    final Position position = await Geolocator.getCurrentPosition();
    await _updateLocationOnServer(position);

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) {
            stopSharing();
          } else {
            _updateLocationOnServer(position);
          }
        });

    // Auto-stop when duration expires
    _expiryTimer = Timer(duration, () {
      stopSharing();
    });
  }

  Future<void> stopSharing() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    await _positionStream?.cancel();
    _positionStream = null;

    if (_activeMessageId != null) {
      try {
        final currentPosition = await Geolocator.getLastKnownPosition();
        if (currentPosition != null) {
          final locData = LocationData(
            latitude: currentPosition.latitude,
            longitude: currentPosition.longitude,
            timestamp: DateTime.now(),
            isLive: false,
          );
          await Supabase.instance.client
              .from('messages')
              .update({'location_data': locData.toJson()})
              .eq('id', _activeMessageId!);
        }
      } catch (e) {
        debugPrint('Failed to mark location as not live: $e');
      }
    }

    _activeMessageId = null;
    _expiresAt = null;
  }

  Future<void> _updateLocationOnServer(Position position) async {
    if (_activeMessageId == null) return;

    final locData = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      isLive: true,
    );

    try {
      await Supabase.instance.client
          .from('messages')
          .update({'location_data': locData.toJson()})
          .eq('id', _activeMessageId!);
    } catch (e) {
      debugPrint('Live location update error: $e');
    }
  }
}

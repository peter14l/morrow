import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocationScreen extends StatefulWidget {
  final Message message;

  const LiveLocationScreen({super.key, required this.message});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  GoogleMapController? _mapController;
  RealtimeChannel? _channel;
  late Message _currentMessage;

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.message;

    // Listen to real-time updates for THIS specific message row
    _channel = Supabase.instance.client
        .channel('public:messages:id=eq.${_currentMessage.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _currentMessage.id,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _currentMessage = Message.fromJson(payload.newRecord);
                _updateMapPosition();
              });
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
              '[LiveLocationScreen] Realtime subscription timed out. Marker updates may be delayed.',
            );
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('[LiveLocationScreen] Realtime channel error: $error');
          }
        });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMapPosition() {
    if (_currentMessage.locationData != null && _mapController != null) {
      final locData = _currentMessage.locationData!;
      if (locData['latitude'] != null && locData['longitude'] != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(
              locData['latitude'] as double,
              locData['longitude'] as double,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMessage.locationData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Location')),
        body: const Center(child: Text('Location not available')),
      );
    }

    final locData = _currentMessage.locationData!;
    if (locData['latitude'] == null || locData['longitude'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Location')),
        body: const Center(child: Text('Location coordinates missing')),
      );
    }

    final latLng = LatLng(
      locData['latitude'] as double,
      locData['longitude'] as double,
    );
    final isLive = locData['is_live'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLive ? 'Live Location' : 'Location (Ended)'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
        onMapCreated: (controller) => _mapController = controller,
        markers: {
          Marker(
            markerId: const MarkerId('user_loc'),
            position: latLng,
            infoWindow: InfoWindow(
              title: isLive ? 'Live Location' : 'Last Known Location',
            ),
          ),
        },
      ),
    );
  }
}

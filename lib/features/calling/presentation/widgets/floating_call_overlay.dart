import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:go_router/go_router.dart';
import '../screens/calling_screen.dart';

class FloatingCallOverlay extends StatefulWidget {
  const FloatingCallOverlay({super.key});

  @override
  State<FloatingCallOverlay> createState() => _FloatingCallOverlayState();
}

class _FloatingCallOverlayState extends State<FloatingCallOverlay> {
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final state = callProvider.state;

    if (!state.isMinimized ||
        (state.activeCall == null && state.incomingCall == null)) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;

            // Keep within bounds
            _position = Offset(
              _position.dx.clamp(0, size.width - 120),
              _position.dy.clamp(0, size.height - 160),
            );
          });
        },
        onTap: () {
          callProvider.toggleMinimize(value: false);
          context.pushNamed(
            'active_call',
            pathParameters: {
              'callId': (state.activeCall ?? state.incomingCall)!.id,
            },
          );
        },
        child: Material(
          elevation: 8,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Mini Video / Avatar
                _buildMiniContent(callProvider),

                // Status Indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            callProvider.isMuted ? Icons.mic_off : Icons.mic,
                            size: 16,
                            color: Colors.white,
                          ),
                          onPressed: callProvider.toggleMute,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.call_end,
                            size: 16,
                            color: Colors.red,
                          ),
                          onPressed: callProvider.endCall,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniContent(CallProvider provider) {
    final room = provider.room;
    if (room == null) {
      return _buildPlaceholder(provider);
    }

    final remoteParticipant = room.remoteParticipants.values.firstOrNull;
    if (remoteParticipant != null) {
      final videoTrack = remoteParticipant.videoTrackPublications.firstOrNull?.track;
      if (videoTrack != null) {
        return VideoTrackRenderer(
          videoTrack,
          fit: VideoViewFit.cover,
        );
      }
    }

    if (provider.isVideoOn) {
      final localVideoTrack = room.localParticipant?.videoTrackPublications.firstOrNull?.track;
      if (localVideoTrack != null) {
        return VideoTrackRenderer(
          localVideoTrack,
          fit: VideoViewFit.cover,
        );
      }
    }

    return _buildPlaceholder(provider);
  }

  Widget _buildPlaceholder(CallProvider provider) {
    final call = provider.activeCall ?? provider.incomingCall;
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: PulsatingParticipant(
          userId: call?.callerId, // Placeholder logic
          isLocal: false,
          size: 60,
        ),
      ),
    );
  }
}

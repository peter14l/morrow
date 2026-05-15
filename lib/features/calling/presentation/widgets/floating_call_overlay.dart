import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:go_router/go_router.dart';

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
    final state = provider.state;

    // If there's a remote stream, show it
    if (state.remoteRenderers.isNotEmpty) {
      final renderer = state.remoteRenderers.values.first;
      return RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    // Otherwise show local camera or just a person icon
    if (provider.isVideoOn && state.localRenderer != null) {
      return RTCVideoView(
        state.localRenderer!,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    return const Center(
      child: Icon(Icons.person, color: Colors.white24, size: 40),
    );
  }
}

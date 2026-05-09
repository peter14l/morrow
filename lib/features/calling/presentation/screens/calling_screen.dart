import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';

class CallingScreen extends StatefulWidget {
  final String? callId;
  final bool isIncoming;

  const CallingScreen({
    super.key,
    this.callId,
    this.isIncoming = false,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {
  bool _isCallDataTimeout = false;
  CallProvider? _callProvider;

  @override
  void initState() {
    super.initState();

    if (widget.isIncoming) {
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          final provider = context.read<CallProvider>();
          if (!provider.hasIncomingCall && !provider.hasActiveCall) {
            setState(() {
              _isCallDataTimeout = true;
            });
          }
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_callProvider == null) {
      _callProvider = context.read<CallProvider>();
      _callProvider!.addListener(_handleProviderUpdate);
    }
  }

  void _handleProviderUpdate() {
    if (!mounted) return;
    final error = _callProvider?.state.error;
    if (error != null) {
      _showError(error);
      _callProvider?.clearError();
    }
  }

  @override
  void dispose() {
    _callProvider?.removeListener(_handleProviderUpdate);
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Optimization: Use select for high-level structure to avoid total rebuilds
    final hasActiveCall = context.select<CallProvider, bool>((p) => p.hasActiveCall);
    final hasIncomingCall = context.select<CallProvider, bool>((p) => p.hasIncomingCall);
    
    final isWaitingForIncomingCall = widget.isIncoming && !hasActiveCall && !hasIncomingCall && !_isCallDataTimeout;
    
    if (!isWaitingForIncomingCall && !hasActiveCall && !hasIncomingCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Call ended', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.blueGrey.withValues(alpha: 0.2),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Using a separate widget for the grid to isolate rebuilds
            const Positioned.fill(child: ParticipantDisplay()),

            // Control Bar - Isolated rebuilds
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: CallControlBar(isIncoming: widget.isIncoming),
            ),

            // Call Header - Isolated rebuilds
            const Positioned(
              top: 60,
              left: 20,
              child: CallHeaderDisplay(),
            ),

            // Diagnostic Button (Only shown in debug or when explicitly requested)
            Positioned(
              top: 60,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.white54),
                onPressed: () => _showDiagnostics(context),
                tooltip: 'Diagnostics',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiagnostics(BuildContext context) {
    final steps = context.read<CallProvider>().callSteps;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Call Diagnostics', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: steps.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                steps[index],
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class ParticipantDisplay extends StatelessWidget {
  const ParticipantDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuild if streams or sharing state changes
    final state = context.watch<CallProvider>().state;
    final isLocalSharing = context.select<CallProvider, bool>((p) => p.isScreenSharing);
    final isVideoOn = context.select<CallProvider, bool>((p) => p.isVideoOn);
    
    final isWaiting = state.remoteStreams.isEmpty;
    if (isWaiting) {
      return const WaitingScreen();
    }

    final remoteIds = state.remoteStreams.keys.toList();
    final remoteSharingId = state.remoteScreenShareUserId;
    final someoneSharing = isLocalSharing || remoteSharingId != null;

    if (someoneSharing) {
      return ScreenShareLayout(
        remoteIds: remoteIds, 
        isLocalSharing: isLocalSharing, 
        remoteSharingId: remoteSharingId,
        isVideoOn: isVideoOn,
        localRenderer: state.localRenderer,
      );
    }

    if (remoteIds.length == 1) {
      return Column(
        children: [
          Expanded(
            child: VideoTile(
              key: const ValueKey('local_tile'),
              name: 'You', 
              renderer: state.localRenderer, 
              isLocal: true, 
              isVideoOn: isVideoOn
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RemoteParticipantTile(
              key: ValueKey('remote_${remoteIds[0]}'),
              userId: remoteIds[0],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 100, 4, 120),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: remoteIds.length + 1 <= 2 ? 1 : 2,
        childAspectRatio: remoteIds.length + 1 <= 2 ? 0.8 : 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: remoteIds.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return VideoTile(
            key: const ValueKey('local_tile_grid'),
            name: 'You', 
            renderer: state.localRenderer, 
            isLocal: true, 
            isVideoOn: isVideoOn
          );
        }
        final userId = remoteIds[index - 1];
        return RemoteParticipantTile(
          key: ValueKey('remote_grid_$userId'),
          userId: userId,
        );
      },
    );
  }
}

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final call = context.select<CallProvider, CallEntity?>((p) => p.activeCall ?? p.incomingCall);
    final currentUserId = context.select<ProfileProvider, String?>((p) => p.currentProfile?.id);
    final otherUserId = call?.callerId == currentUserId ? call?.receiverId : call?.callerId;
    
    String statusText;
    if (call?.status == CallStatus.ringing) {
      statusText = call?.callerId == currentUserId ? 'Calling...' : 'Incoming...';
    } else {
      statusText = 'Connecting...';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulsatingParticipant(
            key: ValueKey('pulsating_$otherUserId'),
            userId: otherUserId,
            isLocal: false,
            size: 200,
          ),
          const SizedBox(height: 40),
          Text(
            statusText,
            style: const TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class ScreenShareLayout extends StatelessWidget {
  final List<String> remoteIds;
  final bool isLocalSharing;
  final String? remoteSharingId;
  final bool isVideoOn;
  final RTCVideoRenderer? localRenderer;

  const ScreenShareLayout({
    super.key,
    required this.remoteIds,
    required this.isLocalSharing,
    this.remoteSharingId,
    required this.isVideoOn,
    this.localRenderer,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: isLocalSharing 
            ? VideoTile(
                key: const ValueKey('local_screen_share'),
                name: 'Your Screen', 
                renderer: localRenderer, 
                isLocal: true, 
                isVideoOn: true
              )
            : RemoteParticipantTile(
                key: ValueKey('remote_screen_share_$remoteSharingId'),
                userId: remoteSharingId!, 
                isFull: true
              ),
        ),
        Positioned(
          top: 100,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLocalSharing)
                SizedBox(
                  width: 120,
                  height: 160,
                  child: VideoTile(
                    key: const ValueKey('local_pip'),
                    name: 'You', 
                    renderer: localRenderer, 
                    isLocal: true, 
                    isVideoOn: isVideoOn
                  ),
                ),
              ...remoteIds.where((id) => id != remoteSharingId).map((id) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: RemoteParticipantTile(
                    key: ValueKey('remote_pip_$id'),
                    userId: id,
                  ),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class RemoteParticipantTile extends StatelessWidget {
  final String userId;
  final bool isFull;

  const RemoteParticipantTile({
    super.key,
    required this.userId,
    this.isFull = false,
  });

  @override
  Widget build(BuildContext context) {
    // Optimization: Select only what's needed for this specific participant
    final stream = context.select<CallProvider, MediaStream?>((p) => p.state.remoteStreams[userId]);
    final renderer = context.select<CallProvider, RTCVideoRenderer?>((p) => p.state.remoteRenderers[userId]);
    
    final hasRemoteVideo = stream != null && 
                          stream.getVideoTracks().isNotEmpty && 
                          stream.getVideoTracks().any((t) => t.enabled);

    return ParticipantTile(
      key: ValueKey('tile_$userId'),
      userId: userId,
      renderer: renderer,
      isVideoOn: hasRemoteVideo,
      isFull: isFull,
    );
  }
}

class CallHeaderDisplay extends StatelessWidget {
  const CallHeaderDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select<CallProvider, CallType?>((p) => (p.activeCall ?? p.incomingCall)?.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type == CallType.video ? 'Video Call' : 'Voice Call',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Icon(Icons.lock, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              'End-to-end encrypted',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class CallControlBar extends StatelessWidget {
  final bool isIncoming;
  const CallControlBar({super.key, required this.isIncoming});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CallProvider>();
    final hasIncomingCall = context.select<CallProvider, bool>((p) => p.hasIncomingCall);
    final hasActiveCall = context.select<CallProvider, bool>((p) => p.hasActiveCall);
    final isMuted = context.select<CallProvider, bool>((p) => p.isMuted);
    final isVideoOn = context.select<CallProvider, bool>((p) => p.isVideoOn);
    final isSpeakerphoneOn = context.select<CallProvider, bool>((p) => p.isSpeakerphoneOn);
    final isSharing = context.select<CallProvider, bool>((p) => p.isScreenSharing);

    if (isIncoming && !hasIncomingCall && !hasActiveCall) {
      return const SizedBox.shrink();
    }

    // Optimization: Wrap in RepaintBoundary to avoid unnecessary paints of background elements
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: hasIncomingCall && !hasActiveCall
            ? _buildIncomingControls(context, provider)
            : _buildActiveControls(context, provider, isMuted, isVideoOn, isSpeakerphoneOn, isSharing),
      ),
    );
  }

  Widget _buildIncomingControls(BuildContext context, CallProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          onPressed: () {
            final call = provider.incomingCall;
            final userId = context.read<ProfileProvider>().currentProfile?.id;
            if (call != null && userId != null) {
              provider.declineCall(call.id, userId);
            }
          },
          icon: Icons.call_end,
          color: Colors.red,
          isLarge: true,
        ),
        const SizedBox(width: 60),
        _ControlButton(
          onPressed: () {
            final call = provider.incomingCall;
            if (call != null) {
              provider.acceptCall(call);
            }
          },
          icon: Icons.call,
          color: Colors.green,
          isLarge: true,
        ),
      ],
    );
  }

  Widget _buildActiveControls(BuildContext context, CallProvider provider, bool isMuted, bool isVideoOn, bool isSpeakerphoneOn, bool isSharing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          onPressed: provider.toggleMute,
          icon: isMuted ? Icons.mic_off : Icons.mic,
          color: isMuted ? Colors.red : Colors.white24,
        ),
        _ControlButton(
          onPressed: provider.toggleSpeakerphone,
          icon: isSpeakerphoneOn ? Icons.volume_up : Icons.volume_down,
          color: isSpeakerphoneOn ? Colors.blue : Colors.white24,
        ),
        _ControlButton(
          onPressed: () {
            provider.toggleMinimize(value: true);
            Navigator.pop(context);
          },
          icon: Icons.close_fullscreen_rounded,
          color: Colors.white24,
        ),
        _ControlButton(
          onPressed: provider.toggleVideo,
          icon: isVideoOn ? Icons.videocam : Icons.videocam_off,
          color: isVideoOn ? Colors.white24 : Colors.red,
        ),
        _ControlButton(
          onPressed: provider.toggleScreenShare,
          icon: isSharing ? Icons.screen_share : Icons.stop_screen_share,
          color: isSharing ? Colors.green : Colors.white24,
        ),
        _ControlButton(
          onPressed: provider.endCall,
          icon: Icons.call_end,
          color: Colors.red,
          isLarge: true,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  final bool isLarge;

  const _ControlButton({
    required this.onPressed,
    required this.icon,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        iconSize: isLarge ? 32 : 24,
        padding: EdgeInsets.all(isLarge ? 16 : 12),
      ),
    );
  }
}

class VideoTile extends StatelessWidget {
  final String name;
  final RTCVideoRenderer? renderer;
  final bool isLocal;
  final String? userId;
  final bool isVideoOn;

  const VideoTile({
    super.key,
    required this.name,
    this.renderer,
    this.isLocal = false,
    this.userId,
    required this.isVideoOn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (renderer != null)
            Opacity(
              opacity: isVideoOn ? 1.0 : 0.01,
              child: RTCVideoView(
                renderer!,
                mirror: isLocal,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                key: ValueKey('renderer_${renderer!.hashCode}'),
              ),
            ),
          
          if (!isVideoOn)
            Positioned.fill(
              child: Container(
                color: Colors.grey[900],
                child: PulsatingParticipant(
                  userId: userId,
                  isLocal: isLocal,
                ),
              ),
            ),

          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PulsatingParticipant extends StatefulWidget {
  final String? userId;
  final bool isLocal;
  final double size;

  const PulsatingParticipant({
    super.key,
    this.userId,
    this.isLocal = false,
    this.size = 100,
  });

  @override
  State<PulsatingParticipant> createState() => _PulsatingParticipantState();
}

class _PulsatingParticipantState extends State<PulsatingParticipant> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  UserProfileEntity? _profile;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profileProvider = context.read<ProfileProvider>();
    if (widget.isLocal) {
      _profile = profileProvider.currentProfile;
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      try {
        final profile = await profileProvider.getProfile(widget.userId!);
        if (mounted) setState(() => _profile = profile);
      } catch (e) {
        debugPrint('Error loading participant profile: $e');
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _animation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.2),
                blurRadius: widget.size / 4,
                spreadRadius: widget.size / 20,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: widget.size / 2,
            backgroundColor: Colors.grey[800],
            backgroundImage: _profile?.avatarUrl != null 
                ? CachedNetworkImageProvider(_profile!.avatarUrl!) 
                : null,
            child: _profile?.avatarUrl == null 
                ? Icon(Icons.person, size: widget.size / 2, color: Colors.white54) 
                : null,
          ),
        ),
      ),
    );
  }
}

class ParticipantTile extends StatefulWidget {
  final String userId;
  final RTCVideoRenderer? renderer;
  final bool isVideoOn;
  final bool isFull;

  const ParticipantTile({
    super.key,
    required this.userId,
    this.renderer,
    required this.isVideoOn,
    this.isFull = false,
  });

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  UserProfileEntity? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await context.read<ProfileProvider>().getProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('[ParticipantTile] Error loading profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?.displayName ?? _profile?.username ?? 'Remote User';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: widget.isFull ? BorderRadius.zero : BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (widget.renderer != null)
            Opacity(
              opacity: widget.isVideoOn ? 1.0 : 0.01,
              child: RTCVideoView(
                widget.renderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                key: ValueKey('remote_renderer_${widget.renderer!.hashCode}'),
              ),
            ),
          
          if (!widget.isVideoOn)
            Positioned.fill(
              child: Container(
                color: Colors.grey[900],
                child: PulsatingParticipant(
                  userId: widget.userId,
                  size: widget.isFull ? 200 : 80,
                ),
              ),
            ),

          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

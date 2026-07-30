import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';
import '../widgets/add_participant_sheet.dart';

class CallingScreen extends StatefulWidget {
  final String? callId;
  final bool isIncoming;

  const CallingScreen({super.key, this.callId, this.isIncoming = false});

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {
  bool _isCallDataTimeout = false;
  bool _hasPopped = false;
  CallProvider? _callProvider;

  @override
  void initState() {
    super.initState();

    if (widget.isIncoming) {
      Future.delayed(const Duration(seconds: 15), () {
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
    final hasActiveCall = context.select<CallProvider, bool>(
      (p) => p.hasActiveCall,
    );
    final hasIncomingCall = context.select<CallProvider, bool>(
      (p) => p.hasIncomingCall,
    );
    final isUnanswered = context.select<CallProvider, bool>(
      (p) => p.state.isUnanswered,
    );

    final isWaitingForIncomingCall =
        widget.isIncoming &&
        !hasActiveCall &&
        !hasIncomingCall &&
        !_isCallDataTimeout;

    if (!isWaitingForIncomingCall && !hasActiveCall && !hasIncomingCall && !isUnanswered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasPopped) {
          _hasPopped = true;
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          }
        }
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Call ended', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (isUnanswered) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_missed_rounded, color: Colors.redAccent, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Call unanswered',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      context.read<CallProvider>().clearUnanswered();
                      final router = GoRouter.of(context);
                      if (router.canPop()) {
                        router.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CallProvider>().retryLastCall();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Try again', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
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
            const Positioned.fill(child: ParticipantDisplay()),

            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: CallControlBar(isIncoming: widget.isIncoming),
            ),

            const Positioned(top: 60, left: 20, child: CallHeaderDisplay()),

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
        title: const Text(
          'Call Diagnostics',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: steps.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                steps[index],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
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
    final room = context.select<CallProvider, Room?>((p) => p.room);

    if (room == null) {
      return const WaitingScreen();
    }

    final localParticipant = room.localParticipant;
    final List<RemoteParticipant> remoteParticipants = room.remoteParticipants.values.toList();
    
    // Sort participants: speakers first, then by join time
    remoteParticipants.sort((a, b) {
      if (a.isSpeaking && !b.isSpeaking) return -1;
      if (!a.isSpeaking && b.isSpeaking) return 1;
      return a.joinedAt.compareTo(b.joinedAt);
    });

    final List<Participant> allParticipants = [if (localParticipant != null) localParticipant, ...remoteParticipants];

    if (allParticipants.length <= 1) {
      return const WaitingScreen();
    }

    // Check for screen sharing
    Participant? screenSharer;
    for (final p in allParticipants) {
      if (p.isScreenShareEnabled()) {
        screenSharer = p;
        break;
      }
    }

    if (screenSharer != null) {
      return ScreenShareLayout(
        screenSharer: screenSharer,
        otherParticipants: allParticipants.where((p) => p != screenSharer).toList(),
      );
    }

    if (allParticipants.length == 2) {
      return Column(
        children: [
          Expanded(
            child: ParticipantTile(
              participant: allParticipants[0],
              isLocal: allParticipants[0] is LocalParticipant,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ParticipantTile(
              participant: allParticipants[1],
              isLocal: allParticipants[1] is LocalParticipant,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final crossAxisCount = isLandscape ? (allParticipants.length <= 4 ? 2 : 3) : (allParticipants.length <= 2 ? 1 : 2);
        
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(8, 100, 8, 120),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isLandscape ? 1.5 : 0.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: allParticipants.length,
          itemBuilder: (context, index) {
            final p = allParticipants[index];
            return ParticipantTile(
              key: ValueKey(p.sid),
              participant: p,
              isLocal: p is LocalParticipant,
            );
          },
        );
      }
    );
  }
}

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final call = context.select<CallProvider, CallEntity?>(
      (p) => p.activeCall ?? p.incomingCall,
    );
    final currentUserId = context.select<ProfileProvider, String?>(
      (p) => p.currentProfile?.id,
    );
    final otherUserId = call?.callerId == currentUserId
        ? call?.receiverId
        : call?.callerId;

    String statusText;
    if (call?.status == CallStatus.ringing) {
      statusText = call?.callerId == currentUserId
          ? 'Calling...'
          : 'Incoming...';
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
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenShareLayout extends StatelessWidget {
  final Participant screenSharer;
  final List<Participant> otherParticipants;

  const ScreenShareLayout({
    super.key,
    required this.screenSharer,
    required this.otherParticipants,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ParticipantTile(
            participant: screenSharer,
            isLocal: screenSharer is LocalParticipant,
            useScreenShare: true,
          ),
        ),
        Positioned(
          top: 100,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: otherParticipants.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 120,
                height: 160,
                child: ParticipantTile(
                  participant: p,
                  isLocal: p is LocalParticipant,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class ParticipantTile extends StatefulWidget {
  final Participant participant;
  final bool isLocal;
  final bool useScreenShare;

  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isLocal,
    this.useScreenShare = false,
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
    if (oldWidget.participant != widget.participant) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final identity = widget.participant.identity;
      final profile = await context.read<ProfileProvider>().getProfile(identity);
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('[ParticipantTile] Error loading profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?.displayName ?? _profile?.username ?? (widget.isLocal ? 'You' : 'Remote User');
    
    TrackPublication? videoPub;
    if (widget.useScreenShare) {
      videoPub = widget.participant.videoTrackPublications.where((e) => e.isScreenShare).firstOrNull;
    } else {
      videoPub = widget.participant.videoTrackPublications.where((e) => !e.isScreenShare).firstOrNull;
    }
    
    final isVideoEnabled = videoPub?.subscribed ?? false;
    final videoTrack = videoPub?.track;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: widget.participant.isSpeaking 
          ? Border.all(color: Colors.blue, width: 2)
          : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (videoTrack != null && videoTrack is VideoTrack && isVideoEnabled)
            VideoTrackRenderer(
              videoTrack,
              fit: VideoViewFit.contain,
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.grey[900],
                child: PulsatingParticipant(
                  userId: widget.participant.identity,
                  isLocal: widget.isLocal,
                  size: 80,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.participant.isSpeaking)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.mic, color: Colors.blue, size: 12),
                    ),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CallHeaderDisplay extends StatelessWidget {
  const CallHeaderDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.select<CallProvider, CallType?>(
      (p) => (p.activeCall ?? p.incomingCall)?.type,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type == CallType.video ? 'Video Call' : 'Voice Call',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Icon(Icons.lock, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              'LiveKit Powered • End-to-end encrypted',
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
    final hasIncomingCall = context.select<CallProvider, bool>(
      (p) => p.hasIncomingCall,
    );
    final hasActiveCall = context.select<CallProvider, bool>(
      (p) => p.hasActiveCall,
    );
    final isMuted = context.select<CallProvider, bool>((p) => p.isMuted);
    final isVideoOn = context.select<CallProvider, bool>((p) => p.isVideoOn);
    final isSpeakerphoneOn = context.select<CallProvider, bool>(
      (p) => p.isSpeakerphoneOn,
    );
    final isSharing = context.select<CallProvider, bool>(
      (p) => p.isScreenSharing,
    );

    if (isIncoming && !hasIncomingCall && !hasActiveCall) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: hasIncomingCall && !hasActiveCall
            ? _buildIncomingControls(context, provider)
            : _buildActiveControls(
                context,
                provider,
                isMuted,
                isVideoOn,
                isSpeakerphoneOn,
                isSharing,
              ),
      ),
    );
  }

  Widget _buildIncomingControls(BuildContext context, CallProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          onPressed: () {
            try {
              final call = provider.incomingCall;
              if (call == null) return;
              final userId = context.read<ProfileProvider>().currentProfile?.id;
              if (userId != null) {
                provider.declineCall(call.id, userId);
              }
            } catch (e) {
              debugPrint('[CallingScreen] Decline error: $e');
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

  Widget _buildActiveControls(
    BuildContext context,
    CallProvider provider,
    bool isMuted,
    bool isVideoOn,
    bool isSpeakerphoneOn,
    bool isSharing,
  ) {
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
          onPressed: () {
            final room = provider.room;
            if (room != null) {
              context.showResponsiveSheet(
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddParticipantSheet(
                  existingParticipantIds: [
                    room.localParticipant?.identity ?? '',
                    ...room.remoteParticipants.values.map((p) => p.identity),
                  ],
                ),
              );
            }
          },
          icon: Icons.person_add_alt_1,
          color: Colors.white24,
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        iconSize: isLarge ? 32 : 24,
        padding: EdgeInsets.all(isLarge ? 16 : 12),
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

class _PulsatingParticipantState extends State<PulsatingParticipant>
    with SingleTickerProviderStateMixin {
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
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                ? Icon(
                    Icons.person,
                    size: widget.size / 2,
                    color: Colors.white54,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

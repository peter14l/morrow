import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/app_config.dart';
import '../../domain/models/call_entity.dart';
import '../../domain/usecases/initiate_call.dart';
import '../../domain/usecases/accept_call.dart';
import '../../domain/usecases/end_call.dart';
import '../../domain/usecases/get_active_calls.dart';

/// Immutable state for calling feature
class CallState {
  final CallEntity? activeCall;
  final CallEntity? incomingCall;
  final List<CallEntity> activeCalls;
  final MediaStream? localStream;
  final Map<String, MediaStream> remoteStreams;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final RTCVideoRenderer? localRenderer;
  final bool isLoading;
  final String? error;
  final bool isMuted;
  final bool isVideoOn;
  final bool isScreenSharing;
  final bool isMinimized;
  final String? remoteScreenShareUserId;

  const CallState({
    this.activeCall,
    this.incomingCall,
    this.activeCalls = const [],
    this.localStream,
    this.remoteStreams = const {},
    this.remoteRenderers = const {},
    this.localRenderer,
    this.isLoading = false,
    this.error,
    this.isMuted = false,
    this.isVideoOn = true,
    this.isScreenSharing = false,
    this.isMinimized = false,
    this.remoteScreenShareUserId,
  });

  factory CallState.initial() {
    return const CallState(isLoading: true);
  }

  CallState copyWith({
    CallEntity? activeCall,
    bool clearActiveCall = false,
    CallEntity? incomingCall,
    bool clearIncomingCall = false,
    List<CallEntity>? activeCalls,
    MediaStream? localStream,
    Map<String, MediaStream>? remoteStreams,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    RTCVideoRenderer? localRenderer,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isMuted,
    bool? isVideoOn,
    bool? isScreenSharing,
    bool? isMinimized,
    String? remoteScreenShareUserId,
    bool clearRemoteScreenShare = false,
  }) {
    return CallState(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      incomingCall: clearIncomingCall ? null : (incomingCall ?? this.incomingCall),
      activeCalls: activeCalls ?? this.activeCalls,
      localStream: localStream ?? this.localStream,
      remoteStreams: remoteStreams ?? this.remoteStreams,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      localRenderer: localRenderer ?? this.localRenderer,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isMinimized: isMinimized ?? this.isMinimized,
      remoteScreenShareUserId: clearRemoteScreenShare ? null : (remoteScreenShareUserId ?? this.remoteScreenShareUserId),
    );
  }
}

/// Provider for call state management
class CallProvider extends ChangeNotifier {
  final CallService _callService;
  late InitiateCall _initiateCall;
  late AcceptCall _acceptCall;
  late EndCall _endCall;
  late GetActiveCalls _getActiveCalls;
  bool _isInitialized = false;
  bool _isEnding = false;
  Timer? _ringingTimer;

  CallState _state = CallState.initial();

  CallProvider(this._callService) {
    _callService.addListener(_onCallServiceUpdate);
    
    // Listen to auth state changes to automatically start/stop listener
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        // User logged in or session restored
        if (_isInitialized) {
          _startListenerWithRetry();
        }
      } else {
        // User logged out
        _callService.endCall();
      }
    });
  }

  void _onCallServiceUpdate() {
    if (_isEnding) return;

    final newState = _state.copyWith(
      activeCall: _callService.currentCall,
      localStream: _callService.localStream,
      remoteStreams: Map.from(_callService.remoteStreams),
      remoteRenderers: Map.from(_callService.remoteRenderers),
      localRenderer: _callService.localRenderer,
      isMuted: _callService.isMuted,
      isVideoOn: _callService.isVideoOn,
      isScreenSharing: _callService.isScreenSharing,
      incomingCall: _callService.incomingCall,
      remoteScreenShareUserId: _callService.remoteScreenShareUserId,
      clearRemoteScreenShare: _callService.remoteScreenShareUserId == null,
      clearIncomingCall: _callService.incomingCall == null,
      clearActiveCall: _callService.currentCallId == null,
    );

    if (newState.activeCall != _state.activeCall ||
        newState.incomingCall != _state.incomingCall ||
        newState.localStream != _state.localStream ||
        newState.remoteStreams.length != _state.remoteStreams.length ||
        newState.isMuted != _state.isMuted ||
        newState.isVideoOn != _state.isVideoOn ||
        newState.isScreenSharing != _state.isScreenSharing ||
        newState.remoteScreenShareUserId != _state.remoteScreenShareUserId ||
        newState.remoteRenderers.length != _state.remoteRenderers.length) {
      
      // If call status changed to active, stop ringing timer
      if (newState.activeCall?.status == CallStatus.active && 
          _state.activeCall?.status == CallStatus.ringing) {
        _ringingTimer?.cancel();
        _callService.stopRingtone();
      }

      _state = newState;
      notifyListeners();
    } else {
      _state = newState;
    }
  }

  @override
  void dispose() {
    _ringingTimer?.cancel();
    _callService.removeListener(_onCallServiceUpdate);
    super.dispose();
  }

  CallState get state => _state;
  CallEntity? get activeCall => _state.activeCall;
  CallEntity? get incomingCall => _state.incomingCall;
  bool get hasActiveCall => _state.activeCall != null;
  bool get hasIncomingCall => _state.incomingCall != null;
  MediaStream? get localStream => _state.localStream;
  Map<String, MediaStream> get remoteStreams => _state.remoteStreams;
  bool get isMuted => _state.isMuted;
  bool get isVideoOn => _state.isVideoOn;
  bool get isScreenSharing => _state.isScreenSharing;

  Future<void> initialize({
    required InitiateCall initiateCall,
    required AcceptCall acceptCall,
    required EndCall endCall,
    required GetActiveCalls getActiveCalls,
  }) async {
    if (_isInitialized) return;

    _initiateCall = initiateCall;
    _acceptCall = acceptCall;
    _endCall = endCall;
    _getActiveCalls = getActiveCalls;
    _state = _state.copyWith(isLoading: false);
    
    // Start incoming call listener with basic error handling to prevent 
    // startup blocking if Realtime has a temporary hiccup.
    _startListenerWithRetry();
    
    _isInitialized = true;
    _isEnding = false;
    notifyListeners();
  }

  Future<void> _startListenerWithRetry({int attempt = 0}) async {
    try {
      _callService.startIncomingCallListener();
    } catch (e) {
      debugPrint('[CallProvider] Failed to start incoming call listener (attempt $attempt): $e');
      if (attempt < 5) {
        // Linear backoff: 2s, 4s, 6s, 8s, 10s
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        _startListenerWithRetry(attempt: attempt + 1);
      }
    }
  }

  /// Initiate a new 1-on-1 call
  Future<CallEntity?> initiateCall({
    required String conversationId,
    required String callerId,
    required String receiverId,
    required CallType type,
  }) async {
    if (!AppConfig.enableCalls) {
      debugPrint('[CallProvider] Calling is currently disabled in AppConfig');
      return null;
    }
    try {
      _isEnding = false;
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();

      // 1. Initialize local stream
      await _callService.initLocalStream(type == CallType.video);
      
      // 2. Create WebRTC offer
      final offer = await _callService.createOffer(receiverId);

      // 3. Create call in DB
      final call = await _initiateCall.call(
        conversationId: conversationId,
        callerId: callerId,
        receiverId: receiverId,
        type: type,
        offer: offer,
      );

      if (call != null) {
        // 4. Start signaling and ringtone
        await _callService.startSignaling(call);
        await _callService.startRingtone();
        
        _state = _state.copyWith(activeCall: call, isLoading: false);
        
        // 5. Start ringing timeout (30 seconds)
        _ringingTimer?.cancel();
        _ringingTimer = Timer(const Duration(seconds: 30), () {
          debugPrint('[CallProvider] Ringing timeout reached');
          if (_state.activeCall?.status == CallStatus.ringing) {
            endCall();
          }
        });
      } else {
        _state = _state.copyWith(isLoading: false, error: 'Failed to create call');
      }

      notifyListeners();
      return call;
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
      return null;
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall(CallEntity call) async {
    if (_state.isLoading) return;
    try {
      _isEnding = false;
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();

      // Lock the call ID immediately to prevent race conditions in the incoming call listener
      _callService.setAnswering(call.id);

      // 1. Stop local ringtone
      await _callService.stopRingtone();

      // 2. Initialize local stream
      await _callService.initLocalStream(call.type == CallType.video);
      
      // 3. Create WebRTC answer (this now handles E2EE internally with retry)
      final answer = await _callService.createAnswer(call.callerId, call.offer!);

      // 4. Update DB with answer
      final acceptedCall = await _acceptCall.call(
        callId: call.id, 
        userId: call.receiverId,
        answer: answer,
      );
      
      // 5. Start signaling
      await _callService.startSignaling(acceptedCall);
      
      _state = _state.copyWith(
        isLoading: false, 
        activeCall: acceptedCall, 
        clearIncomingCall: true
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[CallProvider] Error accepting call: $e');
      _state = _state.copyWith(isLoading: false, error: 'Failed to accept call: ${e.toString()}');
      notifyListeners();
      
      // If it fails after stopping ringtone, we should cleanup to be safe
      _callService.stopRingtone();
    }
  }

  /// Decline incoming call
  Future<void> declineCall(String callId, String userId) async {
    try {
      _isEnding = true;
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();

      await _endCall.decline(callId, userId);
      await _callService.endCall();

      _state = _state.copyWith(isLoading: false, clearIncomingCall: true, clearActiveCall: true);
      _isEnding = false;
      notifyListeners();
    } catch (e) {
      _isEnding = false;
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }

  /// End current call
  Future<void> endCall() async {
    try {
      final callId = _state.activeCall?.id ?? _state.incomingCall?.id;
      if (callId == null) return;
      
      _ringingTimer?.cancel();
      _isEnding = true;
      _state = _state.copyWith(
        isLoading: true, 
        clearError: true,
        clearActiveCall: true,
        clearIncomingCall: true,
      );
      notifyListeners();

      await _endCall.call(callId);
      await _callService.endCall();
      
      _state = _state.copyWith(isLoading: false);
      _isEnding = false;
      notifyListeners();
    } catch (e) {
      _isEnding = false;
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }

  /// Toggle mute
  void toggleMute() {
    _callService.toggleMute();
  }

  /// Toggle video
  Future<void> toggleVideo() async {
    await _callService.toggleVideo();
  }

  /// Toggle minimized state (PiP)
  void toggleMinimize({bool? value}) {
    _state = _state.copyWith(isMinimized: value ?? !_state.isMinimized);
    notifyListeners();
  }

  /// Toggle screen sharing
  Future<void> toggleScreenShare() async {
    await _callService.toggleScreenShare();
  }

  /// Load active calls
  Future<void> loadActiveCalls(String userId) async {
    try {
      final calls = await _getActiveCalls.calls(userId);
      _state = _state.copyWith(activeCalls: calls);
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
}

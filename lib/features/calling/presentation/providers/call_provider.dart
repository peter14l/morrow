import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';
import '../../domain/models/call_entity.dart';
import '../../domain/usecases/initiate_call.dart';
import '../../domain/usecases/accept_call.dart';
import '../../domain/usecases/end_call.dart';
import '../../domain/usecases/get_active_calls.dart';

/// Immutable state for calling feature using LiveKit
class CallState {
  final CallEntity? activeCall;
  final CallEntity? incomingCall;
  final List<CallEntity> activeCalls;
  final Room? room;
  final bool isLoading;
  final String? error;
  final bool isMuted;
  final bool isVideoOn;
  final bool isSpeakerphoneOn;
  final bool isScreenSharing;
  final bool isMinimized;

  const CallState({
    this.activeCall,
    this.incomingCall,
    this.activeCalls = const [],
    this.room,
    this.isLoading = false,
    this.error,
    this.isMuted = false,
    this.isVideoOn = true,
    this.isSpeakerphoneOn = false,
    this.isScreenSharing = false,
    this.isMinimized = false,
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
    Room? room,
    bool clearRoom = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isMuted,
    bool? isVideoOn,
    bool? isSpeakerphoneOn,
    bool? isScreenSharing,
    bool? isMinimized,
  }) {
    return CallState(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      incomingCall: clearIncomingCall
          ? null
          : (incomingCall ?? this.incomingCall),
      activeCalls: activeCalls ?? this.activeCalls,
      room: clearRoom ? null : (room ?? this.room),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isSpeakerphoneOn: isSpeakerphoneOn ?? this.isSpeakerphoneOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }
}

/// Provider for call state management using LiveKit
class CallProvider extends ChangeNotifier with SafeChangeNotifier {
  final CallService _callService;
  final InitiateCall _initiateCall;
  final AcceptCall _acceptCall;
  final EndCall _endCall;
  final GetActiveCalls _getActiveCalls;
  bool _isInitialized = false;
  bool _isEnding = false;
  Timer? _ringingTimer;

  CallState _state = CallState.initial();

  CallProvider({
    required CallService callService,
    required InitiateCall initiateCall,
    required AcceptCall acceptCall,
    required EndCall endCall,
    required GetActiveCalls getActiveCalls,
  }) : _callService = callService,
       _initiateCall = initiateCall,
       _acceptCall = acceptCall,
       _endCall = endCall,
       _getActiveCalls = getActiveCalls {
    _callService.addListener(_onCallServiceUpdate);

    // Listen to auth state changes to automatically start/stop listener
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        if (_isInitialized) {
          _startListenerWithRetry();
        }
      }
    });

    _startListenerWithRetry();
    _isInitialized = true;
  }

  bool _isProcessingUpdate = false;

  void _onCallServiceUpdate() {
    if (_isEnding || _isProcessingUpdate || isDisposed) return;

    try {
      _isProcessingUpdate = true;
      final newState = _state.copyWith(
        activeCall: _callService.currentCall,
        room: _callService.room,
        isMuted: _callService.isMuted,
        isVideoOn: _callService.isVideoOn,
        isSpeakerphoneOn: _callService.isSpeakerphoneOn,
        isScreenSharing: _callService.isScreenSharing,
        incomingCall: _callService.incomingCall,
        clearIncomingCall: _callService.incomingCall == null,
        clearActiveCall: _callService.currentCallId == null,
        clearRoom: _callService.room == null,
      );

      final hasChanges =
          newState.activeCall != _state.activeCall ||
          newState.incomingCall != _state.incomingCall ||
          newState.room != _state.room ||
          newState.isMuted != _state.isMuted ||
          newState.isVideoOn != _state.isVideoOn ||
          newState.isSpeakerphoneOn != _state.isSpeakerphoneOn ||
          newState.isScreenSharing != _state.isScreenSharing;

      if (hasChanges) {
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
    } finally {
      _isProcessingUpdate = false;
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
  List<String> get callSteps => _callService.callSteps;
  Room? get room => _state.room;
  bool get isMuted => _state.isMuted;
  bool get isVideoOn => _state.isVideoOn;
  bool get isSpeakerphoneOn => _state.isSpeakerphoneOn;
  bool get isScreenSharing => _state.isScreenSharing;

  Future<void> _startListenerWithRetry({int attempt = 0}) async {
    try {
      _callService.startIncomingCallListener();
    } catch (e) {
      if (attempt < 5) {
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        _startListenerWithRetry(attempt: attempt + 1);
      }
    }
  }

  /// Initiate a new LiveKit call
  Future<CallEntity?> initiateCall({
    required String conversationId,
    required String callerId,
    required String receiverId,
    required CallType type,
  }) async {
    if (!AppConfig.enableCalls) return null;
    try {
      _isEnding = false;
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();

      // 1. Initialize local tracks
      await _callService.initLocalStream(type == CallType.video);

      // 2. Create call in DB (No WebRTC offer needed)
      final call = await _initiateCall.call(
        conversationId: conversationId,
        callerId: callerId,
        receiverId: receiverId,
        type: type,
      );

      // 3. Connect to LiveKit room and start ringtone
      await _callService.startSignaling(call);
      await _callService.startRingtone();

      _state = _state.copyWith(activeCall: call, isLoading: false);

      // 4. Start ringing timeout (30 seconds)
      _ringingTimer?.cancel();
      _ringingTimer = Timer(const Duration(seconds: 30), () {
        if (_state.activeCall?.status == CallStatus.ringing) {
          endCall();
        }
      });
    
      notifyListeners();
      return call;
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
      return null;
    }
  }

  /// Accept an incoming LiveKit call
  Future<void> acceptCall(CallEntity call) async {
    if (_state.isLoading) return;
    try {
      _isEnding = false;
      _state = _state.copyWith(isLoading: true, clearError: true);
      notifyListeners();

      _callService.setAnswering(call.id);
      await _callService.stopRingtone();

      // 1. Initialize local tracks
      await _callService.initLocalStream(call.type == CallType.video);

      // 2. Update DB status
      final acceptedCall = await _acceptCall.call(
        callId: call.id,
        userId: call.receiverId,
      );

      // 3. Connect to LiveKit room
      await _callService.startSignaling(acceptedCall);

      _state = _state.copyWith(
        isLoading: false,
        activeCall: acceptedCall,
        clearIncomingCall: true,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Failed to accept call: ${e.toString()}',
      );
      notifyListeners();
      await _callService.stopRingtone();
      await _callService.endCall();
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

      _state = _state.copyWith(
        isLoading: false,
        clearIncomingCall: true,
        clearActiveCall: true,
      );
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
    // Guard against concurrent calls — if already ending, do nothing.
    if (_isEnding) return;

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
        isMinimized: false,
      );
      notifyListeners();

      await _endCall.call(callId);
      // _callService.endCall() calls _cleanup() which calls notifyListeners()
      // internally, but _onCallServiceUpdate is already guarded by _isEnding,
      // so that extra notification won't cause a state conflict.
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

  void toggleMute() => _callService.toggleMute();
  Future<void> toggleVideo() async => await _callService.toggleVideo();
  void toggleSpeakerphone() => _callService.toggleSpeakerphone();
  void toggleMinimize({bool? value}) {
    _state = _state.copyWith(isMinimized: value ?? !_state.isMinimized);
    notifyListeners();
  }
  Future<void> toggleScreenShare() async => await _callService.toggleScreenShare();

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

  void clear() {
    if (isDisposed) return;
    _ringingTimer?.cancel();
    _ringingTimer = null;
    _callService.endCall();
    _state = CallState.initial();
    _isEnding = false;
    notifyListeners();
  }
}

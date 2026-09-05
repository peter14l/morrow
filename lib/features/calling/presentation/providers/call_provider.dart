import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';
import '../../domain/models/call_entity.dart';
import '../../domain/repositories/call_repository.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';

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
  final bool isReconnecting;
  final bool isUnanswered;

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
    this.isReconnecting = false,
    this.isUnanswered = false,
  });

  factory CallState.initial() => const CallState();

  CallState copyWith({
    CallEntity? activeCall,
    CallEntity? incomingCall,
    List<CallEntity>? activeCalls,
    Room? room,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearActiveCall = false,
    bool clearIncomingCall = false,
    bool clearRoom = false,
    bool? isMuted,
    bool? isVideoOn,
    bool? isSpeakerphoneOn,
    bool? isScreenSharing,
    bool? isMinimized,
    bool? isReconnecting,
    bool? isUnanswered,
  }) {
    return CallState(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      incomingCall: clearIncomingCall ? null : (incomingCall ?? this.incomingCall),
      activeCalls: activeCalls ?? this.activeCalls,
      room: clearRoom ? null : (room ?? this.room),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isSpeakerphoneOn: isSpeakerphoneOn ?? this.isSpeakerphoneOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isMinimized: isMinimized ?? this.isMinimized,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      isUnanswered: isUnanswered ?? this.isUnanswered,
    );
  }
}

/// Provider for call state management using LiveKit
class CallProvider extends ChangeNotifier with SafeChangeNotifier {
  final CallService _callService;
  final CallRepository _callRepository;
  final PQAuraService? _pqAuraService;
  PQAuraService get _pqAura => _pqAuraService ?? PQAuraService.instance;
  bool _isInitialized = false;
  bool _isEnding = false;
  Timer? _ringingTimer;

  CallState _state = CallState.initial();

  // Variables to retry the last call
  String? _lastConversationId;
  String? _lastCallerId;
  String? _lastReceiverId;
  CallType? _lastCallType;

  CallProvider({
    required CallService callService,
    required CallRepository callRepository,
    SupabaseClient? supabase,
    PQAuraService? pqAuraService,
  }) : _callService = callService,
       _callRepository = callRepository,
       _pqAuraService = pqAuraService {
    _callService.addListener(_onCallServiceUpdate);

    // Listen to auth state changes to automatically start/stop listener if Supabase is initialized
    try {
      final client = supabase ?? (SupabaseService.isInitialized ? Supabase.instance.client : null);
      client?.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          if (_isInitialized) {
            _startListenerWithRetry();
          }
        }
      });
    } catch (_) {}

    _startListenerWithRetry();
    _isInitialized = true;
  }

  bool _updateQueued = false;

  void _onCallServiceUpdate() {
    if (_isEnding || isDisposed) return;

    // Always sync the latest state from CallService
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

    // If state actually changed, debounce the notifyListeners
    if (newState != _state) {
      // Capture old state for transition detection before updating
      final oldActiveCallStatus = _state.activeCall?.status;
      _state = newState;

      if (!_updateQueued) {
        _updateQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateQueued = false;
          if (!isDisposed && !_isEnding) {
            // Check if call transitioned from ringing to active
            if (newState.activeCall?.status == CallStatus.active &&
                oldActiveCallStatus == CallStatus.ringing) {
              _ringingTimer?.cancel();
              _callService.stopRingtone();
            }
            notifyListeners();
          }
        });
      }
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
      _state = _state.copyWith(isLoading: true, clearError: true, isUnanswered: false);
      notifyListeners();

      // Store retry info
      _lastConversationId = conversationId;
      _lastCallerId = callerId;
      _lastReceiverId = receiverId;
      _lastCallType = type;

      // 1. Initialize local tracks
      await _callService.initLocalStream(type == CallType.video);

      // 1a. Generate random E2EE key
      final random = Random.secure();
      final e2eeKey = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
      
      // 1b. Encrypt via PQAuraService
      final encryptedOffer = await _pqAura.encryptMediaKey(receiverId, e2eeKey);

      // 2. Create call in DB with the offer
      final call = await _callRepository.createCall(
        conversationId: conversationId,
        callerId: callerId,
        receiverId: receiverId,
        type: type,
        offer: encryptedOffer,
      );

      // 3. Connect to LiveKit room and start ringtone
      await _callService.startSignaling(call, e2eeKey);
      await _callService.startRingtone();

      _state = _state.copyWith(activeCall: call, isLoading: false);

      // 4. Start ringing timeout (20 seconds)
      _ringingTimer?.cancel();
      _ringingTimer = Timer(const Duration(seconds: 20), () {
        if (_state.activeCall?.status == CallStatus.ringing) {
          markCallAsUnanswered();
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

  /// Mark the active call as unanswered/missed in the database and local state
  Future<void> markCallAsUnanswered() async {
    try {
      final callId = _state.activeCall?.id;
      if (callId == null) return;

      _ringingTimer?.cancel();
      _isEnding = true;
      _state = _state.copyWith(
        isLoading: true,
        clearError: true,
      );
      notifyListeners();

      // Update call status to missed in database
      await Supabase.instance.client
          .from('calls')
          .update({
            'status': CallStatus.missed.name,
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId);

      await _callService.endCall();

      _state = _state.copyWith(
        isLoading: false,
        isUnanswered: true,
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

  /// Clear the unanswered flag
  void clearUnanswered() {
    _state = _state.copyWith(isUnanswered: false);
    notifyListeners();
  }

  /// Retry the last initiated call
  Future<void> retryLastCall() async {
    if (_lastConversationId == null ||
        _lastCallerId == null ||
        _lastReceiverId == null ||
        _lastCallType == null) {
      return;
    }

    await initiateCall(
      conversationId: _lastConversationId!,
      callerId: _lastCallerId!,
      receiverId: _lastReceiverId!,
      type: _lastCallType!,
    );
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
      final acceptedCall = await _callRepository.acceptCall(
        callId: call.id,
        userId: call.receiverId,
      );

      // 3. Connect to LiveKit room
      await _callService.startSignaling(acceptedCall, _callService.e2eeKey);

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

      await _callRepository.declineCall(callId, userId);
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

      await _callRepository.endCall(callId);
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
      final calls = await _callRepository.getActiveCalls(userId);
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

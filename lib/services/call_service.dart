import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/desktop_call_notifier.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session_pkg;
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class DisabledCallService extends CallService {
  @override
  Future<void> initLocalStream(bool isVideo) async {}
  @override
  void startIncomingCallListener() {}
  @override
  Future<void> startSignaling(CallEntity call) async {}
  @override
  Future<Map<String, dynamic>> createOffer(String remoteUserId) async => {};
  @override
  Future<Map<String, dynamic>> createAnswer(String remoteUserId, Map<String, dynamic> offer) async => {};
  @override
  Future<void> endCall() async {}
  @override
  void toggleMute() {}
  @override
  Future<void> toggleVideo() async {}
  @override
  Future<void> toggleScreenShare() async {}
  @override
  Future<void> startRingtone() async {}
  @override
  Future<void> stopRingtone() async {}
}

class CallService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final SignalService _signal;
  final _uuid = const Uuid();
  final AudioPlayer _audioPlayer;
  bool _isPlayingRingtone = false;
  
  static const MethodChannel _callChannel = MethodChannel('oasis/call');

  CallService({
    SupabaseClient? supabase,
    SignalService? signalService,
    AudioPlayer? audioPlayer,
  })  : _supabase = supabase ?? SupabaseService().client,
        _signal = signalService ?? SignalService(),
        _audioPlayer = audioPlayer ?? AudioPlayer() {
    _callChannel.setMethodCallHandler(_handleNativeCall);
    // Check if the app was launched by accepting a call natively (Cold Start)
    checkInitialCall();
  }

  Future<void> checkInitialCall() async {
    try {
      final String? pendingCallId = await _callChannel.invokeMethod('getPendingCall');
      if (pendingCallId != null) {
        debugPrint('[CallService] Detected initial pending call: $pendingCallId');
        setAnswering(pendingCallId);
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('[CallService] Error checking initial call: $e');
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onCallAccepted':
        final String? callId = call.arguments['callId'];
        if (callId != null) {
          debugPrint('[CallService] Call accepted natively: $callId');
          setAnswering(callId);
          _safeNotifyListeners();
        }
        break;
    }
  }

  // Multi-peer management
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<Map<String, dynamic>>> _candidateQueue = {};
  final Map<String, List<Map<String, dynamic>>> _outgoingCandidateQueue = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _localRendererInitialized = false;

  final List<String> _callSteps = [];
  List<String> get callSteps => List.unmodifiable(_callSteps);

  void _recordStep(String step) {
    final msg = '[${DateTime.now().toIso8601String().split('T').last}] $step';
    _callSteps.add(msg);
    debugPrint('[CallService] STEP: $step');
    if (_callSteps.length > 100) _callSteps.removeAt(0);
  }

  void clearSteps() => _callSteps.clear();

  MediaStream? _localStream;
  String? _currentCallId;
  CallEntity? _currentCall;
  CallEntity? _incomingCall;
  
  StreamSubscription? _callSubscription;
  StreamSubscription? _incomingCallSubscription;
  RealtimeChannel? _signalingChannel;
  bool _isSignalingSubscribed = false;

  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isSpeakerphoneOn = false;

  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;
  RTCVideoRenderer get localRenderer => _localRenderer;
  CallEntity? get currentCall => _currentCall;
  CallEntity? get incomingCall => _incomingCall;
  String? get currentCallId => _currentCallId;
  bool get isMuted => _isMuted;
  bool get isVideoOn => _isVideoOn;
  bool get isSpeakerphoneOn => _isSpeakerphoneOn;

  void setAnswering(String callId) {
    _currentCallId = callId;
  }

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject'
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  bool _isScreenSharing = false;
  String? _remoteScreenShareUserId;

  bool get isScreenSharing => _isScreenSharing;
  String? get remoteScreenShareUserId => _remoteScreenShareUserId;

  void _safeNotifyListeners() {
    if (kIsWeb) {
      notifyListeners();
      return;
    }
    Future(() {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> initLocalStream(bool isVideo) async {
    _recordStep('initLocalStream(video: $isVideo)');
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        _recordStep('Microphone permission denied');
        throw Exception('Microphone permission denied');
      }

      if (isVideo) {
        final camStatus = await Permission.camera.request();
        if (camStatus != PermissionStatus.granted) {
          _recordStep('Camera permission denied');
          throw Exception('Camera permission denied');
        }
      }
    }

    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': isVideo ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      } : false,
    };

    if (!_localRendererInitialized) {
      await _localRenderer.initialize();
      _localRendererInitialized = true;
    }

    final oldStream = _localStream;
    _recordStep('Requesting getUserMedia');
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _recordStep('Local stream obtained: ${_localStream?.id}');
    
    for (var track in _localStream!.getAudioTracks()) {
      _recordStep('Enabling local audio track: ${track.id}');
      track.enabled = true;
    }

    _localRenderer.srcObject = _localStream;
    _isVideoOn = isVideo;
    _isMuted = false;
    _isSpeakerphoneOn = isVideo;

    if (_peerConnections.isNotEmpty) {
      _recordStep('Updating tracks in existing connections');
      for (var pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        for (var track in _localStream!.getTracks()) {
          final sender = senders.cast<RTCRtpSender?>().firstWhere(
            (s) => s?.track?.kind == track.kind,
            orElse: () => null,
          );
          if (sender != null) {
            _recordStep('Replacing ${track.kind} track');
            await sender.replaceTrack(track);
          } else {
            _recordStep('Adding ${track.kind} track');
            await pc.addTrack(track, _localStream!);
          }
        }
      }
    }

    if (oldStream != null) {
      for (var track in oldStream.getTracks()) {
        track.stop();
      }
    }

    await _configureAudioSession(_isSpeakerphoneOn, isVideo);
    _safeNotifyListeners();
  }

  Future<void> _configureAudioSession(bool speakerOn, bool isVideo) async {
    if (kIsWeb) return;
    try {
      debugPrint('[CallService] Configuring audio session: speaker=$speakerOn, isVideo=$isVideo');
      
      // On Windows, we still try to set speakerphone as it might trigger internal driver refreshes
      if (Platform.isWindows) {
        await Helper.setSpeakerphoneOn(true);
      }

      if (Platform.isIOS || Platform.isAndroid) {
        final session = await session_pkg.AudioSession.instance;
        await session.configure(session_pkg.AudioSessionConfiguration(
          avAudioSessionCategory: session_pkg.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              session_pkg.AVAudioSessionCategoryOptions.allowBluetooth |
              (speakerOn ? session_pkg.AVAudioSessionCategoryOptions.defaultToSpeaker : session_pkg.AVAudioSessionCategoryOptions.none),
          avAudioSessionMode: isVideo ? session_pkg.AVAudioSessionMode.videoChat : session_pkg.AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              session_pkg.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: session_pkg.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const session_pkg.AndroidAudioAttributes(
            contentType: session_pkg.AndroidAudioContentType.speech,
            usage: session_pkg.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: session_pkg.AndroidAudioFocusGainType.gain,
        ));
        await session.setActive(true);
        debugPrint('[CallService] Audio session activated');
        await Helper.setSpeakerphoneOn(speakerOn);
        debugPrint('[CallService] Speakerphone set to: $speakerOn');
      }
    } catch (e) {
      debugPrint('[CallService] Error configuring audio session: $e');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId) async {
    _recordStep('Creating PeerConnection for $remoteUserId');
    final pc = await createPeerConnection(_configuration);
    
    if (_localStream != null) {
      _recordStep('Adding local tracks to PC for $remoteUserId');
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (candidate) {
      Future(() {
        final data = {
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };
        
        if (!_isSignalingSubscribed) {
          _recordStep('Buffering outgoing ICE for $remoteUserId');
          _outgoingCandidateQueue[remoteUserId] ??= [];
          _outgoingCandidateQueue[remoteUserId]!.add(data);
        } else {
          _recordStep('Sending ICE candidate to $remoteUserId');
          _sendSignaling(remoteUserId, data);
        }
      });
    };

    pc.onTrack = (event) {
      _recordStep('onTrack: ${event.track.kind} from $remoteUserId');
      Future(() async {
        try {
          if (event.track.kind == 'audio') {
            _recordStep('Enabling remote audio track: ${event.track.id}');
            event.track.enabled = true;
          }

          // Use the provided stream if available, otherwise aggregate
          MediaStream stream;
          if (event.streams.isNotEmpty) {
            stream = event.streams[0];
          } else {
            _recordStep('No stream in onTrack, using/creating aggregate stream');
            _remoteStreams[remoteUserId] ??= await createLocalMediaStream('remote_$remoteUserId');
            final aggregate = _remoteStreams[remoteUserId]!;
            if (!aggregate.getTracks().any((t) => t.id == event.track.id)) {
              await aggregate.addTrack(event.track);
            }
            stream = aggregate;
          }
          _remoteStreams[remoteUserId] = stream;

          if (event.track.kind == 'video') {
            _recordStep('Initializing remote video renderer');
            if (!_remoteRenderers.containsKey(remoteUserId)) {
              final renderer = RTCVideoRenderer();
              await renderer.initialize();
              renderer.srcObject = stream;
              _remoteRenderers[remoteUserId] = renderer;
            } else {
              _remoteRenderers[remoteUserId]!.srcObject = stream;
            }
          }
          
          _safeNotifyListeners();
        } catch (e) {
          _recordStep('Error in onTrack: $e');
        }
      });
    };

    pc.onRenegotiationNeeded = () {
      debugPrint('[CallService] onRenegotiationNeeded for $remoteUserId');
      Future(() async {
        if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable) {
          debugPrint('[CallService] Skipping renegotiation: Signaling state is ${pc.signalingState}');
          return;
        }

        try {
          debugPrint('[CallService] Creating offer for renegotiation');
          final offer = await pc.createOffer();
          await pc.setLocalDescription(offer);
          await _sendSignaling(remoteUserId, {
            'type': 'offer',
            'sdp': offer.sdp,
            'sdp_type': offer.type,
          });
        } catch (e) {
          debugPrint('[CallService] Renegotiation error: $e');
        }
      });
    };

    pc.onConnectionState = (state) {
      _recordStep('Connection state: $state');
      Future(() {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _removePeer(remoteUserId);
        }
      });
    };

    pc.onIceConnectionState = (state) {
      _recordStep('ICE Connection state: $state');
    };

    pc.onSignalingState = (state) {
      _recordStep('Signaling state: $state');
    };

    _peerConnections[remoteUserId] = pc;
    return pc;
  }

  Future<void> _applyBitrateConstraints(RTCPeerConnection pc) async {
    final senders = await pc.getSenders();
    for (var sender in senders) {
      if (sender.track?.kind == 'video') {
        var parameters = sender.parameters;
        if (parameters.encodings != null && parameters.encodings!.isNotEmpty) {
          parameters.encodings![0].maxBitrate = 1500000;
          await sender.setParameters(parameters);
          debugPrint('[CallService] Applied bitrate constraints for video');
        }
      }
    }
  }

  Future<void> _sendSignaling(String recipientId, Map<String, dynamic> data) async {
    if (_currentCallId == null || _signalingChannel == null) {
      debugPrint('[CallService] Cannot send signaling: No call ID or signaling channel');
      return;
    }
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _signalingChannel!.sendBroadcastMessage(
        event: 'signaling',
        payload: {
          'sender_id': user.id,
          'recipient_id': recipientId,
          ...data,
        },
      );
    } catch (e) {
      debugPrint('[CallService] Error sending signaling broadcast: $e');
    }
  }

  Future<Map<String, dynamic>> _decryptData(String senderId, Map<String, dynamic> encryptedData, {int attempt = 0}) async {
    if (encryptedData['e2ee'] != true) return encryptedData;
    try {
      int signalType = encryptedData['signal_message_type'];
      if (signalType == 1) signalType = 3;
      final decryptedJson = await _signal.decryptMessage(senderId, encryptedData['payload'], signalType);
      if (decryptedJson.startsWith('🔒')) {
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
          return _decryptData(senderId, encryptedData, attempt: attempt + 1);
        }
        throw Exception('Decryption failed: Message locked');
      }
      return jsonDecode(decryptedJson);
    } catch (e) {
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 500));
        return _decryptData(senderId, encryptedData, attempt: attempt + 1);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOffer(String remoteUserId) async {
    debugPrint('[CallService] createOffer for $remoteUserId');
    final pc = await _getOrCreatePeerConnection(remoteUserId);
    final offer = await pc.createOffer();
    debugPrint('[CallService] Setting local description (offer)');
    await pc.setLocalDescription(offer);
    return {'type': 'offer', 'sdp': offer.sdp, 'sdp_type': offer.type};
  }

  Future<Map<String, dynamic>> createAnswer(String remoteUserId, Map<String, dynamic> offer) async {
    debugPrint('[CallService] createAnswer for $remoteUserId');
    final pc = await _getOrCreatePeerConnection(remoteUserId);
    debugPrint('[CallService] Setting remote description (offer)');
    await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['sdp_type']));
    final answer = await pc.createAnswer();
    debugPrint('[CallService] Setting local description (answer)');
    await pc.setLocalDescription(answer);
    await _applyBitrateConstraints(pc);
    await _flushCandidateQueue(remoteUserId, pc);
    return {'type': 'answer', 'sdp': answer.sdp, 'sdp_type': answer.type};
  }

  Future<void> startSignaling(CallEntity call) async {
    debugPrint('[CallService] Starting signaling for call: ${call.id}');
    _currentCallId = call.id;
    _currentCall = call;
    _subscribeToCall(call.id);
    _subscribeToSignaling(call.id);
    
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final remoteUserId = call.callerId == user.id ? call.receiverId : call.callerId;
      final pc = _peerConnections[remoteUserId];
      if (pc != null) {
        final rd = await pc.getRemoteDescription();
        if (rd != null) {
          await _flushCandidateQueue(remoteUserId, pc);
        }
      }
      
      // Safety flush for outgoing candidates if already subscribed
      if (_isSignalingSubscribed) {
        await _flushOutgoingCandidateQueue(remoteUserId);
      }
    }
    
    _safeNotifyListeners();
  }

  void _subscribeToCall(String callId) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    _callSubscription?.cancel();
    debugPrint('[CallService] Subscribing to call status updates for $callId');
    _callSubscription = _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .listen((data) {
          Future(() async {
            if (data.isNotEmpty) {
              final updatedCall = CallEntity.fromJson(data.first);
              final oldCall = _currentCall;
              _currentCall = updatedCall;

              if (updatedCall.status == CallStatus.ended || 
                  updatedCall.status == CallStatus.declined ||
                  updatedCall.status == CallStatus.missed) {
                debugPrint('[CallService] Call status updated to ${updatedCall.status}, cleaning up');
                _cleanup();
                return;
              }

              if (updatedCall.callerId == userId && 
                  updatedCall.status == CallStatus.active && 
                  oldCall?.status == CallStatus.ringing &&
                  updatedCall.answer != null) {
                try {
                  debugPrint('[CallService] Call accepted by remote, processing answer');
                  await _handleSignalingData(updatedCall.receiverId, updatedCall.answer!);
                } catch (e) {
                  debugPrint('[CallService] Error processing answer: $e');
                }
              }
              _safeNotifyListeners();
            }
          });
        });
  }

  void _subscribeToSignaling(String callId) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    _isSignalingSubscribed = false;
    debugPrint('[CallService] Subscribing to signaling broadcast for call_$callId');
    _signalingChannel = _supabase.channel('call_$callId');
    _signalingChannel!.onBroadcast(event: 'signaling', callback: (payload) {
      final senderId = payload['sender_id'];
      final recipientId = payload['recipient_id'];
      if (recipientId == userId && senderId != userId) {
        Future(() async {
          try {
            final decryptedData = await _decryptData(senderId, payload);
            debugPrint('[CallService] Received signaling event: ${decryptedData['type']} from $senderId');
            await _handleSignalingData(senderId, decryptedData);
          } catch (e) {
            debugPrint('[CallService] Signaling processing error: $e');
          }
        });
      }
    }).subscribe((status, [error]) {
      debugPrint('[CallService] Signaling channel status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSignalingSubscribed = true;
        final remoteUserId = _currentCall?.callerId == userId ? _currentCall?.receiverId : _currentCall?.callerId;
        if (remoteUserId != null) {
          _flushOutgoingCandidateQueue(remoteUserId);
        }
      }
      if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('[CallService] Signaling subscription error: $error');
      }
    });
  }

  Future<void> _flushOutgoingCandidateQueue(String remoteUserId) async {
    final candidates = _outgoingCandidateQueue[remoteUserId];
    if (candidates != null && _isSignalingSubscribed) {
      debugPrint('[CallService] Flushing ${candidates.length} outgoing candidates for $remoteUserId');
      for (var candidate in candidates) {
        await _sendSignaling(remoteUserId, candidate);
      }
      _outgoingCandidateQueue.remove(remoteUserId);
    }
  }

  Future<void> toggleScreenShare() async {
    try {
      debugPrint('[CallService] Toggling screen share: currently=$_isScreenSharing');
      if (_isScreenSharing) {
        _isScreenSharing = false;
        if (!kIsWeb && Platform.isAndroid) {
          try {
            final helper = Helper as dynamic;
            if (helper.stopForegroundService != null) await helper.stopForegroundService();
          } catch (_) {}
        }
        await initLocalStream(_isVideoOn);
      } else {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            final helper = Helper as dynamic;
            if (helper.startForegroundService != null) {
              await helper.startForegroundService(
                notificationId: 123,
                contentTitle: 'Screen Sharing',
                contentText: 'Sharing your screen',
                iconName: 'ic_launcher',
              );
            }
          } catch (_) {}
        }

        final Map<String, dynamic> mediaConstraints = {'audio': false, 'video': true};
        final MediaStream screenStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

        if (screenStream.getVideoTracks().isNotEmpty) {
          final screenTrack = screenStream.getVideoTracks().first;
          for (var pc in _peerConnections.values) {
            final senders = await pc.getSenders();
            final videoSender = senders.cast<RTCRtpSender?>().firstWhere(
              (s) => s?.track?.kind == 'video', orElse: () => null,
            );
            if (videoSender != null) {
              await videoSender.replaceTrack(screenTrack);
            } else {
              await pc.addTrack(screenTrack, screenStream);
            }
          }
          _isScreenSharing = true;
          final user = _supabase.auth.currentUser;
          if (user != null) {
            for (var remoteId in _peerConnections.keys) {
              await _sendSignaling(remoteId, {'type': 'screen_share_state', 'userId': user.id, 'isSharing': true});
            }
          }
          screenTrack.onEnded = () { if (_isScreenSharing) toggleScreenShare(); };
        }
      }
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('[CallService] Error toggling screen share: $e');
    }
  }

  Future<void> _handleSignalingData(String senderId, Map<String, dynamic> data) async {
    final type = data['type'];
    final pc = _peerConnections[senderId];
    
    Future(() async {
      try {
        final rd = pc != null ? await pc.getRemoteDescription() : null;
        if (type == 'offer') {
          if (pc != null && rd == null) {
            debugPrint('[CallService] Handling remote offer from $senderId');
            await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdp_type']));
            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            await _sendSignaling(senderId, {'type': 'answer', 'sdp': answer.sdp, 'sdp_type': answer.type});
            await _flushCandidateQueue(senderId, pc);
          } else if (pc != null) {
             debugPrint('[CallService] Skipping remote offer: remoteDescription already set for $senderId');
          }
        } else if (type == 'answer') {
          if (pc != null && pc.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer && rd == null) {
            debugPrint('[CallService] Handling remote answer from $senderId');
            await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdp_type']));
            await _applyBitrateConstraints(pc);
            await _flushCandidateQueue(senderId, pc);
          } else if (pc != null) {
            debugPrint('[CallService] Skipping remote answer: Signaling state is ${pc.signalingState} and remoteDescription is ${rd != null ? 'SET' : 'MISSING'}');
          }
        } else if (type == 'candidate') {
          if (pc != null && rd != null) {
            debugPrint('[CallService] Adding remote candidate from $senderId');
            await pc.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          } else {
            debugPrint('[CallService] Buffering incoming candidate from $senderId (PC ${pc != null ? 'EXISTS' : 'NULL'}, RemoteDescription ${rd != null ? 'SET' : 'MISSING'})');
            _candidateQueue[senderId] ??= [];
            _candidateQueue[senderId]!.add(data);
          }
        } else if (type == 'screen_share_state') {
          final isSharing = data['isSharing'] as bool;
          if (isSharing) {
            _remoteScreenShareUserId = data['userId'];
          } else if (_remoteScreenShareUserId == data['userId']) {
            _remoteScreenShareUserId = null;
          }
          _safeNotifyListeners();
        }
      } catch (e) {
        debugPrint('[CallService] Error handling signaling data ($type) for $senderId: $e');
      }
    });
  }

  Future<RTCPeerConnection> _getOrCreatePeerConnection(String remoteUserId) async {
    if (_peerConnections.containsKey(remoteUserId)) return _peerConnections[remoteUserId]!;
    return await _createPeerConnection(remoteUserId);
  }

  Future<void> _flushCandidateQueue(String senderId, RTCPeerConnection pc) async {
    final rd = await pc.getRemoteDescription();
    if (rd == null) {
      debugPrint('[CallService] Cannot flush candidate queue for $senderId: remoteDescription is null');
      return;
    }
    final candidates = _candidateQueue[senderId];
    if (candidates != null) {
      debugPrint('[CallService] Flushing ${candidates.length} buffered incoming candidates for $senderId');
      for (var candidate in candidates) {
        try {
          await pc.addCandidate(RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']));
        } catch (e) {
          debugPrint('[CallService] Error adding candidate during flush: $e');
        }
      }
      _candidateQueue.remove(senderId);
    }
  }

  void _removePeer(String remoteUserId) {
    _peerConnections[remoteUserId]?.close();
    _peerConnections.remove(remoteUserId);
    _remoteStreams[remoteUserId]?.getTracks().forEach((t) => t.stop());
    _remoteStreams.remove(remoteUserId);
    _remoteRenderers[remoteUserId]?.dispose();
    _remoteRenderers.remove(remoteUserId);
    _safeNotifyListeners();
  }

  void _cleanup() {
    _stopRingtone();
    _callSubscription?.cancel();
    _callSubscription = null;
    _signalingChannel?.unsubscribe();
    _signalingChannel = null;
    _isSignalingSubscribed = false;
    
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final helper = Helper as dynamic;
        if (helper.stopForegroundService != null) helper.stopForegroundService();
      } catch (_) {}
    }
    
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    if (_localRendererInitialized) {
      _localRenderer.srcObject = null;
    }
    for (var pc in _peerConnections.values) pc.close();
    _peerConnections.clear();
    for (var stream in _remoteStreams.values) stream.getTracks().forEach((track) => track.stop());
    _remoteStreams.clear();
    for (var renderer in _remoteRenderers.values) renderer.dispose();
    _remoteRenderers.clear();
    _currentCallId = null;
    _currentCall = null;
    _incomingCall = null;
    _candidateQueue.clear();
    _outgoingCandidateQueue.clear();
    _isScreenSharing = false;
    _remoteScreenShareUserId = null;
    _safeNotifyListeners();
  }

  void startIncomingCallListener() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[CallService] Cannot start incoming call listener: No user logged in');
      return;
    }
    
    final userId = user.id;
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = _supabase.from('calls').stream(primaryKey: ['id']).eq('receiver_id', userId).listen((data) {
      if (data.isNotEmpty) {
        final ringingCalls = data.where((json) => json['status'] == CallStatus.ringing.name.toLowerCase()).toList();
        if (ringingCalls.isNotEmpty) {
          final call = CallEntity.fromJson(ringingCalls.first);
          if (_currentCallId == null && _incomingCall?.id != call.id) {
            _incomingCall = call;
            _playRingtone();
            DesktopCallNotifier.instance.handleIncomingCall(callId: call.id, callerName: 'Incoming Call', senderId: call.callerId);
            _safeNotifyListeners();
          }
        } else if (_incomingCall != null) {
          _incomingCall = null;
          _stopRingtone();
          _safeNotifyListeners();
        }
      } else if (_incomingCall != null) {
        _incomingCall = null;
        _stopRingtone();
        _safeNotifyListeners();
      }
    });
  }

  Future<void> endCall() async { _cleanup(); }

  void toggleMute() {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      for (var track in _localStream!.getAudioTracks()) track.enabled = !_isMuted;
      _safeNotifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream == null) return;
    if (_localStream!.getVideoTracks().isEmpty && !_isVideoOn) {
      try {
        final videoStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}}
        });
        if (videoStream.getVideoTracks().isNotEmpty) {
          final videoTrack = videoStream.getVideoTracks().first;
          await _localStream!.addTrack(videoTrack);
          _isVideoOn = true;
          for (var pc in _peerConnections.values) {
            final senders = await pc.getSenders();
            final videoSender = senders.cast<RTCRtpSender?>().firstWhere(
              (s) => s?.track?.kind == 'video', orElse: () => null,
            );
            if (videoSender != null) {
              await videoSender.replaceTrack(videoTrack);
            } else {
              await pc.addTrack(videoTrack, _localStream!);
            }
          }
        }
      } catch (e) {
        debugPrint('[CallService] Error enabling video: $e');
      }
    } else {
      _isVideoOn = !_isVideoOn;
      for (var track in _localStream!.getVideoTracks()) track.enabled = _isVideoOn;
    }
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) await _configureAudioSession(_isSpeakerphoneOn, _isVideoOn);
    _safeNotifyListeners();
  }

  void toggleSpeakerphone() {
    _isSpeakerphoneOn = !_isSpeakerphoneOn;
    _configureAudioSession(_isSpeakerphoneOn, _isVideoOn);
    _safeNotifyListeners();
  }

  Future<void> _playRingtone() async {
    if (_isPlayingRingtone) return;
    _isPlayingRingtone = true;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/standardringtone.mp3'));
    } catch (_) { _isPlayingRingtone = false; }
  }

  Future<void> _stopRingtone() async {
    _isPlayingRingtone = false;
    await _audioPlayer.stop();
    DesktopCallNotifier.instance.dismissIncomingCall();
  }

  Future<void> startRingtone() => _playRingtone();
  Future<void> stopRingtone() => _stopRingtone();

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _callSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

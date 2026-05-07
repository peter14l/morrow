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
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _localRendererInitialized = false;

  MediaStream? _localStream;
  String? _currentCallId;
  CallEntity? _currentCall;
  CallEntity? _incomingCall;
  
  StreamSubscription? _callSubscription;
  StreamSubscription? _incomingCallSubscription;
  RealtimeChannel? _signalingChannel;

  bool _isMuted = false;
  bool _isVideoOn = true;

  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;
  RTCVideoRenderer get localRenderer => _localRenderer;
  CallEntity? get currentCall => _currentCall;
  CallEntity? get incomingCall => _incomingCall;
  String? get currentCallId => _currentCallId;

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

  bool get isMuted => _isMuted;
  bool get isVideoOn => _isVideoOn;
  bool get isScreenSharing => _isScreenSharing;
  String? get remoteScreenShareUserId => _remoteScreenShareUserId;

  void _safeNotifyListeners() {
    if (kIsWeb) {
      notifyListeners();
      return;
    }
    // Ensure notifyListeners is always called on the UI/Platform thread.
    // Future.microtask may still run on a background thread if scheduled from one.
    // Using Future() ensures it goes to the main event loop.
    Future(() {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> initLocalStream(bool isVideo) async {
    debugPrint('[CallService] Initializing local stream: video=$isVideo');
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) throw Exception('Microphone permission denied');

      if (isVideo) {
        final camStatus = await Permission.camera.request();
        if (camStatus != PermissionStatus.granted) throw Exception('Camera permission denied');
      }
    }

    final Map<String, dynamic> constraints = {
      'audio': true, // Simplified constraints for better compatibility
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
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    
    // Explicitly enable audio tracks and log status
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = true;
      debugPrint('[CallService] Local audio track: id=${track.id}, enabled=${track.enabled}, kind=${track.kind}');
    }

    _localRenderer.srcObject = _localStream;
    _isVideoOn = isVideo;
    _isMuted = false;

    // If we have active peer connections, update their tracks
    if (_peerConnections.isNotEmpty) {
      for (var pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        for (var track in _localStream!.getTracks()) {
          final sender = senders.cast<RTCRtpSender?>().firstWhere(
            (s) => s?.track?.kind == track.kind,
            orElse: () => null,
          );
          if (sender != null) {
            await sender.replaceTrack(track);
          } else {
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

    await _configureAudioSession(isVideo);
    _safeNotifyListeners();
  }

  Future<void> _configureAudioSession(bool isVideo) async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        final session = await session_pkg.AudioSession.instance;
        await session.configure(session_pkg.AudioSessionConfiguration(
          avAudioSessionCategory: session_pkg.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              session_pkg.AVAudioSessionCategoryOptions.allowBluetooth |
              session_pkg.AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: isVideo ? session_pkg.AVAudioSessionMode.videoChat : session_pkg.AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy:
              session_pkg.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: session_pkg.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const session_pkg.AndroidAudioAttributes(
            contentType: session_pkg.AndroidAudioContentType.speech,
            usage: session_pkg.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: session_pkg.AndroidAudioFocusGainType.gainTransient,
        ));
        await session.setActive(true);

        // This hint still helps some Android versions, but the AudioSession
        // configuration above ensures Bluetooth/Headset priority.
        await Helper.setSpeakerphoneOn(isVideo);
      }
    } catch (e) {
      debugPrint('[CallService] Error configuring audio session: $e');
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId) async {
    debugPrint('[CallService] Creating peer connection for $remoteUserId');
    final pc = await createPeerConnection(_configuration);
    
    // Add local tracks to peer connection
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (candidate) {
      // Jump to main event loop to avoid threading issues on Windows
      Future(() {
        _sendSignaling(remoteUserId, {
          'type': 'candidate',
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      });
    };

    pc.onTrack = (event) {
      debugPrint('[CallService] onTrack: ${event.track.kind} from $remoteUserId');
      
      // Use Future() instead of Future.microtask to guarantee we escape the background thread 
      // where this callback might have been triggered from the native side.
      Future(() async {
        try {
          if (event.track.kind == 'audio') {
            event.track.enabled = true;
          }

          MediaStream stream;
          if (event.streams.isNotEmpty) {
            stream = event.streams[0];
          } else {
            // Fallback for some legacy WebRTC implementations
            _remoteStreams[remoteUserId] ??= await createLocalMediaStream('remote_$remoteUserId');
            await _remoteStreams[remoteUserId]!.addTrack(event.track);
            stream = _remoteStreams[remoteUserId]!;
          }
          _remoteStreams[remoteUserId] = stream;

          if (event.track.kind == 'video') {
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
          debugPrint('[CallService] Error in onTrack: $e');
        }
      });
    };

    pc.onRenegotiationNeeded = () {
      debugPrint('[CallService] onRenegotiationNeeded for $remoteUserId');
      Future(() async {
        if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable) return;

        try {
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
      debugPrint('[CallService] Connection state for $remoteUserId: $state');
      Future(() {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _removePeer(remoteUserId);
        }
      });
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
        }
      }
    }
  }

  Future<void> _sendSignaling(String recipientId, Map<String, dynamic> data) async {
    if (_currentCallId == null || _signalingChannel == null) return;
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
      debugPrint('[CallService] Error sending signaling: $e');
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
    final pc = await _getOrCreatePeerConnection(remoteUserId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return {'type': 'offer', 'sdp': offer.sdp, 'sdp_type': offer.type};
  }

  Future<Map<String, dynamic>> createAnswer(String remoteUserId, Map<String, dynamic> offer) async {
    final pc = await _getOrCreatePeerConnection(remoteUserId);
    await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['sdp_type']));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _applyBitrateConstraints(pc);
    
    // IMPORTANT: Flush any queued candidates that arrived while ringing
    await _flushCandidateQueue(remoteUserId, pc);
    
    return {'type': 'answer', 'sdp': answer.sdp, 'sdp_type': answer.type};
  }

  Future<void> startSignaling(CallEntity call) async {
    _currentCallId = call.id;
    _currentCall = call;
    _subscribeToCall(call.id);
    _subscribeToSignaling(call.id);
    
    // Also try to flush candidates here if PC already exists
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final remoteUserId = call.callerId == user.id ? call.receiverId : call.callerId;
      final pc = _peerConnections[remoteUserId];
      if (pc != null) {
        await _flushCandidateQueue(remoteUserId, pc);
      }
    }
    
    _safeNotifyListeners();
  }

  void _subscribeToCall(String callId) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    _callSubscription?.cancel();
    _callSubscription = _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .listen((data) {
          // Wrap in Future to escape stream listener thread
          Future(() async {
            if (data.isNotEmpty) {
              final updatedCall = CallEntity.fromJson(data.first);
              final oldCall = _currentCall;
              _currentCall = updatedCall;

              if (updatedCall.status == CallStatus.ended || 
                  updatedCall.status == CallStatus.declined ||
                  updatedCall.status == CallStatus.missed) {
                _cleanup();
                return;
              }

              if (updatedCall.callerId == userId && 
                  updatedCall.status == CallStatus.active && 
                  oldCall?.status == CallStatus.ringing &&
                  updatedCall.answer != null) {
                try {
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

    _signalingChannel = _supabase.channel('call_$callId');
    _signalingChannel!.onBroadcast(event: 'signaling', callback: (payload) {
      final senderId = payload['sender_id'];
      final recipientId = payload['recipient_id'];
      if (recipientId == userId && senderId != userId) {
        // Ensure we handle signaling data on the main event loop
        Future(() async {
          try {
            final decryptedData = await _decryptData(senderId, payload);
            await _handleSignalingData(senderId, decryptedData);
          } catch (e) {
            debugPrint('[CallService] Signaling processing error: $e');
          }
        });
      }
    }).subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('[CallService] Signaling subscription error: $error');
      }
    });
  }

  Future<void> toggleScreenShare() async {
    try {
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
    
    Future.microtask(() async {
      try {
        if (type == 'offer') {
          if (pc != null) {
            await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdp_type']));
            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            await _sendSignaling(senderId, {'type': 'answer', 'sdp': answer.sdp, 'sdp_type': answer.type});
          }
        } else if (type == 'answer') {
          if (pc != null && (pc.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer || 
                             pc.signalingState == RTCSignalingState.RTCSignalingStateStable)) {
            await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['sdp_type']));
            await _applyBitrateConstraints(pc);
            await _flushCandidateQueue(senderId, pc);
          }
        } else if (type == 'candidate') {
          if (pc != null) {
            await pc.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          } else {
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
        debugPrint('[CallService] Error handling signaling: $e');
      }
    });
  }

  Future<RTCPeerConnection> _getOrCreatePeerConnection(String remoteUserId) async {
    if (_peerConnections.containsKey(remoteUserId)) return _peerConnections[remoteUserId]!;
    return await _createPeerConnection(remoteUserId);
  }

  Future<void> _flushCandidateQueue(String senderId, RTCPeerConnection pc) async {
    final candidates = _candidateQueue[senderId];
    if (candidates != null) {
      for (var candidate in candidates) {
        await pc.addCandidate(RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']));
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
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) await _configureAudioSession(_isVideoOn);
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

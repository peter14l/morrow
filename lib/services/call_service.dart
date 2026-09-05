import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/desktop_call_notifier.dart';
import 'package:oasis/services/notification_manager.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:universal_io/io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';

class CallService extends ChangeNotifier {
  static CallService? _instance;
  static CallService get instance => _instance ?? CallService();

  final SupabaseClient? _supabaseClient;
  SupabaseClient get _supabase => _supabaseClient ?? SupabaseService().client;
  AudioPlayer? _audioPlayerInstance;
  AudioPlayer get _audioPlayer => _audioPlayerInstance ??= AudioPlayer();
  bool _isPlayingRingtone = false;

  CallEntity? _currentCall;
  CallEntity? _incomingCall;
  String? _currentCallId;
  Uint8List? e2eeKey;
  Room? _room;
  String? _lastEndedCallId;
  DateTime? _lastEndedTimestamp;

  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isSpeakerphoneOn = false;
  bool _isScreenSharing = false;

  StreamSubscription? _incomingCallSubscription;
  RealtimeChannel? _callBroadcastChannel;
  Timer? _notifyDebounce;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  CallService({
    SupabaseClient? supabase,
    AudioPlayer? audioPlayer,
  }) : _supabaseClient = supabase,
       _audioPlayerInstance = audioPlayer {
    _instance = this;
    if (audioPlayer != null) {
      _configureAudioPlayer();
    }
  }

  /// Debounced notifyListeners to batch rapid state changes (e.g. LiveKit events)
  void _scheduleNotify() {
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 16), () {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  void _configureAudioPlayer() {
    if (kIsWeb) return;
    try {
      _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            // voiceCommunicationSignalling is correct for incoming call ringtones.
            // notificationRingtone bypasses the active audio output device on Android.
            usageType: AndroidUsageType.voiceCommunicationSignalling,
            contentType: AndroidContentType.sonification,
            // Request exclusive transient focus so Android routes audio to the
            // currently active output device (Bluetooth headset, speaker, etc.)
            // instead of blasting through all available outputs simultaneously.
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              // allowBluetooth: routes to Bluetooth HFP (mono call profile)
              AVAudioSessionOptions.allowBluetooth,
              // allowBluetoothA2DP: routes to Bluetooth A2DP (stereo profile)
              AVAudioSessionOptions.allowBluetoothA2DP,
              // Do NOT include defaultToSpeaker — it overrides Bluetooth routing
              // and forces audio to the built-in speaker even when a headset is
              // connected, which causes the double-output the user is experiencing.
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallService] setAudioContext is not supported on this platform: $e');
    }
  }

  /// Configure the system audio session for call audio (WebRTC/LiveKit).
  /// This ensures proper audio routing to speaker/earpiece/Bluetooth.
  Future<void> _configureCallAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await audio_session.AudioSession.instance;
      await session.configure(const audio_session.AudioSessionConfiguration.speech());
    } catch (e) {
      debugPrint('[CallService] Audio session configuration not supported on this platform: $e');
    }
  }

  // Getters
  CallEntity? get currentCall => _currentCall;
  CallEntity? get incomingCall => _incomingCall;
  String? get currentCallId => _currentCallId;
  bool get isMuted => _isMuted;
  bool get isVideoOn => _isVideoOn;
  bool get isSpeakerphoneOn => _isSpeakerphoneOn;
  bool get isScreenSharing => _isScreenSharing;
  Room? get room => _room;

  final List<String> _callSteps = [];
  List<String> get callSteps => List.unmodifiable(_callSteps);

  void _recordStep(String step) {
    final msg = '[${DateTime.now().toIso8601String().split('T').last}] $step';
    _callSteps.add(msg);
    debugPrint('[CallService] STEP: $step');
    if (_callSteps.length > 100) _callSteps.removeAt(0);
  }

  void setAnswering(String callId) {
    _currentCallId = callId;
  }

  Future<void> initLocalStream(bool isVideo) async {
    _recordStep('initLocalStream(video: $isVideo)');
    _isVideoOn = isVideo;
    _isMuted = false;
    _isSpeakerphoneOn = isVideo;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await [Permission.microphone, Permission.camera].request();
    }
  }

  Future<void> startSignaling(CallEntity call, [Uint8List? key]) async {
    _recordStep('startSignaling for call: ${call.id}');
    _currentCall = call;
    _currentCallId = call.id;
    if (key != null) {
      e2eeKey = key;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Send low-latency broadcast signaling message to receiver
    final targetUserId = user.id == call.callerId ? call.receiverId : call.callerId;
    final signalChannel = _supabase.channel('call_signaling:$targetUserId');
    signalChannel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await signalChannel.sendBroadcastMessage(
          event: 'invite',
          payload: {
            'call': call.toJson(),
            'e2ee_key': e2eeKey != null ? base64Encode(e2eeKey!) : null,
          },
        );
        _recordStep('Call invite broadcasted to $targetUserId');
      }
    });

    // Fetch token
    final token = await _getLiveKitToken(call.roomName, user.id);
    if (token == null) {
      _recordStep('Failed to get LiveKit token');
      return;
    }

      // Connect to room
    try {
      RoomOptions roomOptions = const RoomOptions();

      if (e2eeKey != null) {
        try {
          final keyProvider = await BaseKeyProvider.create();
          await keyProvider.setKey(base64Encode(e2eeKey!));
          final e2eeOptions = E2EEOptions(keyProvider: keyProvider);
          roomOptions = RoomOptions(encryption: e2eeOptions);
          _recordStep('E2EE initialized with PQ-DR key');
        } catch (e) {
          _recordStep('E2EE FrameCryptor not supported on this platform: $e. Falling back to standard transport security.');
        }
      }

_room = Room(roomOptions: roomOptions);
      
      // Configure audio session for proper call audio routing
      await _configureCallAudioSession();
       
      // Use createListener() to listen for Room events
      final listener = _room!.createListener();
      _setupRoomListeners(listener);

      await _room!.connect(AppConfig.liveKitUrl, token, fastConnectOptions: FastConnectOptions(
        microphone: const TrackOption(enabled: true),
        camera: TrackOption(enabled: _isVideoOn),
      ));

      _recordStep('Connected to LiveKit room');

      NotificationManager.instance.showActiveCallNotification(
        callId: call.id,
        participantName: 'Call in Progress',
      );
    } catch (e) {
      _recordStep('Error connecting to room: $e');
    }

    _scheduleNotify();
  }

  void _setupRoomListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomDisconnectedEvent>((event) {
        _recordStep('Room disconnected: ${event.reason}');
        _cleanup();
      })
      ..on<ParticipantConnectedEvent>((event) {
        _recordStep('Participant connected: ${event.participant.identity}');
        _scheduleNotify();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _recordStep('Participant disconnected: ${event.participant.identity}');
        if (_room?.remoteParticipants.isEmpty ?? true) {
          _recordStep('No more participants, ending call');
          endCall();
        }
        _scheduleNotify();
      })
      ..on<TrackSubscribedEvent>((event) {
        _recordStep('Track subscribed: ${event.track.sid}');
        _scheduleNotify();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _recordStep('Track unsubscribed: ${event.track.sid}');
        _scheduleNotify();
      })
      ..on<LocalTrackPublishedEvent>((event) {
        _recordStep('Local track published: ${event.publication.sid}');
        _scheduleNotify();
      });
  }

  Future<String?> _getLiveKitToken(String roomName, String identity) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-livekit-token',
        body: {'roomName': roomName, 'identity': identity},
      );
      if (response.status == 200) {
        return response.data['token'] as String;
      }
      return null;
    } catch (e) {
      _recordStep('Error getting LiveKit token: $e');
      return null;
    }
  }

  void startIncomingCallListener() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final userId = user.id;
    _incomingCallSubscription?.cancel();

    // Set up Broadcast Channel for real-time low-latency calling signaling (WhatsApp/Instagram style)
    _callBroadcastChannel?.unsubscribe();
    _callBroadcastChannel = _supabase.channel('call_signaling:$userId');
    _callBroadcastChannel!
        .onBroadcast(
          event: 'invite',
          callback: (payload) async {
            debugPrint('[CallService] Received broadcast invite: $payload');
            final callMap = payload['call'] as Map<String, dynamic>;
            final call = CallEntity.fromJson(callMap);
            final e2eeKeyBase64 = payload['e2ee_key'] as String?;

            // Ignore stale calls on broadcast channel too
            final age = DateTime.now().toUtc().difference(call.createdAt.toUtc()).inSeconds;
            if (age > 45) {
              debugPrint('[CallService] Stale broadcast invite (age: ${age}s). Ignoring.');
              return;
            }

            if (_currentCallId == null && _incomingCall?.id != call.id) {
              if (e2eeKeyBase64 != null) {
                e2eeKey = base64Decode(e2eeKeyBase64);
              }
              _incomingCall = call;
              _playRingtone();
              DesktopCallNotifier.instance.handleIncomingCall(
                callId: call.id,
                callerName: 'Incoming Call',
                senderId: call.callerId,
              );
              notifyListeners();
            }
          },
        )
        .onBroadcast(
          event: 'end',
          callback: (payload) async {
            final callId = payload['call_id'] as String;
            debugPrint('[CallService] Received broadcast end call event for: $callId');
            if (_incomingCall?.id == callId || _currentCall?.id == callId) {
              await _cleanup();
            }
          },
        )
        .subscribe();

    _incomingCallSubscription = _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .listen((data) async {
          if (data.isNotEmpty) {
            final ringingCalls = data
                .where(
                  (json) =>
                      json['status'] == CallStatus.ringing.name.toLowerCase(),
                )
                .toList();
            if (ringingCalls.isNotEmpty) {
              final call = CallEntity.fromJson(ringingCalls.first);

              // Ignore and mark as missed if the call is stale (older than 30 seconds)
              final age = DateTime.now().toUtc().difference(call.createdAt.toUtc()).inSeconds;
              if (age > 30 || call.endedAt != null) {
                if (age > 30) {
                  debugPrint('[CallService] Stale call detected (age: ${age}s). Marking as missed.');
                  try {
                    await _supabase
                        .from('calls')
                        .update({'status': CallStatus.missed.name})
                        .eq('id', call.id);
                  } catch (e) {
                    debugPrint('[CallService] Error marking stale call as missed: $e');
                  }
                }
                return;
              }

              final isRecentlyEnded =
                  _lastEndedCallId == call.id &&
                  _lastEndedTimestamp != null &&
                  DateTime.now().difference(_lastEndedTimestamp!).inSeconds < 5;

              if (_currentCallId == null &&
                  _incomingCall?.id != call.id &&
                  !isRecentlyEnded) {
                
                // Decrypt PQ-DR E2EE Key from the offer
                if (call.offer != null) {
                  e2eeKey = await PQAuraService.instance.decryptMediaKey(call.callerId, call.offer!);
                }

                _incomingCall = call;
                _playRingtone();
                DesktopCallNotifier.instance.handleIncomingCall(
                  callId: call.id,
                  callerName: 'Incoming Call',
                  senderId: call.callerId,
                );
                notifyListeners();
              }
            } else if (_incomingCall != null) {
              _incomingCall = null;
              _stopRingtone();
              notifyListeners();
            }
          } else if (_incomingCall != null) {
            _incomingCall = null;
            _stopRingtone();
            notifyListeners();
          }
        }, onError: (error) {
          debugPrint('[CallService] Incoming call stream error: $error');
          // Re-subscribe on error so we don't miss calls after a WS reconnect.
          Future.delayed(const Duration(seconds: 3), startIncomingCallListener);
        });
  }

  Future<void> endCall() async {
    _recordStep('Ending call');
    final callId = _currentCall?.id ?? _incomingCall?.id;
    final receiverId = _currentCall?.receiverId ?? _currentCall?.callerId ?? _incomingCall?.callerId;

    if (callId != null && receiverId != null) {
      final signalChannel = _supabase.channel('call_signaling:$receiverId');
      signalChannel.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await signalChannel.sendBroadcastMessage(
            event: 'end',
            payload: {'call_id': callId},
          );
        }
      });
    }

    if (_currentCall != null) {
      await _supabase
          .from('calls')
          .update({'status': CallStatus.ended.name, 'ended_at': DateTime.now().toIso8601String()})
          .eq('id', _currentCall!.id);
    }
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _recordStep('Cleaning up call resources');
    _notifyDebounce?.cancel();

    if (_currentCallId != null) {
      _lastEndedCallId = _currentCallId;
      _lastEndedTimestamp = DateTime.now();
    }

    await _stopRingtone();
    NotificationManager.instance.dismissActiveCallNotification();

    await _room?.disconnect();
    await _room?.dispose();
    _room = null;

    _currentCallId = null;
    _currentCall = null;
    _incomingCall = null;
    _isScreenSharing = false;

    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    _isVideoOn = !_isVideoOn;
    await _room?.localParticipant?.setCameraEnabled(_isVideoOn);
    notifyListeners();
  }

  Future<void> toggleScreenShare() async {
    _isScreenSharing = !_isScreenSharing;
    await _room?.localParticipant?.setScreenShareEnabled(_isScreenSharing);
    notifyListeners();
  }

  void toggleSpeakerphone() async {
    _isSpeakerphoneOn = !_isSpeakerphoneOn;
    
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final session = await audio_session.AudioSession.instance;
        await session.configure(audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: _isSpeakerphoneOn
              ? audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker
              : audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.speech,
            flags: audio_session.AndroidAudioFlags.none,
            usage: audio_session.AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gainTransientExclusive,
          androidWillPauseWhenDucked: false,
        ));
        await session.setActive(true);
      } catch (e) {
        debugPrint('[CallService] Error toggling speakerphone: $e');
      }
    }
    _scheduleNotify();
  }

  Future<void> _playRingtone() async {
    if (kIsWeb) return;
    if (_isPlayingRingtone) return;
    _isPlayingRingtone = true;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/standardringtone.mp3'));
    } catch (e) {
      _isPlayingRingtone = false;
    }
  }

  Future<void> _stopRingtone() async {
    if (kIsWeb) return;
    _isPlayingRingtone = false;
    try {
      await _audioPlayer.stop();
    } catch (e) {}
    DesktopCallNotifier.instance.dismissIncomingCall();
  }

  Future<void> startRingtone() => _playRingtone();
  Future<void> stopRingtone() => _stopRingtone();

  Future<void> inviteToCall(String userId) async {
    if (_currentCall == null) return;
    _recordStep('Inviting user $userId to call');

    await _supabase.from('calls').insert({
      'conversation_id': _currentCall!.conversationId,
      'caller_id': _supabase.auth.currentUser!.id,
      'receiver_id': userId,
      'type': _currentCall!.type.name,
      'status': CallStatus.ringing.name,
      'created_at': DateTime.now().toIso8601String(),
      'offer': {'room_name': _currentCall!.roomName},
    });
  }

  // Compatibility stubs — not used in the LiveKit-based call flow.
  // These exist to satisfy the interface if legacy code references them.
  Future<Map<String, dynamic>> createOffer(String remoteUserId) async =>
      throw UnsupportedError('Legacy createOffer not used with LiveKit signaling');
  Future<Map<String, dynamic>> createAnswer(String remoteUserId, Map<String, dynamic> offer) async =>
      throw UnsupportedError('Legacy createAnswer not used with LiveKit signaling');

  @override
  void dispose() {
    _isDisposed = true;
    _notifyDebounce?.cancel();
    _incomingCallSubscription?.cancel();
    _audioPlayer.dispose();
    _room?.dispose();
    super.dispose();
  }
}

class DisabledCallService extends CallService {
  @override
  Future<void> initLocalStream(bool isVideo) async {}
  @override
  Future<void> startSignaling(CallEntity call, [Uint8List? key]) async {}
  @override
  void startIncomingCallListener() {}
  @override
  Future<void> endCall() async {}
  @override
  void toggleMute() {}
  @override
  Future<void> toggleVideo() async {}
  @override
  void toggleSpeakerphone() {}
  @override
  Future<void> toggleScreenShare() async {}
}

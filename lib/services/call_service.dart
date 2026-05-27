import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/desktop_call_notifier.dart';
import 'package:oasis/services/notification_manager.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:universal_io/io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service_io.dart';

class CallService extends ChangeNotifier {
  static CallService? _instance;
  static CallService get instance => _instance ?? CallService();

  final SupabaseClient _supabase;
  final AudioPlayer _audioPlayer;
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

  CallService({
    SupabaseClient? supabase,
    AudioPlayer? audioPlayer,
  }) : _supabase = supabase ?? SupabaseService().client,
       _audioPlayer = audioPlayer ?? AudioPlayer() {
    _instance = this;
    _initBackgroundService();
    _configureAudioPlayer();
  }

  Future<void> _initBackgroundService() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        const androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: 'Oasis Call',
          notificationText: 'Active call in progress',
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        );
        await FlutterBackground.initialize(androidConfig: androidConfig);
      } catch (e) {
        debugPrint('[CallService] Error initializing background service: $e');
      }
    }
  }

  void _configureAudioPlayer() {
    if (kIsWeb) return;
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
    notifyListeners();
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
        final keyProvider = await BaseKeyProvider.create();
        await keyProvider.setKey(base64Encode(e2eeKey!));
        final e2eeOptions = E2EEOptions(keyProvider: keyProvider);
        roomOptions = RoomOptions(e2ee: e2eeOptions);
        _recordStep('E2EE initialized with PQ-DR key');
      }

      _room = Room(roomOptions: roomOptions);
      
      // Use createListener() to listen for Room events
      final listener = _room!.createListener();
      _setupRoomListeners(listener);

      await _room!.connect(AppConfig.liveKitUrl, token, fastConnectOptions: FastConnectOptions(
        microphone: const TrackOption(enabled: true),
        camera: TrackOption(enabled: _isVideoOn),
      ));

      _recordStep('Connected to LiveKit room');

      if (!kIsWeb && Platform.isAndroid) {
        await FlutterBackground.enableBackgroundExecution();
      }

      NotificationManager.instance.showActiveCallNotification(
        callId: call.id,
        participantName: 'Call in Progress',
      );
    } catch (e) {
      _recordStep('Error connecting to room: $e');
    }

    notifyListeners();
  }

  void _setupRoomListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomDisconnectedEvent>((event) {
        _recordStep('Room disconnected: ${event.reason}');
        _cleanup();
      })
      ..on<ParticipantConnectedEvent>((event) {
        _recordStep('Participant connected: ${event.participant.identity}');
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _recordStep('Participant disconnected: ${event.participant.identity}');
        if (_room?.remoteParticipants.isEmpty ?? true) {
          _recordStep('No more participants, ending call');
          endCall();
        }
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((event) {
        _recordStep('Track subscribed: ${event.track.sid}');
        notifyListeners();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _recordStep('Track unsubscribed: ${event.track.sid}');
        notifyListeners();
      })
      ..on<LocalTrackPublishedEvent>((event) {
        _recordStep('Local track published: ${event.publication.sid}');
        notifyListeners();
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
        });
  }

  Future<void> endCall() async {
    _recordStep('Ending call');
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

    if (_currentCallId != null) {
      _lastEndedCallId = _currentCallId;
      _lastEndedTimestamp = DateTime.now();
    }

    await _stopRingtone();
    NotificationManager.instance.dismissActiveCallNotification();

    if (!kIsWeb && Platform.isAndroid) {
      await FlutterBackground.disableBackgroundExecution();
    }

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

  void toggleSpeakerphone() {
    _isSpeakerphoneOn = !_isSpeakerphoneOn;
    // LiveKit manages audio routing via underlying WebRTC/OS settings
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Hardware helper could be used here if needed
    }
    notifyListeners();
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

  // Compatibility methods for CallProvider (will be refactored or kept as stubs)
  Future<Map<String, dynamic>> createOffer(String remoteUserId) async => {};
  Future<Map<String, dynamic>> createAnswer(String remoteUserId, Map<String, dynamic> offer) async => {};

  @override
  void dispose() {
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
  Future<void> startSignaling(CallEntity call) async {}
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

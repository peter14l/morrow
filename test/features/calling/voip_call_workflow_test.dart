import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/calling/domain/repositories/call_repository.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';

class _FakePQAuraService implements PQAuraService {
  @override
  Future<Map<String, String>?> encryptMediaKey(String recipientId, Uint8List key) async {
    return {'fake_offer': '123'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallRepository implements CallRepository {
  CallEntity? callToReturn;
  bool shouldThrow = false;

  @override
  Future<CallEntity> createCall({
    required String conversationId,
    required String callerId,
    required String receiverId,
    required CallType type,
    Map<String, dynamic>? offer,
  }) async {
    if (shouldThrow) throw Exception('Signaling server unreachable');
    return callToReturn ??
        CallEntity(
          id: 'call-123',
          conversationId: conversationId,
          callerId: callerId,
          receiverId: receiverId,
          type: type,
          status: CallStatus.ringing,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<CallEntity> acceptCall({required String callId, required String userId}) async {
    return callToReturn ??
        CallEntity(
          id: callId,
          conversationId: 'conv-123',
          callerId: 'user-1',
          receiverId: userId,
          status: CallStatus.active,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<void> declineCall(String callId, String userId) async {}

  @override
  Future<CallEntity> endCall(String callId) async {
    return callToReturn ??
        CallEntity(
          id: callId,
          conversationId: 'conv-123',
          callerId: 'user-1',
          receiverId: 'user-2',
          status: CallStatus.ended,
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<CallEntity?> getCall(String callId) async => callToReturn;

  @override
  Future<List<CallEntity>> getActiveCalls(String userId) async => [];

  @override
  Stream<CallEntity> watchCall(String callId) => const Stream.empty();
}

class _FakeCallService extends CallService {
  CallEntity? fakeIncomingCall;
  CallEntity? fakeCurrentCall;
  String? fakeCurrentCallId;
  bool fakeIsMuted = false;
  bool fakeIsVideoOn = true;
  bool fakeIsSpeakerphoneOn = false;

  @override
  CallEntity? get incomingCall => fakeIncomingCall;

  @override
  CallEntity? get currentCall => fakeCurrentCall;

  @override
  String? get currentCallId => fakeCurrentCallId;

  @override
  bool get isMuted => fakeIsMuted;

  @override
  bool get isVideoOn => fakeIsVideoOn;

  @override
  bool get isSpeakerphoneOn => fakeIsSpeakerphoneOn;

  @override
  Future<void> initLocalStream(bool isVideo) async {}

  @override
  Future<void> startSignaling(CallEntity call, [dynamic key]) async {}

  @override
  Future<void> startRingtone() async {}

  void triggerUpdate() {
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoIP Call Workflow & State Transition Tests', () {
    late _FakeCallRepository mockRepository;
    late _FakeCallService mockService;
    late _FakePQAuraService mockPQAura;
    late CallProvider callProvider;

    setUp(() {
      mockRepository = _FakeCallRepository();
      mockService = _FakeCallService();
      mockPQAura = _FakePQAuraService();
      callProvider = CallProvider(
        callService: mockService,
        callRepository: mockRepository,
        pqAuraService: mockPQAura,
      );
    });

    tearDown(() {
      callProvider.dispose();
    });

    test('Initiates outgoing voice call successfully and transitions state', () async {
      final call = await callProvider.initiateCall(
        conversationId: 'conv-101',
        callerId: 'user-alice',
        receiverId: 'user-bob',
        type: CallType.voice,
      );

      expect(call, isNotNull);
      expect(call?.id, equals('call-123'));
      expect(call?.type, equals(CallType.voice));
      expect(callProvider.state.isLoading, isFalse);
    });

    test('Handles call initiation failure gracefully with error state', () async {
      mockRepository.shouldThrow = true;

      final call = await callProvider.initiateCall(
        conversationId: 'conv-101',
        callerId: 'user-alice',
        receiverId: 'user-bob',
        type: CallType.video,
      );

      expect(call, isNull);
      expect(callProvider.state.error, isNotNull);
    });

    test('Incoming call syncs properly from VoIP CallService', () {
      final incoming = CallEntity(
        id: 'incoming-call-99',
        conversationId: 'conv-202',
        callerId: 'user-charlie',
        receiverId: 'user-alice',
        type: CallType.video,
        status: CallStatus.ringing,
        createdAt: DateTime.now(),
      );

      mockService.fakeIncomingCall = incoming;
      mockService.triggerUpdate();

      expect(callProvider.state.incomingCall, isNotNull);
      expect(callProvider.state.incomingCall?.id, equals('incoming-call-99'));
      expect(callProvider.hasIncomingCall, isTrue);
    });

    test('Toggle audio/video properties updates call controls', () {
      callProvider.toggleMute();
      callProvider.toggleVideo();
      callProvider.toggleSpeakerphone();
      callProvider.toggleMinimize();

      expect(callProvider.state.isMinimized, isTrue);
    });
  });
}

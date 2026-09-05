library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/calling/domain/repositories/call_repository.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';
import 'package:oasis/services/call_service.dart';

import 'call_provider_real_path_test.mocks.dart';

@GenerateMocks([
  CallService,
  CallRepository,
  SupabaseClient,
  GoTrueClient,
  PQAuraService,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCallService mockCallService;
  late MockCallRepository mockCallRepository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockPQAuraService mockPQAura;
  late StreamController<AuthState> authController;

  CallEntity _makeCall({String id = 'call-test', CallType type = CallType.voice}) {
    final now = DateTime.now();
    return CallEntity(
      id: id,
      conversationId: 'conv-test',
      callerId: 'caller-test',
      receiverId: 'receiver-test',
      status: CallStatus.ringing,
      type: type,
      createdAt: now,
    );
  }

  setUp(() {
    mockCallService = MockCallService();
    mockCallRepository = MockCallRepository();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockPQAura = MockPQAuraService();

    authController = StreamController<AuthState>.broadcast();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.onAuthStateChange).thenAnswer((_) => authController.stream);
    when(mockPQAura.encryptMediaKey(any, any)).thenAnswer(
      (_) async => {'pq_header': 'h', 'pq_payload': 'p', 'protocol': 'pq_aura'},
    );
  });

  tearDown(() {
    authController.close();
  });

  group('CallProvider.initiateCall (real class, mocked deps)', () {
    CallProvider _createProvider() {
      return CallProvider(
        callService: mockCallService,
        callRepository: mockCallRepository,
        supabase: mockSupabase,
        pqAuraService: mockPQAura,
      );
    }

    test('returns null when CallService.initLocalStream throws', () async {
      when(mockCallService.initLocalStream(any)).thenThrow(
        Exception('WebRTC initialization failed'),
      );

      final provider = _createProvider();
      addTearDown(() => provider.dispose());

      final result = await provider.initiateCall(
        conversationId: 'conv-1',
        callerId: 'user-a',
        receiverId: 'user-b',
        type: CallType.voice,
      );

      expect(result, isNull);
      expect(provider.state.isLoading, isFalse);
      expect(provider.state.error, contains('WebRTC'));
    });

    test('returns null when CallRepository.createCall throws', () async {
      when(mockCallService.initLocalStream(any)).thenAnswer((_) async {});
      when(mockCallRepository.createCall(
        conversationId: anyNamed('conversationId'),
        callerId: anyNamed('callerId'),
        receiverId: anyNamed('receiverId'),
        type: anyNamed('type'),
        offer: anyNamed('offer'),
      )).thenThrow(Exception('Supabase insert failed'));

      final provider = _createProvider();
      addTearDown(() => provider.dispose());

      final result = await provider.initiateCall(
        conversationId: 'conv-1',
        callerId: 'user-a',
        receiverId: 'user-b',
        type: CallType.voice,
      );

      expect(result, isNull);
      expect(provider.state.isLoading, isFalse);
      expect(provider.state.error, contains('Supabase'));
    });

    test('returns null when startSignaling throws', () async {
      when(mockCallService.initLocalStream(any)).thenAnswer((_) async {});
      final call = _makeCall();
      when(mockCallRepository.createCall(
        conversationId: anyNamed('conversationId'),
        callerId: anyNamed('callerId'),
        receiverId: anyNamed('receiverId'),
        type: anyNamed('type'),
        offer: anyNamed('offer'),
      )).thenAnswer((_) async => call);
      when(mockCallService.startSignaling(any, any)).thenThrow(
        Exception('LiveKit connection failed'),
      );

      final provider = _createProvider();
      addTearDown(() => provider.dispose());

      final result = await provider.initiateCall(
        conversationId: 'conv-1',
        callerId: 'user-a',
        receiverId: 'user-b',
        type: CallType.voice,
      );

      expect(result, isNull);
      expect(provider.state.isLoading, isFalse);
      expect(provider.state.error, contains('LiveKit'));
    });

    test('returns CallEntity on full success path', () async {
      when(mockCallService.initLocalStream(any)).thenAnswer((_) async {});
      final call = _makeCall(id: 'success-call', type: CallType.video);
      when(mockCallRepository.createCall(
        conversationId: anyNamed('conversationId'),
        callerId: anyNamed('callerId'),
        receiverId: anyNamed('receiverId'),
        type: anyNamed('type'),
        offer: anyNamed('offer'),
      )).thenAnswer((_) async => call);
      when(mockCallService.startSignaling(any, any)).thenAnswer((_) async {});
      when(mockCallService.startRingtone()).thenAnswer((_) async {});

      final provider = _createProvider();
      addTearDown(() => provider.dispose());

      final result = await provider.initiateCall(
        conversationId: 'conv-1',
        callerId: 'user-a',
        receiverId: 'user-b',
        type: CallType.video,
      );

      expect(result, isNotNull);
      expect(result!.id, 'success-call');
      expect(result.type, CallType.video);
      expect(provider.state.isLoading, isFalse);
      expect(provider.state.activeCall, isNotNull);
    });

    test('state.isLoading resets to false on success', () async {
      when(mockCallService.initLocalStream(any)).thenAnswer((_) async {});
      final call = _makeCall();
      when(mockCallRepository.createCall(
        conversationId: anyNamed('conversationId'),
        callerId: anyNamed('callerId'),
        receiverId: anyNamed('receiverId'),
        type: anyNamed('type'),
        offer: anyNamed('offer'),
      )).thenAnswer((_) async => call);
      when(mockCallService.startSignaling(any, any)).thenAnswer((_) async {});
      when(mockCallService.startRingtone()).thenAnswer((_) async {});

      final provider = _createProvider();
      addTearDown(() => provider.dispose());

      await provider.initiateCall(
        conversationId: 'conv-1',
        callerId: 'user-a',
        receiverId: 'user-b',
        type: CallType.voice,
      );

      expect(provider.state.isLoading, isFalse);
      expect(provider.state.error, isNull);
    });

    test('state is properly reset on failure', () async {
      when(mockCallService.initLocalStream(any)).thenThrow(
        Exception('mic permission denied'),
      );

      final provider = _createProvider();
      addTearDown(() => provider.dispose());

      await provider.initiateCall(
        conversationId: 'conv-1',
        callerId: 'user-a',
        receiverId: 'user-b',
        type: CallType.video,
      );

      expect(provider.state.isLoading, isFalse);
      expect(provider.state.error, isNotNull);
      expect(provider.state.activeCall, isNull);
    });
  });
}

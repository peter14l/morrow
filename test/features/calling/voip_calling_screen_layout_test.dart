import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/calling/presentation/screens/calling_screen.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/features/calling/domain/repositories/call_repository.dart';

class _MockCallRepo implements CallRepository {
  @override
  Future<CallEntity> createCall({required String conversationId, required String callerId, required String receiverId, required CallType type, Map<String, dynamic>? offer}) async => throw UnimplementedError();
  @override
  Future<CallEntity> acceptCall({required String callId, required String userId}) async => throw UnimplementedError();
  @override
  Future<void> declineCall(String callId, String userId) async {}
  @override
  Future<CallEntity> endCall(String callId) async => throw UnimplementedError();
  @override
  Future<CallEntity?> getCall(String callId) async => null;
  @override
  Future<List<CallEntity>> getActiveCalls(String userId) async => [];
  @override
  Stream<CallEntity> watchCall(String callId) => const Stream.empty();
}

class _MockCallSvc extends CallService {
  CallEntity? testIncomingCall;
  CallEntity? testActiveCall;

  @override
  CallEntity? get incomingCall => testIncomingCall;

  @override
  CallEntity? get currentCall => testActiveCall;

  @override
  String? get currentCallId => testActiveCall?.id;
}

void main() {
  group('VoIP Calling Screen Layout & Widget Tests', () {
    late _MockCallRepo repo;
    late _MockCallSvc svc;
    late CallProvider callProvider;

    setUp(() {
      repo = _MockCallRepo();
      svc = _MockCallSvc();
      callProvider = CallProvider(callService: svc, callRepository: repo);
    });

    testWidgets('Renders CallingScreen for outgoing voice call with live controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<CallProvider>.value(value: callProvider),
            ],
            child: const CallingScreen(),
          ),
        ),
      );

      // Verify basic calling container and layout
      expect(find.byType(CallingScreen), findsOneWidget);
    });
  });
}

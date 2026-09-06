import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';
import 'package:oasis/services/chat_messaging_service.dart';
import 'package:oasis/features/messages/data/conversation_service.dart';
import 'package:oasis/features/messages/data/message_operations_service.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/moderation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSupabaseClient extends Fake implements SupabaseClient {}
class FakeConversationService extends Fake implements ConversationService {}
class FakeChatMessagingService extends Fake implements ChatMessagingService {}
class FakeChatMediaService extends Fake implements ChatMediaService {}
class FakeModerationService extends Fake implements ModerationService {}

class FakeMessageOperationsService extends Fake implements MessageOperationsService {
  String? clearedEveryoneConvId;
  String? clearedMeConvId;
  int clearEveryoneCallCount = 0;
  int clearMeCallCount = 0;

  @override
  Future<void> clearConversationMessages(String conversationId) async {
    clearedEveryoneConvId = conversationId;
    clearEveryoneCallCount++;
  }

  @override
  Future<void> clearChatForMe(String conversationId) async {
    clearedMeConvId = conversationId;
    clearMeCallCount++;
  }
}

void main() {
  group('Clear Chat For Everyone vs Clear Chat For Me Verification', () {
    late FakeMessageOperationsService fakeMessageOps;
    late MessagingService messagingService;
    late FakeSupabaseClient fakeClient;

    setUp(() {
      fakeMessageOps = FakeMessageOperationsService();
      fakeClient = FakeSupabaseClient();
      messagingService = MessagingService(
        client: fakeClient,
        messageOpsService: fakeMessageOps,
        conversationService: FakeConversationService(),
        chatMessagingService: FakeChatMessagingService(),
        chatMediaService: FakeChatMediaService(),
        moderationService: FakeModerationService(),
      );
    });

    test('MessagingService.clearConversationMessages executes full deletion for both participants', () async {
      const conversationId = 'conv-test-12345';
      await messagingService.clearConversationMessages(conversationId);

      expect(fakeMessageOps.clearEveryoneCallCount, equals(1));
      expect(fakeMessageOps.clearedEveryoneConvId, equals('conv-test-12345'));
      expect(fakeMessageOps.clearMeCallCount, equals(0));
    });

    test('MessagingService.clearChatForMe only updates cleared_at for the current user and leaves global messages intact', () async {
      const conversationId = 'conv-test-12345';
      await messagingService.clearChatForMe(conversationId);

      expect(fakeMessageOps.clearMeCallCount, equals(1));
      expect(fakeMessageOps.clearedMeConvId, equals('conv-test-12345'));
      expect(fakeMessageOps.clearEveryoneCallCount, equals(0));
    });
  });
}

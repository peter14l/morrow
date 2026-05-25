import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/presentation/widgets/bubbles/collaboration_request_bubble.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<ProfileProvider>(),
  MockSpec<CircleProvider>(),
  MockSpec<UserSettingsProvider>(),
  MockSpec<SupabaseClient>(),
])
import 'collaborative_posts_test.mocks.dart';
import 'package:oasis/core/network/supabase_client.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockProfileProvider mockProfileProvider;
  late MockCircleProvider mockCircleProvider;
  late MockUserSettingsProvider mockUserSettingsProvider;
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockAuthService = MockAuthService();
    mockProfileProvider = MockProfileProvider();
    mockCircleProvider = MockCircleProvider();
    mockUserSettingsProvider = MockUserSettingsProvider();
    mockSupabaseClient = MockSupabaseClient();

    SupabaseService.setMockClient(mockSupabaseClient);

    when(mockUserSettingsProvider.micaEnabled).thenReturn(false);
    when(mockProfileProvider.following).thenReturn([]);
    when(mockCircleProvider.circles).thenReturn([]);
    when(mockCircleProvider.activeCircle).thenReturn(null);
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<UserSettingsProvider>.value(
          value: mockUserSettingsProvider,
        ),
        ChangeNotifierProvider<ProfileProvider>.value(
          value: mockProfileProvider,
        ),
        ChangeNotifierProvider<CircleProvider>.value(value: mockCircleProvider),
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('PostCard Collaborative Display', () {
    testWidgets('shows only main author when no collaborators', (
      WidgetTester tester,
    ) async {
      final post = Post(
        id: '1',
        userId: 'user1',
        username: 'Alice',
        content: 'Hello',
        timestamp: DateTime.now(),
        collaborators: [],
      );

      await tester.pumpWidget(createTestWidget(PostCard(post: post)));

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows main author and accepted collaborators', (
      WidgetTester tester,
    ) async {
      final post = Post(
        id: '1',
        userId: 'user1',
        username: 'Alice',
        content: 'Collab post',
        timestamp: DateTime.now(),
        collaborators: [
          {'username': 'Bob', 'status': 'accepted'},
          {'username': 'Charlie', 'status': 'pending'},
        ],
      );

      await tester.pumpWidget(createTestWidget(PostCard(post: post)));

      // Alice and Bob are accepted, Charlie is pending
      expect(find.text('Alice and Bob'), findsOneWidget);
      expect(find.textContaining('Charlie'), findsNothing);
    });

    testWidgets('shows "and X others" for multiple collaborators', (
      WidgetTester tester,
    ) async {
      final post = Post(
        id: '1',
        userId: 'user1',
        username: 'Alice',
        content: 'Group collab',
        timestamp: DateTime.now(),
        collaborators: [
          {'username': 'Bob', 'status': 'accepted'},
          {'username': 'Charlie', 'status': 'accepted'},
          {'username': 'David', 'status': 'accepted'},
        ],
      );

      await tester.pumpWidget(createTestWidget(PostCard(post: post)));

      // Alice + 3 accepted = "Alice and 3 others"
      expect(find.text('Alice and 3 others'), findsOneWidget);
    });
  });

  group('CollaborationRequestBubble', () {
    testWidgets('shows Accept/Decline buttons for received invitations', (
      WidgetTester tester,
    ) async {
      final message = Message(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'user1',
        senderName: 'Alice',
        content: 'Invited you to collaborate',
        timestamp: DateTime.now(),
        messageType: MessageType.collaborationRequest,
        postId: 'p1',
        shareData: {'status': 'pending'},
      );

      await tester.pumpWidget(
        createTestWidget(
          CollaborationRequestBubble(message: message, isMe: false),
        ),
      );

      expect(find.text('Alice invited you to collaborate'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('shows status for sent invitations', (WidgetTester tester) async {
      final message = Message(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'me',
        senderName: 'Me',
        content: 'Invited you to collaborate',
        timestamp: DateTime.now(),
        messageType: MessageType.collaborationRequest,
        postId: 'p1',
        shareData: {'status': 'pending'},
      );

      await tester.pumpWidget(
        createTestWidget(
          CollaborationRequestBubble(message: message, isMe: true),
        ),
      );

      expect(find.text('Waiting for response...'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });
  });
}

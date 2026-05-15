import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oasis/features/settings/presentation/screens/privacy_heartbeat_screen.dart';
import 'package:oasis/services/privacy_audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<PrivacyAuditService>(),
])
import 'privacy_heartbeat_test.mocks.dart';

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockPrivacyAuditService mockAuditService;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockAuditService = MockPrivacyAuditService();

    when(mockClient.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.id).thenReturn('test-user-id');

    // Default mock response for fetchLogs
    when(
      mockAuditService.fetchLogs('test-user-id'),
    ).thenAnswer((_) async => []);
  });

  testWidgets('PrivacyHeartbeatScreen renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyHeartbeatScreen(
          client: mockClient,
          auditService: mockAuditService,
        ),
      ),
    );

    expect(find.text('Privacy Heartbeat'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('PrivacyHeartbeatScreen displays logs', (
    WidgetTester tester,
  ) async {
    final logs = [
      {
        'action': 'READ',
        'resource_type': 'Journal',
        'timestamp': DateTime.now().toIso8601String(),
      },
    ];

    when(
      mockAuditService.fetchLogs('test-user-id'),
    ).thenAnswer((_) async => logs);

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyHeartbeatScreen(
          client: mockClient,
          auditService: mockAuditService,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('READ on Journal'), findsOneWidget);
  });
}

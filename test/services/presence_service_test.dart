import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/presence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mock SupabaseClient and RealtimeChannel
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

class MockGotrueSubscription extends Mock
    implements StreamSubscription<AuthState> {}

class MockRealtimeChannelFilter extends Mock implements RealtimeChannelFilter {}

void main() {
  group('PresenceService', () {
    late PresenceService presenceService;
    late MockSupabaseClient mockSupabaseClient;
    late MockRealtimeChannel mockRealtimeChannel;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockRealtimeChannel = MockRealtimeChannel();

      // Mock the client getter in SupabaseService
      // This is a bit tricky since SupabaseService is not easily mockable if it's a singleton.
      // For now, we'll assume a way to inject or mock the client.
      // A more robust solution would be to pass SupabaseClient as a dependency to PresenceService.
      // For this test, we'll directly mock the behavior of `_supabase.channel`.
      when(mockSupabaseClient.channel(any)).thenReturn(mockRealtimeChannel);

      presenceService = PresenceService();
      // Directly inject the mock client for testing purposes if possible,
      // or ensure the SupabaseService singleton can be configured with a mock.
      // For now, we'll rely on the `when` call above for `_supabase.channel`.
    });

    test('updateUserPresence updates status to online when resumed', () async {
      const userId = 'test_user_id';

      // 1. Simulate app going to background (offline)
      // This will cause the channel to be created and subscribed if not already.
      // The track call will be queued.
      await presenceService.updateUserPresence(userId, 'offline');

      // Verify channel creation and subscribe is called
      verify(mockSupabaseClient.channel('user_presence:$userId')).called(1);
      verify(mockRealtimeChannel.subscribe()).called(1);

      // Verify track is called with offline status
      verify(
        mockRealtimeChannel.track({
          'status': 'offline',
          'last_seen': anyNamed('last_seen'),
        }),
      ).called(1);

      // Reset mocks to clear previous interactions
      clearInteractions(mockSupabaseClient);
      clearInteractions(mockRealtimeChannel);

      // 2. Simulate app coming to foreground (online)
      // This should use the existing channel and track the online status.
      await presenceService.updateUserPresence(userId, 'online');

      // Verify no new channel is created (it should use the existing one)
      verifyNever(mockSupabaseClient.channel(any));
      verifyNever(mockRealtimeChannel.subscribe());

      // Verify track is called with online status
      verify(
        mockRealtimeChannel.track({
          'status': 'online',
          'last_seen': anyNamed('last_seen'),
        }),
      ).called(1);
    });
  });
}

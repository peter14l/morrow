import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:google_fonts/google_fonts.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {
  @override
  GoTrueClient get auth => super.noSuchMethod(
    Invocation.getter(#auth),
    returnValue: MockGoTrueClient(),
    returnValueForMissingStub: MockGoTrueClient(),
  );
}

class MockGoTrueClient extends Mock implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Disable Google Fonts network fetching in tests
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Supabase with mock
  final mockClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();

  when(mockClient.auth).thenReturn(mockAuth);

  SupabaseService.setMockClient(mockClient);
}

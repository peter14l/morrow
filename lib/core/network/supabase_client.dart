import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

import 'package:image_picker/image_picker.dart' show XFile;

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static bool isInitialized = false;

  SupabaseClient? _mockClient;
  SupabaseClient? _clientInstance;

  factory SupabaseService() {
    if (!isInitialized) {
      throw Exception(
        'SupabaseService not initialized. Call initialize() first.',
      );
    }
    return _instance;
  }

  // Getter for the Supabase client
  SupabaseClient get client {
    final client = _mockClient ?? _clientInstance;
    if (client == null) {
      throw Exception('Supabase client not initialized.');
    }
    return client;
  }

  @visibleForTesting
  static void setMockClient(SupabaseClient mockClient) {
    _instance._mockClient = mockClient;
    isInitialized = true;
  }

  SupabaseService._internal();

  // Initialize Supabase
  static Future<void> initialize() async {
    if (isInitialized) return;

    final url = SupabaseConfig.supabaseUrl;
    final anonKey = SupabaseConfig.supabaseAnonKey;

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('Supabase configuration is missing (URL or Anon Key is empty)');
      throw Exception('Supabase configuration is missing. Check your .env or dart-define values.');
    }

    try {
      if (kDebugMode) {
        debugPrint('Connecting to Supabase...');
      }
      
      // We removed the hard 15s timeout to prevent crashes on cold starts.
      // Supabase initialization primarily handles local session restoration.
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
          debug: SupabaseConfig.debug,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
          realtimeClientOptions: const RealtimeClientOptions(
            eventsPerSecond: 10,
            logLevel: RealtimeLogLevel.error,
            timeout: Duration(seconds: 30), // Increased from default 10s
          ),
        );
      } on FormatException catch (fe) {
        debugPrint('CRITICAL: Supabase.initialize threw FormatException: $fe');
        debugPrint('This usually means the persisted session data is corrupted.');
        rethrow;
      } on TimeoutException catch (te) {
        debugPrint('Supabase initialization timed out: $te');
        throw Exception('Connection timed out. Please check your internet and try again.');
      }

      _instance._clientInstance = Supabase.instance.client;
      isInitialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e, st) {
      debugPrint('Failed to initialize Supabase: $e');
      debugPrint('Stack trace: $st');
      
      if (e.toString().contains('Failed host lookup')) {
        throw Exception('No internet connection. Oasis requires a connection for the first launch.');
      }
      
      throw Exception('Failed to connect to Oasis servers: $e');
    }
  }

  /// Wait for the session to be restored from storage.
  /// Useful in background isolates.
  Future<bool> waitForSession({int timeoutMs = 2000}) async {
    if (!isInitialized) return false;
    
    int elapsed = 0;
    while (client.auth.currentUser == null && elapsed < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
    }
    
    return client.auth.currentUser != null;
  }

  // Auth methods
  GoTrueClient get auth {
    _checkInitialized();
    return client.auth;
  }

  // Storage methods
  SupabaseStorageClient get storage {
    _checkInitialized();
    return client.storage;
  }

  // Database tables
  SupabaseClient get db {
    _checkInitialized();
    return client;
  }

  // Check if user is authenticated
  bool get isAuthenticated {
    _checkInitialized();
    return client.auth.currentUser != null;
  }

  // Get current user
  User? get currentUser {
    _checkInitialized();
    return client.auth.currentUser;
  }

  // Get current user ID
  String? get currentUserId => currentUser?.id;

  // Get current user's email
  String? get currentUserEmail => currentUser?.email;

  // Auth state changes
  Stream<AuthState> get onAuthStateChange {
    _checkInitialized();
    return client.auth.onAuthStateChange;
  }

  // Sign out
  Future<void> signOut() async {
    _checkInitialized();
    try {
      await client.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get public URL for storage file with CDN and transformation support
  String getPublicUrl(
    String bucket,
    String path, {
    int? width,
    int? height,
    int? quality,
    bool useCdn = true,
  }) {
    _checkInitialized();

    if (!useCdn) {
      return client.storage.from(bucket).getPublicUrl(path);
    }

    // Use Supabase native transformation if possible, or fallback to custom CDN logic
    return client.storage.from(bucket).getPublicUrl(
      path,
      transform: TransformOptions(
        width: width,
        height: height,
        quality: quality,
        format: RequestImageFormat.webp,
      ),
    );
  }

  // Upload file to storage
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required XFile file,
    FileOptions? fileOptions,
  }) async {
    _checkInitialized();
    try {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: fileOptions ?? const FileOptions(),
            );
      } else {
        await client.storage
            .from(bucket)
            .upload(
              path,
              File(file.path),
              fileOptions: fileOptions ?? const FileOptions(),
            );
      }

      return getPublicUrl(bucket, path);
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String bucket, String path) async {
    _checkInitialized();
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  // Clear session data (useful for testing)
  @visibleForTesting
  static void reset() {
    isInitialized = false;
  }

  // Check if the service is initialized
  void _checkInitialized() {
    if (!isInitialized) {
      throw Exception(
        'SupabaseService not initialized. Call SupabaseService.initialize() first.',
      );
    }
  }
}

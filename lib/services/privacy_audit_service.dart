import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacyAuditService {
  static PrivacyAuditService? _instance;

  final SupabaseClient? _client;

  PrivacyAuditService._internal({SupabaseClient? client}) : _client = client;

  factory PrivacyAuditService({SupabaseClient? client}) {
    _instance ??= PrivacyAuditService._internal(client: client);
    return _instance!;
  }

  /// Use for testing purposes to reset the singleton.
  @visibleForTesting
  static void reset(PrivacyAuditService service) {
    _instance = service;
  }

  SupabaseClient get _supabase => _client ?? SupabaseService().client;

  /// Log a data access event (READ, WRITE, DELETE).
  Future<void> logAccess({
    required String userId,
    required String resourceType,
    required String action,
  }) async {
    // No-op fallback: table privacy_audit_logs is not defined in database
    return;
  }

  /// Fetch the latest 50 audit logs for a user.
  Future<List<Map<String, dynamic>>> fetchLogs(String userId) async {
    // No-op fallback: table privacy_audit_logs is not defined in database
    return [];
  }
}

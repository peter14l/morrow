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
    try {
      await _supabase.from('privacy_audit_logs').insert({
        'user_id': userId,
        'resource_type': resourceType,
        'action': action,
      });
      debugPrint('[PrivacyAudit] Logged $action on $resourceType for $userId');
    } catch (e) {
      debugPrint('[PrivacyAudit] Error logging access: $e');
      // We don't rethrow as privacy logging should not block the main operation
    }
  }

  /// Fetch the latest 50 audit logs for a user.
  Future<List<Map<String, dynamic>>> fetchLogs(String userId) async {
    try {
      final response = await _supabase
          .from('privacy_audit_logs')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(50);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[PrivacyAudit] Error fetching logs: $e');
      return [];
    }
  }
}

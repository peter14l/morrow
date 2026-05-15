import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';

class DataExportService {
  final SupabaseClient _supabase;

  DataExportService({SupabaseClient? client})
    : _supabase = client ?? SupabaseService().client;

  Future<void> requestDataExport({required String userId}) async {
    try {
      await _supabase.from(SupabaseConfig.dataExportRequestsTable).insert({
        'user_id': userId,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[DataExportService] Error requesting export: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExportRequests(String userId) async {
    try {
      return await _supabase
          .from(SupabaseConfig.dataExportRequestsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    } catch (e) {
      debugPrint('[DataExportService] Error fetching requests: $e');
      return [];
    }
  }
}

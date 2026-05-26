import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdService {
  static AdService? _instance;
  final SupabaseClient? _client;

  AdService._internal({SupabaseClient? client}) : _client = client;

  factory AdService({SupabaseClient? client}) {
    _instance ??= AdService._internal(client: client);
    return _instance!;
  }

  /// Use for testing purposes to reset the singleton.
  @visibleForTesting
  static void reset(AdService service) {
    _instance = service;
  }

  SupabaseClient get _supabase => _client ?? SupabaseService().client;

  Future<List<Post>> getHouseAds() async {
    try {
      final response = await _supabase
          .from('house_ads')
          .select()
          .eq('is_active', true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        return Post(
          id: json['id'] as String,
          userId: 'oasis_system',
          username: 'Oasis Sponsored',
          userAvatar: 'https://oasis.app/logo.png',
          content: '${json['title'] as String}\n\n${json['body'] as String}',
          imageUrl: json['image_url'] as String?,
          timestamp: DateTime.parse(json['created_at'] as String),
          isAd: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('[AdService] Error fetching house ads: $e');
      return [];
    }
  }
}

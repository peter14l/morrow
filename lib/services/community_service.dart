import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/models/community.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:uuid/uuid.dart';

class CommunityService {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  /// Get all communities
  Future<List<Community>> getCommunities({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.communitiesTable)
          .select()
          .order('members_count', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      return response.map((json) => Community.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching communities: $e');
      rethrow;
    }
  }

  /// Get community by ID
  Future<Community> getCommunity(String communityId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.communitiesTable)
          .select()
          .eq('id', communityId)
          .single();

      return Community.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching community: $e');
      rethrow;
    }
  }

  /// Get user's joined communities
  Future<List<Community>> getUserCommunities({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.communityMembersTable)
          .select('''
            community_id,
            ${SupabaseConfig.communitiesTable}:community_id (*)
          ''')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<Community> communities = [];
      for (final item in response) {
        final communityData = item[SupabaseConfig.communitiesTable];
        if (communityData != null) {
          communities.add(Community.fromJson(communityData));
        }
      }

      return communities;
    } catch (e) {
      debugPrint('Error fetching user communities: $e');
      rethrow;
    }
  }

  /// Create a community
  Future<Community> createCommunity({
    required String creatorId,
    required String name,
    required String description,
    String? rules,
    bool isPrivate = false,
  }) async {
    try {
      final isPro = SubscriptionService().isPro;
      if (!isPro) {
        final createdCommunities = await _supabase
            .from(SupabaseConfig.communitiesTable)
            .select('id')
            .eq('creator_id', creatorId);
        if (createdCommunities.isNotEmpty) {
          throw Exception(
            'Free tier is limited to creating 1 community. Upgrade to Oasis Pro to create more.',
          );
        }
      }
      final communityId = _uuid.v4();

      // Generate slug from name
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-');

      final communityData = {
        'id': communityId,
        'name': name,
        'slug': slug,
        'description': description,
        'rules': rules,
        'is_private': isPrivate,
        'creator_id': creatorId,
      };

      await _supabase
          .from(SupabaseConfig.communitiesTable)
          .insert(communityData);

      // Auto-join creator as admin
      await _supabase.from(SupabaseConfig.communityMembersTable).insert({
        'community_id': communityId,
        'user_id': creatorId,
        'role': 'admin',
      });

      return getCommunity(communityId);
    } catch (e) {
      debugPrint('Error creating community: $e');
      rethrow;
    }
  }

  /// Join a community
  Future<void> joinCommunity({
    required String userId,
    required String communityId,
  }) async {
    try {
      final isPro = SubscriptionService().isPro;
      if (!isPro) {
        final userCommunities = await getUserCommunities(userId: userId);
        if (userCommunities.length >= 5) {
          throw Exception(
            'Free tier is limited to joining 5 communities. Upgrade to Oasis Pro to join more.',
          );
        }
      }
      await _supabase.from(SupabaseConfig.communityMembersTable).insert({
        'community_id': communityId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      debugPrint('Error joining community: $e');
      rethrow;
    }
  }

  /// Leave a community
  Future<void> leaveCommunity({
    required String userId,
    required String communityId,
  }) async {
    try {
      await _supabase
          .from(SupabaseConfig.communityMembersTable)
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error leaving community: $e');
      rethrow;
    }
  }

  /// Check if user is a member of a community
  Future<bool> isMember({
    required String userId,
    required String communityId,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.communityMembersTable)
          .select()
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking membership: $e');
      return false;
    }
  }

  /// Get community members
  Future<List<Map<String, dynamic>>> getCommunityMembers({
    required String communityId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.communityMembersTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('community_id', communityId)
          .order('joined_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching community members: $e');
      rethrow;
    }
  }

  /// Search communities
  Future<List<Community>> searchCommunities({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.communitiesTable)
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(limit);

      if (response.isEmpty) return [];

      return response.map((json) => Community.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error searching communities: $e');
      rethrow;
    }
  }

  /// Update community
  Future<Community> updateCommunity({
    required String communityId,
    required String userId,
    String? name,
    String? description,
    String? rules,
    bool? isPrivate,
  }) async {
    try {
      // Verify user is admin
      final membership = await _supabase
          .from(SupabaseConfig.communityMembersTable)
          .select('role')
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .single();

      if (membership['role'] != 'admin' && membership['role'] != 'moderator') {
        throw Exception('Not authorized to update this community');
      }

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (rules != null) updateData['rules'] = rules;
      if (isPrivate != null) updateData['is_private'] = isPrivate;

      await _supabase
          .from(SupabaseConfig.communitiesTable)
          .update(updateData)
          .eq('id', communityId);

      return getCommunity(communityId);
    } catch (e) {
      debugPrint('Error updating community: $e');
      rethrow;
    }
  }

  /// Delete community
  Future<void> deleteCommunity({
    required String communityId,
    required String userId,
  }) async {
    try {
      // Verify user is creator
      final community = await _supabase
          .from(SupabaseConfig.communitiesTable)
          .select('creator_id')
          .eq('id', communityId)
          .single();

      if (community['creator_id'] != userId) {
        throw Exception('Only the creator can delete this community');
      }

      await _supabase
          .from(SupabaseConfig.communitiesTable)
          .delete()
          .eq('id', communityId);
    } catch (e) {
      debugPrint('Error deleting community: $e');
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class PartnerProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const PartnerProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory PartnerProfile.fromMap(Map<String, dynamic> map) => PartnerProfile(
        id: map['id'] as String,
        username: map['username'] as String,
        displayName: map['full_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );
}

class PartnerInvite {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // pending, accepted, declined
  final DateTime createdAt;
  final PartnerProfile? senderProfile;

  const PartnerInvite({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.senderProfile,
  });

  factory PartnerInvite.fromMap(Map<String, dynamic> map) => PartnerInvite(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        receiverId: map['receiver_id'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        senderProfile: map['sender'] != null
            ? PartnerProfile.fromMap(map['sender'] as Map<String, dynamic>)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class PartnerRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  // -------------------------------------------------------------------------
  // getCurrentPartner
  // -------------------------------------------------------------------------
  /// Returns the OTHER user's profile from an active couple_bubbles row,
  /// or null if the current user has no active partner.
  Future<PartnerProfile?> getCurrentPartner() async {
    try {
      final uid = _currentUserId;
      if (uid == null) return null;

      // Fetch the active bubble where user is user1 or user2.
      final rows = await _client
          .from('couple_bubbles')
          .select('user1_id, user2_id')
          .eq('status', 'active')
          .or('user1_id.eq.$uid,user2_id.eq.$uid')
          .limit(1);

      if (rows.isEmpty) return null;

      final row = rows.first as Map<String, dynamic>;
      final partnerId =
          row['user1_id'] == uid ? row['user2_id'] : row['user1_id'];

      final profileRows = await _client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', partnerId)
          .limit(1);

      if (profileRows.isEmpty) return null;
      return PartnerProfile.fromMap(profileRows.first);
    } catch (e, st) {
      debugPrint('[PartnerRepository.getCurrentPartner] error: $e\n$st');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // searchUsers
  // -------------------------------------------------------------------------
  /// Searches profiles by username (case-insensitive), limit 10, excludes self.
  Future<List<PartnerProfile>> searchUsers(String query) async {
    try {
      final uid = _currentUserId;
      if (uid == null) return [];

      final rows = await _client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .ilike('username', '%$query%')
          .neq('id', uid)
          .limit(10);

      return (rows as List)
          .map((r) => PartnerProfile.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[PartnerRepository.searchUsers] error: $e\n$st');
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // sendInvite
  // -------------------------------------------------------------------------
  /// Inserts a pending partner_invite. Returns false if a pending invite
  /// already exists (either direction) or an active bubble exists.
  Future<bool> sendInvite(String receiverId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) return false;

      // Guard: active bubble already exists?
      final bubbles = await _client
          .from('couple_bubbles')
          .select('id')
          .eq('status', 'active')
          .or('user1_id.eq.$uid,user2_id.eq.$uid')
          .limit(1);

      if ((bubbles as List).isNotEmpty) return false;

      // Guard: pending invite already exists (either direction)?
      final existingInvites = await _client
          .from('partner_invites')
          .select('id')
          .eq('status', 'pending')
          .or(
            'and(sender_id.eq.$uid,receiver_id.eq.$receiverId),'
            'and(sender_id.eq.$receiverId,receiver_id.eq.$uid)',
          )
          .limit(1);

      if ((existingInvites as List).isNotEmpty) return false;

      await _client.from('partner_invites').insert({
        'sender_id': uid,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      return true;
    } catch (e, st) {
      debugPrint('[PartnerRepository.sendInvite] error: $e\n$st');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // getPendingInvites
  // -------------------------------------------------------------------------
  /// Returns pending invites addressed to the current user, with sender profile.
  Future<List<PartnerInvite>> getPendingInvites() async {
    try {
      final uid = _currentUserId;
      if (uid == null) return [];

      final rows = await _client
          .from('partner_invites')
          .select('id, sender_id, receiver_id, status, created_at, sender:profiles!sender_id(id, username, full_name, avatar_url)')
          .eq('receiver_id', uid)
          .eq('status', 'pending');

      return (rows as List)
          .map((r) => PartnerInvite.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[PartnerRepository.getPendingInvites] error: $e\n$st');
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // acceptInvite
  // -------------------------------------------------------------------------
  /// Marks invite as accepted and creates the couple_bubbles row.
  Future<bool> acceptInvite(String inviteId, String senderId) async {
    try {
      final uid = _currentUserId;
      if (uid == null) return false;

      // Update invite status.
      await _client
          .from('partner_invites')
          .update({'status': 'accepted'})
          .eq('id', inviteId);

      // Create the couple bubble.
      await _client.from('couple_bubbles').insert({
        'user1_id': senderId,
        'user2_id': uid,
        'status': 'active',
      });

      return true;
    } catch (e, st) {
      debugPrint('[PartnerRepository.acceptInvite] error: $e\n$st');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // declineInvite
  // -------------------------------------------------------------------------
  /// Marks invite as declined.
  Future<bool> declineInvite(String inviteId) async {
    try {
      await _client
          .from('partner_invites')
          .update({'status': 'declined'})
          .eq('id', inviteId);
      return true;
    } catch (e, st) {
      debugPrint('[PartnerRepository.declineInvite] error: $e\n$st');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // dissolvePartnership
  // -------------------------------------------------------------------------
  /// Sets the active couple_bubbles row to dissolved.
  Future<bool> dissolvePartnership() async {
    try {
      final uid = _currentUserId;
      if (uid == null) return false;

      await _client
          .from('couple_bubbles')
          .update({'status': 'dissolved'})
          .eq('status', 'active')
          .or('user1_id.eq.$uid,user2_id.eq.$uid');

      return true;
    } catch (e, st) {
      debugPrint('[PartnerRepository.dissolvePartnership] error: $e\n$st');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // getSentPendingInvite
  // -------------------------------------------------------------------------
  /// Returns the receiverId of a pending invite sent by the current user,
  /// or null if none exists.
  Future<String?> getSentPendingInvite() async {
    try {
      final uid = _currentUserId;
      if (uid == null) return null;

      final rows = await _client
          .from('partner_invites')
          .select('receiver_id')
          .eq('sender_id', uid)
          .eq('status', 'pending')
          .limit(1);

      if ((rows as List).isEmpty) return null;
      return rows.first['receiver_id'];
    } catch (e, st) {
      debugPrint('[PartnerRepository.getSentPendingInvite] error: $e\n$st');
      return null;
    }
  }
}

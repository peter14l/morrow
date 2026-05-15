import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/services/privacy_audit_service.dart';

class CanvasService {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();
  final _encryption = EncryptionService();
  final _privacyAudit = PrivacyAuditService();

  // Cache for presence channels to ensure we track on subscribed channels
  final Map<String, RealtimeChannel> _presenceChannels = {};

  CanvasService({SupabaseClient? client})
    : _supabase = client ?? SupabaseService().client;

  // ─── Canvases ────────────────────────────────────────────────────────────────

  /// Fetch all canvases the user is a member of.
  Future<List<OasisCanvas>> fetchUserCanvases(String userId) async {
    try {
      final response = await _supabase
          .from('canvases')
          .select('*, canvas_members!inner(user_id)')
          .eq('canvas_members.user_id', userId)
          .order('updated_at', ascending: false);

      // Privacy Audit: Log READ
      await _privacyAudit.logAccess(
        userId: userId,
        resourceType: 'canvas',
        action: 'READ',
      );

      return (response as List).map((row) {
        final canvasMap = Map<String, dynamic>.from(row);
        final memberRows =
            (canvasMap['canvas_members'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        canvasMap['member_ids'] = memberRows
            .map((m) => m['user_id'] as String)
            .toList();
        return OasisCanvas.fromJson(canvasMap);
      }).toList();
    } catch (e) {
      debugPrint('CanvasService.fetchUserCanvases error: $e');
      rethrow;
    }
  }

  /// Create a new canvas with optional initial members.
  Future<OasisCanvas> createCanvas({
    required String createdBy,
    required String title,
    required String coverColor,
    List<String> memberIds = const [],
  }) async {
    try {
      // 1. Create the canvas
      final canvasData = await _supabase
          .from('canvases')
          .insert({
            'title': title,
            'created_by': createdBy,
            'cover_color': coverColor,
          })
          .select()
          .single();

      final canvas = OasisCanvas.fromJson(canvasData);

      // 2. Add creator as owner
      final List<Map<String, dynamic>> membersToInsert = [
        {'canvas_id': canvas.id, 'user_id': createdBy, 'role': 'owner'},
      ];

      // 3. Add other members
      for (final id in memberIds) {
        if (id != createdBy) {
          membersToInsert.add({
            'canvas_id': canvas.id,
            'user_id': id,
            'role': 'member',
          });
        }
      }

      await _supabase.from('canvas_members').insert(membersToInsert);

      // Privacy Audit: Log WRITE
      await _privacyAudit.logAccess(
        userId: createdBy,
        resourceType: 'canvas',
        action: 'WRITE',
      );

      return canvas.copyWith(
        memberIds: membersToInsert.map((m) => m['user_id'] as String).toList(),
      );
    } catch (e) {
      debugPrint('CanvasService.createCanvas error: $e');
      rethrow;
    }
  }

  /// Delete a canvas (only if owner).
  Future<void> deleteCanvas(String canvasId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // The DB RLS policy will handle security, but we can do a quick check here if needed.
      // We'll let the DB enforce deletion rights.
      await _supabase.from('canvases').delete().eq('id', canvasId);

      // Privacy Audit: Log DELETE
      await _privacyAudit.logAccess(
        userId: userId,
        resourceType: 'canvas',
        action: 'DELETE',
      );

      // If no error was thrown, it was either successful or nothing matched.
    } catch (e) {
      debugPrint('CanvasService.deleteCanvas error: $e');
      rethrow;
    }
  }

  /// Leave a canvas (remove membership).
  Future<void> leaveCanvas(String canvasId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await _supabase
          .from('canvas_members')
          .delete()
          .eq('canvas_id', canvasId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('CanvasService.leaveCanvas error: $e');
      rethrow;
    }
  }

  /// Fetch a single canvas by ID
  Future<OasisCanvas> getCanvas(String canvasId) async {
    try {
      final response = await _supabase
          .from('canvases')
          .select('*, canvas_members(user_id)')
          .eq('id', canvasId)
          .single();

      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Privacy Audit: Log READ
        await _privacyAudit.logAccess(
          userId: userId,
          resourceType: 'canvas',
          action: 'READ',
        );
      }

      final canvasMap = Map<String, dynamic>.from(response);
      final memberRows =
          (canvasMap['canvas_members'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      canvasMap['member_ids'] = memberRows
          .map((m) => m['user_id'] as String)
          .toList();

      return OasisCanvas.fromJson(canvasMap);
    } catch (e) {
      debugPrint('CanvasService.getCanvas error: $e');
      rethrow;
    }
  }

  // ─── Items ───────────────────────────────────────────────────────────────────

  /// Fetch all items for a specific canvas.
  Future<List<CanvasItemEntity>> fetchCanvasItems(String canvasId) async {
    try {
      final response = await _supabase
          .from('canvas_items')
          .select('*')
          .eq('canvas_id', canvasId)
          .order('created_at', ascending: true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Privacy Audit: Log READ
        await _privacyAudit.logAccess(
          userId: userId,
          resourceType: 'canvas_item',
          action: 'READ',
        );
      }

      final items = (response as List)
          .map((json) => CanvasItemEntity.fromJson(json))
          .toList();

      return Future.wait(items.map(_decryptItem));
    } catch (e) {
      debugPrint('CanvasService.fetchCanvasItems error: $e');
      rethrow;
    }
  }

  /// Add a new item to a canvas.
  Future<CanvasItemEntity> addItem({
    required String canvasId,
    required String authorId,
    required CanvasItemType type,
    required String content,
    required double xPos,
    required double yPos,
    double rotation = 0.0,
    double scale = 1.0,
    String color = '#252930',
    DateTime? unlockAt,
  }) async {
    try {
      // E2EE Encryption
      if (!_encryption.isInitialized) await _encryption.init();

      // Get all member public keys for this canvas
      final membersResponse = await _supabase
          .from('canvas_members')
          .select('profiles(public_key)')
          .eq('canvas_id', canvasId);

      final publicKeys = (membersResponse as List)
          .map(
            (m) =>
                (m['profiles'] as Map<String, dynamic>?)?['public_key']
                    as String?,
          )
          .whereType<String>()
          .toList();

      if (publicKeys.isEmpty) {
        throw Exception(
          'No member public keys found. At least one member must have E2EE enabled.',
        );
      }

      final encrypted = await _encryption.encryptMessage(content, publicKeys);

      final Map<String, dynamic> insertData = {
        'canvas_id': canvasId,
        'author_id': authorId,
        'type': type.name,
        'content': encrypted.encryptedContent,
        'encrypted_keys': encrypted.encryptedKeys,
        'iv': encrypted.iv,
        'x_pos': xPos,
        'y_pos': yPos,
        'rotation': rotation,
        'scale': scale,
        'color': color,
      };

      if (unlockAt != null) {
        insertData['unlock_at'] = unlockAt.toIso8601String();
      }

      final response = await _supabase
          .from('canvas_items')
          .insert(insertData)
          .select()
          .single();

      // Privacy Audit: Log WRITE
      await _privacyAudit.logAccess(
        userId: authorId,
        resourceType: 'canvas_item',
        action: 'WRITE',
      );

      final item = CanvasItemEntity.fromJson(response);
      return _decryptItem(item);
    } catch (e) {
      debugPrint('CanvasService.addItem error: $e');
      rethrow;
    }
  }

  /// Delete an item from the canvas.
  Future<void> deleteItem(String itemId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('canvas_items').delete().eq('id', itemId);

      if (userId != null) {
        // Privacy Audit: Log DELETE
        await _privacyAudit.logAccess(
          userId: userId,
          resourceType: 'canvas_item',
          action: 'DELETE',
        );
      }
    } catch (e) {
      debugPrint('CanvasService.deleteItem error: $e');
      rethrow;
    }
  }

  /// Update item position/rotation/scale.
  Future<void> updateItemTransform({
    required String itemId,
    required double xPos,
    required double yPos,
    double? rotation,
    double? scale,
    String? lastModifiedBy,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'x_pos': xPos,
        'y_pos': yPos,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (rotation != null) updates['rotation'] = rotation;
      if (scale != null) updates['scale'] = scale;
      if (lastModifiedBy != null) updates['last_modified_by'] = lastModifiedBy;

      await _supabase.from('canvas_items').update(updates).eq('id', itemId);

      if (lastModifiedBy != null) {
        // Privacy Audit: Log WRITE
        await _privacyAudit.logAccess(
          userId: lastModifiedBy,
          resourceType: 'canvas_item',
          action: 'WRITE',
        );
      }
    } catch (e) {
      debugPrint('CanvasService.updateItemTransform error: $e');
      rethrow;
    }
  }

  Future<CanvasItemEntity> _decryptItem(CanvasItemEntity item) async {
    if (item.encryptedKeys == null || item.iv == null) return item;

    try {
      if (!_encryption.isInitialized) await _encryption.init();
      final decrypted = await _encryption.decryptMessage(
        item.content,
        item.encryptedKeys!,
        item.iv!,
      );

      if (decrypted != null) {
        return item.copyWith(content: decrypted);
      }
    } catch (e) {
      debugPrint('Decryption error for canvas item ${item.id}: $e');
    }
    return item;
  }

  /// Toggle a reaction on a canvas item.
  Future<void> toggleReaction({
    required String itemId,
    required String userId,
    required String emoji,
  }) async {
    try {
      // 1. Get current reactions
      final itemData = await _supabase
          .from('canvas_items')
          .select('reactions')
          .eq('id', itemId)
          .single();

      final Map<String, dynamic> reactions = Map<String, dynamic>.from(
        itemData['reactions'] ?? {},
      );
      final List<dynamic> users = reactions[emoji] != null
          ? List.from(reactions[emoji])
          : [];

      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }

      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }

      await _supabase
          .from('canvas_items')
          .update({'reactions': reactions})
          .eq('id', itemId);
    } catch (e) {
      debugPrint('CanvasService.toggleReaction error: $e');
      rethrow;
    }
  }

  /// Lock or unlock an item.
  Future<void> updateItemLock(String itemId, bool isLocked) async {
    try {
      await _supabase
          .from('canvas_items')
          .update({'is_locked': isLocked})
          .eq('id', itemId);
    } catch (e) {
      debugPrint('CanvasService.updateItemLock error: $e');
      rethrow;
    }
  }

  /// Compatibility method for CanvasProvider
  Future<void> moveItem({
    required String itemId,
    required String canvasId,
    required double xPos,
    required double yPos,
    double? rotation,
  }) async {
    return updateItemTransform(
      itemId: itemId,
      xPos: xPos,
      yPos: yPos,
      rotation: rotation,
    );
  }

  /// Upload an image to Supabase Storage for use on the canvas.
  Future<String> uploadCanvasImage(String canvasId, String filePath) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last;
      final fileName = 'canvas_${canvasId}_${_uuid.v4()}.$ext';

      await _supabase.storage.from('post-images').upload(fileName, file);
      return _supabase.storage.from('post-images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('CanvasService.uploadCanvasImage error: $e');
      rethrow;
    }
  }

  /// Upload a voice memo to Supabase Storage for use on the canvas.
  Future<String> uploadCanvasAudio(String canvasId, String filePath) async {
    try {
      final file = File(filePath);
      final ext = filePath.split('.').last;
      final fileName = 'canvas_audio_${canvasId}_${_uuid.v4()}.$ext';

      // Use existing message-attachments bucket instead of non-existent chat-audio
      await _supabase.storage
          .from(SupabaseConfig.messageAttachmentsBucket)
          .upload(fileName, file);
      return _supabase.storage
          .from(SupabaseConfig.messageAttachmentsBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('CanvasService.uploadCanvasAudio error: $e');
      rethrow;
    }
  }

  /// Join an existing canvas.
  Future<void> joinCanvas(String canvasId, String userId) async {
    try {
      await _supabase.from('canvas_members').upsert({
        'canvas_id': canvasId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      debugPrint('CanvasService.joinCanvas error: $e');
      rethrow;
    }
  }

  /// Send a "Pulse" reaction to all members currently on the canvas.
  Future<void> sendPulse(
    String canvasId,
    String userId, {
    double intensity = 1.0,
  }) async {
    try {
      final channel = _supabase.channel('canvas_items:$canvasId');
      await channel.sendBroadcastMessage(
        event: 'pulse',
        payload: {
          'user_id': userId,
          'intensity': intensity,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('CanvasService.sendPulse error: $e');
    }
  }

  Stream<Map<String, dynamic>> subscribeToPresence(String canvasId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    // Reuse or create channel
    final channel =
        _presenceChannels[canvasId] ?? _supabase.channel('presence:$canvasId');
    _presenceChannels[canvasId] = channel;

    channel
        .onPresenceSync((payload) {
          final state = channel.presenceState();
          final Map<String, dynamic> mappedState = {};

          for (final singleState in state) {
            if (singleState.presences.isNotEmpty) {
              mappedState[singleState.key] = singleState.presences
                  .map((p) => p.payload)
                  .toList();
            }
          }

          controller.add(mappedState);
        })
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('[CanvasService] Presence subscription error: $error');
          }
        });

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      _presenceChannels.remove(canvasId);
    };
    return controller.stream;
  }

  void updatePresence({
    required String canvasId,
    required String userId,
    required double x,
    required double y,
    String? activeItemId,
  }) {
    final channel = _presenceChannels[canvasId];

    if (channel == null) {
      debugPrint(
        'CanvasService.updatePresence: No active subscription for canvas $canvasId',
      );
      return;
    }

    channel.track({
      'user_id': userId,
      'x': x,
      'y': y,
      'active_item_id': activeItemId,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  // ─── Realtime ────────────────────────────────────────────────────────────────

  /// Subscribe to live item changes for a canvas.
  Stream<List<CanvasItemEntity>> subscribeToCanvas(String canvasId) {
    final controller = StreamController<List<CanvasItemEntity>>.broadcast();

    final channel = _supabase.channel('canvas_items:$canvasId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'canvas_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'canvas_id',
            value: canvasId,
          ),
          callback: (payload) async {
            // Re-fetch all items to ensure correct order and local state sync
            final items = await fetchCanvasItems(canvasId);
            controller.add(items);
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              '[CanvasService] Canvas items subscription error: $error',
            );
          }
        });

    // Cleanup on cancel
    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}

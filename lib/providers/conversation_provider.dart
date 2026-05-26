import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oasis/providers/presence_provider.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';

class ConversationProvider with ChangeNotifier, SafeChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  PresenceProvider? _presenceProvider;

  List<Conversation> _conversations = [];
  Set<String> _pinnedIds = {};
  bool _isLoading = false;
  String? _currentUserId;

  void updatePresenceProvider(PresenceProvider presenceProvider) {
    if (isDisposed) return;
    _presenceProvider = presenceProvider;
    _setupPresenceSubscriptions();
  }

  // Realtime subscriptions
  RealtimeChannel? _conversationsSubscription;
  final Map<String, RealtimeChannel> _readReceiptSubscriptions = {};
  final Map<String, RealtimeChannel> _typingSubscriptions = {};

  // Polling fallback for when realtime fails (unread count sync)
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);

  // Getters
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  int get totalUnreadCount =>
      _conversations.fold<int>(0, (sum, conv) => sum + conv.unreadCount);

  /// Initialize and load conversations
  Future<void> initialize(String? userId) async {
    if (isDisposed) return;
    if (userId == null) {
      _currentUserId = null;
      _conversations = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    if (_currentUserId == userId && _conversations.isNotEmpty) return;

    _currentUserId = userId;

    // Load pinned IDs first
    final prefs = await SharedPreferences.getInstance();
    if (isDisposed) return;
    final pinnedList =
        prefs.getStringList('pinned_conversations_$_currentUserId') ?? [];
    _pinnedIds = pinnedList.toSet();

    // Load cache first
    await _loadCachedConversations();
    if (isDisposed) return;

    if (_conversations.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    await loadConversations();
    if (isDisposed) return;
    _setupRealtimeSubscriptions();
    _startPollingFallback();
  }

  /// Load conversations from cache
  Future<void> _loadCachedConversations() async {
    if (_currentUserId == null || isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      final String? cachedData = prefs.getString(
        'cached_conversations_$_currentUserId',
      );
      if (cachedData != null && !isDisposed) {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        _conversations = decodedData.map((item) {
          final c = Conversation.fromJson(item);
          return c.copyWith(isPinned: _pinnedIds.contains(c.id));
        }).toList();

        // Sort cached conversations
        _conversations.sort((a, b) {
          final timeA =
              a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB =
              b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached conversations: $e');
    }
  }

  /// Save conversations to cache
  Future<void> _saveConversationsToCache() async {
    if (_currentUserId == null || _conversations.isEmpty || isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      final String encodedData = jsonEncode(
        _conversations.map((c) => c.toJson()).toList(),
      );
      await prefs.setString(
        'cached_conversations_$_currentUserId',
        encodedData,
      );
    } catch (e) {
      debugPrint('Error saving conversations to cache: $e');
    }
  }

  /// Load conversations from service
  Future<void> loadConversations({bool silent = false}) async {
    if (_currentUserId == null || isDisposed) return;

    if (!silent && _conversations.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final conversations = await _messagingService.getConversations(
        userId: _currentUserId!,
      );
      if (isDisposed) return;

      // Ensure they are sorted by last message time
      conversations.sort((a, b) {
        final timeA =
            a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB =
            b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      _conversations = conversations
          .map((c) => c.copyWith(isPinned: _pinnedIds.contains(c.id)))
          .toList();
      await _saveConversationsToCache();
      if (isDisposed) return;
      _setupPresenceSubscriptions();

      // Setup individual subscriptions for each conversation
      for (final conversation in _conversations) {
        _listenToConversationDetails(conversation.id);
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      if (!isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Setup global and conversation-specific subscriptions
  void _setupRealtimeSubscriptions() {
    if (_currentUserId == null || isDisposed) return;

    // Stop existing global subscription
    _conversationsSubscription?.unsubscribe();

    // Subscribe to unread count changes and participant changes
    _conversationsSubscription = _messagingService.subscribeToConversations(
      userId: _currentUserId!,
      onUpdate: (conversationId) {
        if (isDisposed) return;
        // OPTIMIZATION: Trigger a silent, optimistic background refresh instead of a delayed blocking fetch
        _pollConversations();
      },
    );
  }

  /// Listen for read receipts and typing status for a specific conversation
  void _listenToConversationDetails(String conversationId) {
    if (_readReceiptSubscriptions.containsKey(conversationId) || isDisposed) {
      return;
    }

    // Subscribe to read receipts (for "Seen" status)
    final readReceiptChannel = _messagingService.subscribeToReadReceipts(
      conversationId: conversationId,
      onUpdate: (messageId, userId, readAt) {
        if (isDisposed) return;
        _handleReadReceiptUpdate(conversationId, userId);
      },
    );
    _readReceiptSubscriptions[conversationId] = readReceiptChannel;

    // Subscribe to typing status
    final typingChannel = _messagingService.subscribeToTypingStatus(
      conversationId: conversationId,
      onTypingUpdate: (userId, isTyping) {
        if (isDisposed) return;
        if (userId != _currentUserId) {
          _handleTypingUpdate(conversationId, isTyping);
        }
      },
    );
    _typingSubscriptions[conversationId] = typingChannel;
  }

  /// Handle read receipt updates for a specific conversation
  Future<void> _handleReadReceiptUpdate(
    String conversationId,
    String readUserId,
  ) async {
    if (isDisposed) return;
    // Only zero out unread counts if WE read the message. If the other user reads our message,
    // our local unread count (for messages they sent us) shouldn't be cleared!
    if (readUserId == _currentUserId) {
      // 1. Optimistically zero-out locally right away so the badge responds instantly
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1 && _conversations[index].unreadCount > 0) {
        _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
        _conversations = List.from(_conversations);
        notifyListeners();
      }
    }

    // 2. Async refresh in the background to sync actual server state
    refreshConversation(conversationId);
  }

  /// Reload a single conversation's state
  Future<void> refreshConversation(String conversationId) async {
    if (_currentUserId == null || isDisposed) return;

    try {
      final updatedConversation = await _messagingService
          .getConversationDetails(conversationId);
      if (isDisposed) return;

      final c = updatedConversation.copyWith(
        isPinned: _pinnedIds.contains(updatedConversation.id),
      );
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = c;
      } else {
        _conversations.insert(0, c);
      }

      // Always re-sort to move the most recent conversation to the top
      _conversations.sort((a, b) {
        final timeA =
            a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB =
            b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      _conversations = List.from(_conversations);
      _setupPresenceSubscriptions();
      notifyListeners();
      await _saveConversationsToCache();
    } catch (e) {
      debugPrint('Error refreshing conversation: $e');
    }
  }

  void _setupPresenceSubscriptions() {
    if (_presenceProvider == null || _conversations.isEmpty || isDisposed) {
      return;
    }
    for (final conversation in _conversations) {
      _presenceProvider!.subscribeToUserPresence(conversation.otherUserId);
    }
  }

  /// Handle typing status updates
  void _handleTypingUpdate(String conversationId, bool isTyping) {
    if (isDisposed) return;
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        isOtherUserTyping: isTyping,
      );
      notifyListeners();
    }
  }

  /// Manually update a conversation's last message time (useful for sender rearrangement)
  void onMessageSent(String conversationId, String content, String? type) {
    if (isDisposed) return;
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final now = DateTime.now();
      final conversation = _conversations[index];

      _conversations[index] = conversation.copyWith(
        lastMessage: content,
        lastMessageTime: now,
        lastMessageType: type ?? 'text',
        lastMessageSenderId: _currentUserId,
      );

      // Resort immediately to move this conversation to the top
      _conversations.sort((a, b) {
        final timeA =
            a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB =
            b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      _conversations = List.from(_conversations);
      notifyListeners();
      _saveConversationsToCache();
    } else {
      // If conversation not in list (e.g. new message), refresh the whole list
      refreshConversation(conversationId);
    }
  }

  /// Mark a conversation as read locally and on server
  /// Note: This updates the conversation-level unread count. It does NOT
  /// mark individual messages as read on the server (to preserve the Peek feature behavior).
  Future<void> markAsRead(String conversationId) async {
    if (_currentUserId == null || isDisposed) return;

    try {
      // 1. Optimistic update for responsiveness - update immediately in UI
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
        _conversations = List.from(_conversations);
        notifyListeners();
      }

      // 2. Server update - mark conversation as read on server
      // We intentionally do NOT call markMessagesAsRead here to preserve
      // the Peek feature behavior (Peek should NOT mark messages as read)
      await _messagingService.markConversationAsRead(
        conversationId,
        _currentUserId!,
      );
      if (isDisposed) return;

      // 3. Fetch fresh state from server to ensure perfect synchronization
      final updatedConversation = await _messagingService
          .getConversationDetails(conversationId);
      if (isDisposed) return;

      final c = updatedConversation.copyWith(
        isPinned: _pinnedIds.contains(updatedConversation.id),
      );

      final freshIndex = _conversations.indexWhere(
        (conv) => conv.id == conversationId,
      );
      if (freshIndex >= 0 && !isDisposed) {
        // Ensure unread count is 0 (server might have stale data)
        _conversations[freshIndex] = c.copyWith(unreadCount: 0);
        _conversations = List.from(_conversations);
        notifyListeners();
        await _saveConversationsToCache();
      }
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  /// Toggle pin status for a conversation
  Future<void> togglePin(String conversationId) async {
    if (_currentUserId == null || isDisposed) return;

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    final conversation = _conversations[index];
    final newPinnedStatus = !conversation.isPinned;

    // Optimistic update
    _conversations[index] = conversation.copyWith(isPinned: newPinnedStatus);
    _conversations = List.from(_conversations);
    notifyListeners();

    try {
      if (newPinnedStatus) {
        _pinnedIds.add(conversationId);
      } else {
        _pinnedIds.remove(conversationId);
      }
      final prefs = await SharedPreferences.getInstance();
      if (isDisposed) return;
      await prefs.setStringList(
        'pinned_conversations_$_currentUserId',
        _pinnedIds.toList(),
      );

      await _saveConversationsToCache();
    } catch (e) {
      // Revert on error
      if (!isDisposed) {
        if (newPinnedStatus) {
          _pinnedIds.remove(conversationId);
        } else {
          _pinnedIds.add(conversationId);
        }
        _conversations[index] = conversation;
        notifyListeners();
      }
      debugPrint('Error toggling pin: $e');
    }
  }

  /// Clear all data (used during logout)
  Future<void> clear() async {
    if (isDisposed) return;

    // Unsubscribe from presence
    if (_presenceProvider != null) {
      for (final conversation in _conversations) {
        _presenceProvider!.unsubscribeFromUserPresence(
          conversation.otherUserId,
        );
      }
    }

    // Stop subscriptions
    _conversationsSubscription?.unsubscribe();
    _conversationsSubscription = null;
    for (final channel in _readReceiptSubscriptions.values) {
      channel.unsubscribe();
    }
    for (final channel in _typingSubscriptions.values) {
      channel.unsubscribe();
    }

    _readReceiptSubscriptions.clear();
    _typingSubscriptions.clear();

    // Clear cache if we have a user
    if (_currentUserId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!isDisposed) {
          await prefs.remove('cached_conversations_$_currentUserId');
        }
      } catch (e) {
        debugPrint('Error clearing cached conversations: $e');
      }
    }

    if (!isDisposed) {
      _conversations = [];
      _currentUserId = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Stop polling fallback
    _pollingTimer?.cancel();
    _pollingTimer = null;

    _conversationsSubscription?.unsubscribe();
    for (final channel in _readReceiptSubscriptions.values) {
      channel.unsubscribe();
    }
    for (final channel in _typingSubscriptions.values) {
      channel.unsubscribe();
    }
    super.dispose();
  }

  /// Start polling fallback to ensure conversations sync even if realtime fails.
  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _pollConversations();
    });
  }

  /// Polling callback - lightweight sync for unread counts.
  Future<void> _pollConversations() async {
    if (_isLoading) return;

    try {
      // Just refresh conversations without full re-init to sync unread counts
      await loadConversations(silent: true);
    } catch (e) {
      debugPrint('[ConversationProvider] Polling sync error: $e');
    }
  }

  /// Fetches recent unread messages for Peek preview (decrypted, without marking as read).
  /// Uses the MessagingService which delegates to ConversationService.
  Future<List<String>> getRecentUnreadMessages(
    String conversationId,
    int limit,
  ) async {
    return _messagingService.getRecentUnreadMessages(conversationId, limit);
  }
}

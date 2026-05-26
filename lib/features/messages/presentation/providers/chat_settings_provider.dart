import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/models/chat_theme.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';

/// Provider handling chat settings: background, whisper mode, caching, themes.
/// Extracted from _ChatScreenState settings methods in chat_screen.dart.
class ChatSettingsProvider with ChangeNotifier {
  final String conversationId;
  final MessagingService _messagingService;

  ChatSettingsProvider({
    required this.conversationId,
    MessagingService? messagingService,
  }) : _messagingService = messagingService ?? MessagingService();

  // State fields
  String? _backgroundUrl;
  double _bgOpacity = 1.0;
  double _bgBrightness = 0.7;
  int _whisperMode = 0;
  int _lastActiveWhisperMode = 1; // Default to Instant
  int _ephemeralDuration = 86400;
  ChatTheme? _activeTheme;

  String? get backgroundUrl => _backgroundUrl;
  double get bgOpacity => _bgOpacity;
  double get bgBrightness => _bgBrightness;
  int get whisperMode => _whisperMode;
  int get lastActiveWhisperMode => _lastActiveWhisperMode;
  int get ephemeralDuration => _ephemeralDuration;
  ChatTheme? get activeTheme => _activeTheme;

  /// Load persisted chat settings from SharedPreferences and Supabase.
  /// Original: _loadPersistedSettings() in chat_screen.dart
  Future<void> loadPersistedSettings({
    String? currentUserId,
    Function(String?, double, double, Color?, Color?, Color?, Color?)?
    onSettingsLoaded,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bgKey = 'chat_bg_$conversationId';
    _lastActiveWhisperMode =
        prefs.getInt('chat_last_whisper_$conversationId') ?? 1;

    String? bgUrl = prefs.getString(bgKey);

    try {
      if (currentUserId != null) {
        final fetchedBgUrl = await _messagingService.getChatBackground(
          conversationId,
        );

        if (fetchedBgUrl != null || bgUrl != null) {
          bgUrl = fetchedBgUrl;
          // Update local cache
          if (bgUrl != null) {
            await prefs.setString(bgKey, bgUrl);
          } else {
            await prefs.remove(bgKey);
          }
        }

        // Load Whisper Mode from Supabase
        final response = await Supabase.instance.client
            .from('chat_sessions')
            .select('whisper_mode')
            .eq('conversation_id', conversationId)
            .eq('user_id', currentUserId)
            .maybeSingle();

        if (response != null) {
          final modeStr = response['whisper_mode'] as String?;
          if (modeStr == 'INSTANT') {
            _whisperMode = 1;
            _ephemeralDuration = 0;
          } else if (modeStr == '24_HOURS') {
            _whisperMode = 2;
            _ephemeralDuration = 86400;
          } else {
            _whisperMode = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading chat settings from Supabase: $e');
    }

    _backgroundUrl = bgUrl;
    _bgOpacity = prefs.getDouble('chat_bg_opacity_$conversationId') ?? 1.0;
    _bgBrightness =
        prefs.getDouble('chat_bg_brightness_$conversationId') ?? 0.7;
    notifyListeners();

    onSettingsLoaded?.call(
      _backgroundUrl,
      _bgOpacity,
      _bgBrightness,
      null, // bubbleColorSent — computed by encryption provider
      null, // bubbleColorReceived
      null, // textColorSent
      null, // textColorReceived
    );
  }

  /// Save chat settings to SharedPreferences.
  /// Original: _savePersistedSettings() in chat_screen.dart
  Future<void> savePersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bgKey = 'chat_bg_$conversationId';

    if (_backgroundUrl != null) {
      await prefs.setString(bgKey, _backgroundUrl!);
    } else {
      await prefs.remove(bgKey);
    }
  }

  /// Toggle whisper mode (disappearing messages).
  /// Toggles between OFF and Last Active mode.
  void toggleWhisperMode({
    int? currentWhisperMode,
    required Function(int newMode, int newEphemeralDuration) onModeChanged,
    Function(String)? onError,
  }) {
    final oldMode = currentWhisperMode ?? _whisperMode;

    // Toggle logic: OFF <-> Last Active
    final int newMode = oldMode == 0 ? _lastActiveWhisperMode : 0;

    final ephemeralDuration = newMode == 1 ? 0 : 86400;

    _whisperMode = newMode;
    _ephemeralDuration = ephemeralDuration;
    notifyListeners();

    onModeChanged(newMode, ephemeralDuration);

    // Persist to service
    try {
      _messagingService.toggleWhisperMode(conversationId, newMode);
    } catch (e) {
      onError?.call('Failed to toggle whisper mode: $e');
    }
  }

  /// Sets a specific whisper mode.
  Future<void> setWhisperMode(int mode) async {
    if (mode == _whisperMode) return;

    _whisperMode = mode;
    if (mode > 0) {
      _lastActiveWhisperMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('chat_last_whisper_$conversationId', mode);
    }

    _ephemeralDuration = mode == 1 ? 0 : 86400;
    notifyListeners();

    try {
      await _messagingService.toggleWhisperMode(conversationId, mode);
    } catch (e) {
      debugPrint('Failed to set whisper mode: $e');
    }
  }

  /// Handle chat theme change.
  /// Original: _handleThemeChange() in chat_screen.dart
  void handleThemeChange(ChatTheme theme) {
    _activeTheme = theme;
    notifyListeners();
    savePersistedSettings();
  }

  /// Load messages from SharedPreferences cache.
  /// Original: _loadCachedMessages() in chat_screen.dart
  Future<void> loadCachedMessages({
    required DateTime sessionStart,
    required Function(List<Message>) onMessagesLoaded,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String cacheKey = 'chat_messages_$conversationId';
      final String? cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final List<Message> cachedMessages = decoded
            .map((json) => Message.fromJson(json))
            .toList();

        // Filter out expired ephemeral messages from cache
        final now = DateTime.now();
        final filtered = cachedMessages.where((m) {
          if (!m.isEphemeral) return true;
          if (m.ephemeralDuration == 0 && m.readAt != null) return false;
          if (m.expiresAt != null && now.isAfter(m.expiresAt!)) {
            return false;
          }
          return true;
        }).toList();

        if (filtered.isNotEmpty) {
          onMessagesLoaded(filtered);
        }
      }
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
    }
  }

  /// Save current messages to SharedPreferences cache.
  /// Original: _saveMessagesToCache() in chat_screen.dart
  Future<void> saveMessagesToCache(List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String cacheKey = 'chat_messages_$conversationId';

      // Don't cache ephemeral messages that have already been read
      final toCache = messages
          .where((m) => !m.isEphemeral || m.readAt == null)
          .take(50)
          .toList();

      if (toCache.isNotEmpty) {
        final String encoded = jsonEncode(
          toCache.map((m) => m.toJson()).toList(),
        );
        await prefs.setString(cacheKey, encoded);
      }
    } catch (e) {
      debugPrint('Error saving messages to cache: $e');
    }
  }
}

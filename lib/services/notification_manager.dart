import 'package:universal_io/io.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:win_toast/win_toast.dart';
import 'package:oasis/routes/app_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/notification_decryption_service.dart';
import 'package:oasis/services/desktop_call_notifier.dart';
import 'package:oasis/services/session_registry_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/sqlite_init.dart';

/// Represents a message in a notification group history
class NotificationMessage {
  final String senderName;
  final String content;
  final DateTime timestamp;

  NotificationMessage({
    required this.senderName,
    required this.content,
    required this.timestamp,
  });
}

/// Global background notification action handler
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // Ensure core services are ready for background actions
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database factory for desktop background processes
  initSqlite();

  try {
    // 1. Initialize Supabase
    await SupabaseService.initialize();
    // 2. IMPORTANT: Wait for session restoration in background isolate
    // Increased timeout to 3000ms for better reliability on slower devices
    await SupabaseService().waitForSession(timeoutMs: 3000);

    // 3. Initialize NotificationManager in the background isolate
    await NotificationManager.instance.initialize(isBackground: true);
  } catch (e) {
    debugPrint('Background Notification Init Error: $e');
  }

  NotificationManager.instance.handleNotificationResponse(response);
}

/// Cross-platform notification manager
class NotificationManager {
  static NotificationManager? _instance;
  bool _isInitialized = false;
  bool _isPaused = false;
  String? activeConversationId;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final int _notificationId = 1000;

  static const MethodChannel _nativeNotificationChannel = MethodChannel(
    'oasis/notification_tap',
  );

  // Track active message groups (last 5 messages per conversation)
  final Map<String, List<NotificationMessage>> _activeMessageGroups = {};
  // Map conversationId to a fixed notificationId to update the same notification
  final Map<String, int> _conversationToNotificationId = {};
  // Track system assigned IDs to prevent overflow
  int _nextNotificationId = 1000;

  /// Singleton instance
  static NotificationManager get instance {
    _instance ??= NotificationManager._();
    return _instance!;
  }

  NotificationManager._() {
    _nativeNotificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        _handleNotificationTap(call.arguments as String?);
      }
    });
    _checkInitialNotification();
  }

  Future<void> _checkInitialNotification() async {
    try {
      final String? payload = await _nativeNotificationChannel.invokeMethod(
        'getPendingNotificationPayload',
      );
      if (payload != null) {
        debugPrint(
          '[NotificationManager] Detected initial notification tap: $payload',
        );
        _handleNotificationTap(payload);
      }
    } catch (e) {
      debugPrint(
        '[NotificationManager] Error checking initial notification: $e',
      );
    }
  }

  /// Clear a specific message group when conversation is opened/read
  void clearGroup(String conversationId) {
    _activeMessageGroups.remove(conversationId);
    final id = _conversationToNotificationId.remove(conversationId);
    if (id != null) {
      _localNotificationsPlugin.cancel(id);
    }
  }

  /// Set whether notifications should be suppressed (e.g. during Focus Mode)
  void setPaused(bool paused) {
    _isPaused = paused;
    debugPrint(
      'NotificationManager: Notifications ${paused ? 'paused' : 'resumed'}',
    );
  }

  bool get isPaused => _isPaused;

  /// Initialize the notification manager
  Future<bool> initialize({bool isBackground = false}) async {
    // If already initialized, we still want to ensure channels are created
    // especially if called from a background isolate
    try {
      if (_isDesktop) {
        if (Platform.isWindows) {
          // Initialize WinToast for Windows
          await WinToast.instance().initialize(
            appName: 'Oasis',
            productName: 'Oasis',
            companyName: 'Oasis',
          );
        } else if (Platform.isMacOS) {
          await _initLocalNotifications();
        }

        _isInitialized = true;
        debugPrint(
          'NotificationManager: Initialized for desktop (${Platform.operatingSystem})',
        );
        return true;
      } else if (_isMobile) {
        await _initLocalNotifications();
        // FCM initialization usually happens in the main isolate,
        // but the background handler needs local notifications setup.
        if (kDebugMode) {
          debugPrint(
            'NotificationManager: Mobile local notifications initialized',
          );
        }

        // Only init FCM if we are in the main isolate
        if (!isBackground) {
          await _initFCM();
        }

        _isInitialized = true;
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('NotificationManager: Initialization failed: $e');
      return false;
    }
  }

  /// Check if platform supports notifications
  bool get isSupported => _isDesktop || _isMobile;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Show a simple notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? senderAvatar,
    String? messageType,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationManager: Not initialized');
      return;
    }

    if (_isPaused) {
      // In Zen mode, only allow calls to pass through.
      // We check messageType or a 'type' field in the payload.
      bool isCall = messageType == 'call';
      if (!isCall && payload != null) {
        try {
          final data = jsonDecode(payload);
          isCall = data['type'] == 'call';
        } catch (_) {}
      }

      if (!isCall) {
        debugPrint(
          'NotificationManager: Notification suppressed due to Zen Mode: [$title]',
        );
        return;
      }
    }

    String finalBody = body;
    if (messageType == 'image' || messageType == 'Photo') {
      finalBody = '📷 Photo';
    }

    // Hide ciphertext if it hasn't been decrypted yet
    if (finalBody.length > 60 &&
        !finalBody.contains(' ') &&
        !finalBody.contains('🔒')) {
      finalBody = '🔒 Encrypted message';
    }

    // Handle Grouping for DMs
    String? conversationId;
    if (payload != null &&
        (messageType == 'dm' ||
            messageType == 'message' ||
            messageType == 'text')) {
      try {
        final data = jsonDecode(payload);
        conversationId =
            data['conversation_id'] ?? data['sender_id'] ?? data['actor_id'];
      } catch (_) {
        if (payload.length > 20 && !payload.contains('{')) {
          conversationId = payload;
        }
      }
    }

    if (conversationId != null && conversationId == activeConversationId) {
      debugPrint(
        'NotificationManager: Suppressing notification for active conversation: $conversationId',
      );
      return;
    }

    if (conversationId != null) {
      final group = _activeMessageGroups.putIfAbsent(conversationId, () => []);

      // Check if we are updating an existing "Encrypted message" placeholder
      final int existingPlaceholderIndex = group.indexWhere(
        (m) =>
            m.senderName == title &&
            (m.content == '🔒 Encrypted message' ||
                (m.content.length > 60 && !m.content.contains(' '))),
      );

      final bool isDecryptedUpdate =
          existingPlaceholderIndex != -1 &&
          finalBody != '🔒 Encrypted message' &&
          !(finalBody.length > 60 && !finalBody.contains(' '));

      if (isDecryptedUpdate) {
        // Replace the placeholder with the actual content
        group[existingPlaceholderIndex] = NotificationMessage(
          senderName: title,
          content: finalBody,
          timestamp: DateTime.now(),
        );
      } else {
        // Check for exact duplicate to avoid double-posting the same decrypted message
        final bool alreadyExists = group.any(
          (m) => m.content == finalBody && m.senderName == title,
        );

        if (!alreadyExists) {
          group.add(
            NotificationMessage(
              senderName: title,
              content: finalBody,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      // Keep only last 5 messages
      if (group.length > 5) {
        group.removeAt(0);
      }

      // On non-Android platforms, we manually build a multi-line body for the group
      if (!Platform.isAndroid && group.length > 1) {
        finalBody = group
            .map((m) => '${m.senderName}: ${m.content}')
            .join('\n');
      }
    }

    try {
      if (_isDesktop) {
        await _showDesktopNotification(
          title: title,
          body: finalBody,
          senderAvatar: senderAvatar,
        );
      } else if (_isMobile) {
        // Get or assign a notification ID for this conversation
        int idToUse;
        if (conversationId != null) {
          idToUse = _conversationToNotificationId.putIfAbsent(
            conversationId,
            () => _nextNotificationId++,
          );
        } else {
          idToUse = _nextNotificationId++;
        }

        await _showMobileNotification(
          id: idToUse,
          title: title,
          body: finalBody,
          payload: payload,
          senderAvatar: senderAvatar,
          conversationId: conversationId,
        );
      }
    } catch (e) {
      debugPrint('NotificationManager: Failed to show notification: $e');
    }
  }

  /// Show a desktop notification
  Future<void> _showDesktopNotification({
    required String title,
    required String body,
    String? senderAvatar,
  }) async {
    if (Platform.isWindows) {
      try {
        String? iconPath;
        if (senderAvatar != null && senderAvatar.isNotEmpty) {
          try {
            iconPath = await _downloadAndSaveImage(
              senderAvatar,
              'noti_icon_${DateTime.now().millisecondsSinceEpoch}.png',
            );
          } catch (e) {
            debugPrint('Error preparing Windows notification icon: $e');
          }
        }

        // Use win_toast for native Windows notifications
        if (iconPath != null && iconPath.isNotEmpty) {
          await WinToast.instance().showToast(
            type: ToastType.imageAndText02,
            title: title,
            subtitle: body,
            imagePath: iconPath,
          );
        } else {
          await WinToast.instance().showToast(
            type: ToastType.text02,
            title: title,
            subtitle: body,
          );
        }
      } catch (e) {
        debugPrint('NotificationManager (Windows - WinToast): Failed: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        // Use flutter_local_notifications for macOS as it supports images better than osascript
        await _showMobileNotification(
          id: _nextNotificationId++,
          title: title,
          body: body,
          senderAvatar: senderAvatar,
        );
      } catch (e) {
        // Fallback to simple osascript
        await Process.run('osascript', [
          '-e',
          'display notification "$body" with title "$title"',
        ]);
      }
    } else if (!kIsWeb && Platform.isLinux) {
      try {
        await Process.run('notify-send', [title, body]);
      } catch (e) {
        debugPrint('NotificationManager (Linux): [$title] $body');
      }
    }
  }

  /// Show a mobile notification
  Future<void> _showMobileNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? senderAvatar,
    String? conversationId,
  }) async {
    AndroidNotificationDetails? androidDetails;
    DarwinNotificationDetails? darwinDetails;

    // Common Android settings for lock screen visibility and high priority
    const commonAndroidDetails = AndroidNotificationDetails(
      'oasis_channel',
      'Oasis Notifications',
      channelDescription: 'Main notification channel for Oasis',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      fullScreenIntent:
          true, // Crucial for lock screen waking/visibility on many devices
      visibility: NotificationVisibility
          .public, // Ensure content is visible on lock screen
      category: AndroidNotificationCategory.message,
    );

    if (conversationId != null && Platform.isAndroid) {
      final group = _activeMessageGroups[conversationId] ?? [];
      final List<Message> messages = group
          .map(
            (m) => Message(m.content, m.timestamp, Person(name: m.senderName)),
          )
          .toList();

      androidDetails = AndroidNotificationDetails(
        commonAndroidDetails.channelId,
        commonAndroidDetails.channelName,
        channelDescription: commonAndroidDetails.channelDescription,
        importance: commonAndroidDetails.importance,
        priority: commonAndroidDetails.priority,
        showWhen: commonAndroidDetails.showWhen,
        fullScreenIntent: commonAndroidDetails.fullScreenIntent,
        visibility: commonAndroidDetails.visibility,
        category: commonAndroidDetails.category,
        styleInformation: MessagingStyleInformation(
          const Person(name: 'Me'), // Receiver
          conversationTitle: group.length > 1 ? 'Messages from $title' : null,
          messages: messages,
        ),
        actions: [
          const AndroidNotificationAction(
            'reply_action',
            'Reply',
            inputs: [
              AndroidNotificationActionInput(label: 'Type a message...'),
            ],
          ),
          const AndroidNotificationAction('like_action', 'Like'),
        ],
      );
    }

    if (senderAvatar != null &&
        senderAvatar.isNotEmpty &&
        androidDetails == null) {
      try {
        final String largeIconPath = await _downloadAndSaveImage(
          senderAvatar,
          'noti_icon_${DateTime.now().millisecondsSinceEpoch}.png',
        );

        androidDetails = AndroidNotificationDetails(
          commonAndroidDetails.channelId,
          commonAndroidDetails.channelName,
          channelDescription: commonAndroidDetails.channelDescription,
          importance: commonAndroidDetails.importance,
          priority: commonAndroidDetails.priority,
          showWhen: commonAndroidDetails.showWhen,
          fullScreenIntent: commonAndroidDetails.fullScreenIntent,
          visibility: commonAndroidDetails.visibility,
          category: commonAndroidDetails.category,
          largeIcon: FilePathAndroidBitmap(largeIconPath),
          actions: conversationId != null
              ? [
                  const AndroidNotificationAction(
                    'reply_action',
                    'Reply',
                    inputs: [
                      AndroidNotificationActionInput(
                        label: 'Type a message...',
                      ),
                    ],
                  ),
                  const AndroidNotificationAction('like_action', 'Like'),
                ]
              : null,
        );

        darwinDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: [DarwinNotificationAttachment(largeIconPath)],
          threadIdentifier: conversationId,
          categoryIdentifier: conversationId != null ? 'DM_CATEGORY' : null,
        );
      } catch (e) {
        debugPrint('Error downloading notification icon: $e');
      }
    }

    androidDetails ??= AndroidNotificationDetails(
      commonAndroidDetails.channelId,
      commonAndroidDetails.channelName,
      channelDescription: commonAndroidDetails.channelDescription,
      importance: commonAndroidDetails.importance,
      priority: commonAndroidDetails.priority,
      showWhen: commonAndroidDetails.showWhen,
      fullScreenIntent: commonAndroidDetails.fullScreenIntent,
      visibility: commonAndroidDetails.visibility,
      category: commonAndroidDetails.category,
      actions: conversationId != null
          ? [
              const AndroidNotificationAction(
                'reply_action',
                'Reply',
                inputs: [
                  AndroidNotificationActionInput(label: 'Type a message...'),
                ],
              ),
              const AndroidNotificationAction('like_action', 'Like'),
            ]
          : null,
    );

    darwinDetails ??= DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: conversationId,
      categoryIdentifier: conversationId != null ? 'DM_CATEGORY' : null,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: payload,
    );
  }

  /// Master response handler for all local notification actions.
  void handleNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'accept_call' ||
        response.actionId == 'decline_call') {
      _handleCallAction(
        actionId: response.actionId!,
        payload: response.payload,
      );
      return;
    }

    if (response.actionId == 'end_call') {
      debugPrint(
        '[NotificationManager] End call action triggered from notification',
      );
      // Use the global instance to end the call
      CallService.instance.endCall();
      dismissActiveCallNotification();
      return;
    }

    if (response.actionId == 'reply_action') {
      final content = response.input;
      if (content != null && content.isNotEmpty) {
        await _handleReply(payload: response.payload, content: content);

        // Android: Clear the input spinner by updating or canceling the notification
        if (response.id != null) {
          await _localNotificationsPlugin.cancel(response.id!);
        }
      }
      return;
    }

    if (response.actionId == 'like_action') {
      await _handleLike(payload: response.payload);

      // Feedback: Briefly update or cancel to show action complete
      if (response.id != null) {
        // For 'Like', we can just cancel or show a small feedback
        await _localNotificationsPlugin.cancel(response.id!);
      }
      return;
    }

    _handleNotificationTap(response.payload);
  }

  /// Handle DM reply action from notification
  Future<void> _handleReply({
    required String? payload,
    required String content,
  }) async {
    if (payload == null) {
      debugPrint('[NotificationManager] Reply failed: Payload is null');
      return;
    }

    try {
      final data = jsonDecode(payload);
      // Use fallback logic for conversation_id consistent with showNotification
      final conversationId =
          data['conversation_id'] ?? data['sender_id'] ?? data['actor_id'];

      if (conversationId == null) {
        debugPrint(
          '[NotificationManager] Reply failed: conversation_id missing in payload',
        );
        debugPrint('[NotificationManager] Payload keys: ${data.keys.toList()}');
        return;
      }

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('[NotificationManager] Reply failed: No active session');
        return;
      }

      String finalContent = content;
      Map<String, String>? encryptedKeys;
      String? iv;

      // E2EE Support in background:
      try {
        final conversation = await client
            .from('conversations')
            .select('is_encrypted')
            .eq('id', conversationId)
            .maybeSingle();

        if (conversation != null && conversation['is_encrypted'] == true) {
          final encryptionService = EncryptionService();
          if (!encryptionService.isInitialized) await encryptionService.init();

          // Fetch other participants' public keys
          final participants = await client
              .from('conversation_participants')
              .select('profiles(public_key)')
              .eq('conversation_id', conversationId)
              .neq('user_id', userId);

          final List<String> publicKeys = [];
          for (final p in participants) {
            final key = p['profiles']?['public_key'];
            if (key != null) publicKeys.add(key as String);
          }

          if (publicKeys.isNotEmpty) {
            final encrypted = await encryptionService.encryptMessage(
              content,
              publicKeys,
            );
            finalContent = encrypted.encryptedContent;
            encryptedKeys = encrypted.encryptedKeys;
            iv = encrypted.iv;
            debugPrint('[NotificationManager] Reply encrypted for E2EE chat');
          }
        }
      } catch (e) {
        debugPrint('[NotificationManager] E2EE check/encryption failed: $e');
      }

      await client.rpc(
        'send_message_v3',
        params: {
          'p_conversation_id': conversationId,
          'p_content': finalContent,
          'p_message_type': 'text',
          'p_encrypted_keys': encryptedKeys,
          'p_iv': iv,
        },
      );
      debugPrint(
        '[NotificationManager] Reply successfully sent to $conversationId',
      );

      // Update notification to show success
      await _localNotificationsPlugin.show(
        8888, // Use a temporary ID for feedback
        'Message Sent',
        'Your reply to ${data['sender_name'] ?? 'user'} was delivered.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'oasis_silent_channel',
            'Silent Notifications',
            channelDescription: 'Feedback for background actions',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
      // Auto-cancel feedback after 2 seconds
      Future.delayed(
        const Duration(seconds: 2),
        () => _localNotificationsPlugin.cancel(8888),
      );
    } catch (e) {
      debugPrint('[NotificationManager] Error handling notification reply: $e');
    }
  }

  /// Handle DM like action from notification
  Future<void> _handleLike({required String? payload}) async {
    if (payload == null) {
      debugPrint('[NotificationManager] Like failed: Payload is null');
      return;
    }

    try {
      final data = jsonDecode(payload);
      final messageId = data['message_id'] ?? data['id'];

      if (messageId == null) {
        debugPrint(
          '[NotificationManager] Like failed: message_id missing in payload',
        );
        debugPrint('[NotificationManager] Payload keys: ${data.keys.toList()}');
        return;
      }

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('[NotificationManager] Like failed: No active session');
        return;
      }

      final username =
          client.auth.currentUser?.userMetadata?['username'] ??
          client.auth.currentUser?.email?.split('@').first ??
          'User';

      // Use RPC or table insert directly for reactions
      await client.from('message_reactions').upsert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': '❤️',
        'username': username,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'message_id, user_id');
      debugPrint(
        '[NotificationManager] Like reaction successfully added to $messageId',
      );

      // Optional: Feedback notification for "Like"
      await _localNotificationsPlugin.show(
        8889,
        'Liked message',
        'Reaction added to message from ${data['sender_name'] ?? 'user'}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'oasis_silent_channel',
            'Silent Notifications',
            channelDescription: 'Feedback for background actions',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
      Future.delayed(
        const Duration(seconds: 2),
        () => _localNotificationsPlugin.cancel(8889),
      );
    } catch (e) {
      debugPrint('[NotificationManager] Error handling notification like: $e');
    }
  }

  Future<String> _downloadAndSaveImage(String url, String fileName) async {
    final Directory directory = await getTemporaryDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  /// Initialize local notifications for mobile (and macOS)
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    // macOS/iOS: register categories so notifications show action buttons.
    final macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'CALL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain('accept_call', 'Accept'),
            DarwinNotificationAction.plain(
              'decline_call',
              'Decline',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
        DarwinNotificationCategory(
          'ACTIVE_CALL_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'end_call',
              'End Call',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
        DarwinNotificationCategory(
          'DM_CATEGORY',
          actions: [
            DarwinNotificationAction.text(
              'reply_action',
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Type a message...',
            ),
            DarwinNotificationAction.plain('like_action', 'Like'),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create the default channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'oasis_channel',
          'Oasis Notifications',
          description: 'Main notification channel for Oasis',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }
  }

  /// Handle accept / decline actions from a macOS call notification.
  void _handleCallAction({required String actionId, String? payload}) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final callId = data['call_id'] as String?;
      if (callId == null) return;

      if (actionId == 'accept_call') {
        DesktopCallNotifier.acceptFromNotification(
          callId,
          data['sender_id'] as String?,
        );
      } else if (actionId == 'decline_call') {
        DesktopCallNotifier.declineFromNotification(callId);
      }
    } catch (e) {
      debugPrint('[NotificationManager] Call action handler error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Call notification helpers (used by DesktopCallNotifier)
  // ---------------------------------------------------------------------------

  static const int _callNotificationId = 9999;

  /// Show a macOS incoming-call notification with Accept / Decline actions.
  Future<void> showCallNotification({
    required String callId,
    required String callerName,
    String? senderId,
  }) async {
    if (!_isInitialized) return;
    final payload = jsonEncode({
      'type': 'call',
      'call_id': callId,
      'sender_id': senderId ?? '',
    });
    await _localNotificationsPlugin.show(
      _callNotificationId,
      '📞 Incoming Call',
      '$callerName is calling...',
      const NotificationDetails(
        macOS: DarwinNotificationDetails(
          categoryIdentifier: 'CALL_CATEGORY',
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      payload: payload,
    );
  }

  /// Show a persistent "Call in Progress" notification with an "End Call" button.
  Future<void> showActiveCallNotification({
    required String callId,
    required String participantName,
  }) async {
    if (!_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'oasis_active_call_channel',
      'Active Calls',
      channelDescription: 'Notification for calls in progress',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      usesChronometer: true,
      category: AndroidNotificationCategory.call,
      actions: [
        AndroidNotificationAction(
          'end_call',
          'End Call',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: false,
      presentBadge: false,
      categoryIdentifier: 'ACTIVE_CALL_CATEGORY',
    );

    await _localNotificationsPlugin.show(
      _activeCallNotificationId,
      '📞 Call in Progress',
      'With $participantName',
      const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      ),
      payload: jsonEncode({'type': 'active_call', 'call_id': callId}),
    );
  }

  /// Cancel the active call notification.
  Future<void> dismissActiveCallNotification() async {
    await _localNotificationsPlugin.cancel(_activeCallNotificationId);
  }

  static const int _activeCallNotificationId = 9998;

  /// Cancel the persistent incoming-call notification.
  Future<void> dismissCallNotification() async {
    await _localNotificationsPlugin.cancel(_callNotificationId);
  }

  /// Initialize FCM integration
  Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission on mobile platforms only
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }

    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _syncTokenToBackend(token);
      }
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[NotificationManager] FCM Token refreshed');
        await _syncTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('Failed to retrieve or save FCM token: $e');
    }

    // Foreground message handler - works when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('FCM onMessage received: ${message.messageId}');

      if (message.notification != null || message.data.isNotEmpty) {
        final receiverId =
            message.data['receiver_id'] ?? message.data['user_id'];

        // 1. Requirement (a): Only show if logged in.
        // Check if receiverId is one of our registered accounts.
        final accounts = await SessionRegistryService().getAllAccounts();
        if (accounts.isEmpty) {
          debugPrint(
            '[NotificationManager] Suppressing notification: No accounts logged in.',
          );
          return;
        }

        if (receiverId != null &&
            !accounts.any((a) => a.userId == receiverId)) {
          debugPrint(
            '[NotificationManager] Suppressing notification: Recipient $receiverId is not a logged-in account.',
          );
          return;
        }

        final String title =
            message.notification?.title ??
            message.data['title'] ??
            'New Notification';
        String body = message.notification?.body ?? message.data['body'] ?? '';

        // Decrypt body if it's an encrypted message using the correct receiver's keys
        try {
          final decryptedBody = await NotificationDecryptionService()
              .decryptMessage(message.data, targetUserId: receiverId);
          if (decryptedBody != null &&
              decryptedBody.isNotEmpty &&
              !decryptedBody.contains('🔒')) {
            body = decryptedBody;
          } else if (body.length > 100 && !body.contains(' ')) {
            body = '🔒 Encrypted message';
          }
        } catch (e) {
          debugPrint('Foreground decryption failed: $e');
        }

        final messageType =
            message.data['message_type'] ?? message.data['type'];

        // In-app calling overlay handles foreground calls
        if (messageType == 'call') return;

        showNotification(
          title: title,
          body: body,
          payload: jsonEncode(message.data),
          messageType: messageType,
          senderAvatar: message.data['sender_avatar'],
        );
      }
    });

    // Handle when user taps notification to open app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: ${message.messageId}');
      _handleNotificationTap(jsonEncode(message.data));
    });

    // Check if app was opened from terminated state
    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initialMessage: ${initialMessage.messageId}');
      _handleNotificationTap(jsonEncode(initialMessage.data));
    }

    // Windows-specific: when in system tray, we need to ensure we're listening
    debugPrint(
      'FCM initialized - app must run in system tray for background notifications on Windows',
    );
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final receiverId = data['receiver_id'] ?? data['user_id'];
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // Requirement (c): Switch account if notification is for a different account
      if (receiverId != null && receiverId != currentUserId) {
        debugPrint(
          '[NotificationManager] Switching account to $receiverId for notification',
        );
        final context = AppRouter.rootNavigatorKey.currentContext;
        if (context != null) {
          try {
            await AuthService().switchAccount(context, receiverId);
            // Brief delay for session state to propagate
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            debugPrint('[NotificationManager] Failed to switch account: $e');
          }
        }
      }

      final type = data['type'] as String?;
      final conversationId = data['conversation_id'] as String?;

      // Clear the group history when the user taps it to open the chat
      if (conversationId != null) {
        clearGroup(conversationId);
      }

      if (type == 'call') {
        final callId = data['call_id'] as String?;
        final senderId = data['actor_id'] as String?;
        if (callId != null) {
          AppRouter.router.pushNamed(
            'active_call',
            pathParameters: {'callId': callId},
            extra: {'isIncoming': true, 'callerId': senderId},
          );
        }
        return;
      }

      if (type == 'dm' || type == 'message') {
        if (conversationId != null) {
          AppRouter.router.pushNamed(
            'chat_nested',
            pathParameters: {'conversationId': conversationId},
            extra: {
              'otherUserName': data['sender_name'] ?? 'User',
              'otherUserAvatar': data['sender_avatar'] ?? '',
              'otherUserId': data['sender_id'] ?? '',
            },
          );
        }
      } else if (data.containsKey('post_id')) {
        AppRouter.router.pushNamed(
          'post_details',
          pathParameters: {'postId': data['post_id']},
        );
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) return;

    Future.delayed(delay, () {
      showNotification(title: title, body: body, payload: payload);
    });
  }

  Future<void> cancelAll() async {
    await _localNotificationsPlugin.cancelAll();
    _activeMessageGroups.clear();
    _conversationToNotificationId.clear();
  }

  Future<bool> requestPermission() async {
    if (_isDesktop) return true;
    if (_isMobile) {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Request Android 14 full screen intent for incoming call ringing
      if (Platform.isAndroid) {
        try {
          await FlutterCallkitIncoming.requestFullIntentPermission();
        } catch (_) {}
      }

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }
    return false;
  }

  Future<void> _syncTokenToBackend(String token) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint(
        '[NotificationManager] FCM Token synced to backend for $userId',
      );
    } catch (e) {
      debugPrint('[NotificationManager] Error syncing FCM token: $e');
    }
  }
}

/// Notification types for categorization
enum NotificationType {
  message,
  like,
  comment,
  follow,
  mention,
  community,
  reminder,
  system,
}

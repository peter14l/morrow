import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/widgets/messages/unread_badge_widget.dart';
import 'package:oasis/features/messages/presentation/screens/chat_screen.dart';
import 'package:oasis/features/messages/presentation/screens/chat_details_screen.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:oasis/providers/presence_provider.dart';
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/widgets/desktop_header.dart';
import 'package:oasis/widgets/custom_text_field.dart';
import 'package:oasis/themes/theme_provider.dart';

import 'package:oasis/services/auth_service.dart';
import 'package:oasis/routes/app_router.dart';

class DirectMessagesScreen extends StatefulWidget {
  final String? initialConversationId;
  final Map<String, dynamic>? initialConversationData;

  const DirectMessagesScreen({
    super.key,
    this.initialConversationId,
    this.initialConversationData,
  });

  @override
  State<DirectMessagesScreen> createState() => _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends State<DirectMessagesScreen>
    with WidgetsBindingObserver {
  Conversation? _selectedConversation;
  bool _showDetails = false;
  double _bgOpacity = 1.0;
  double _bgBrightness = 0.7;
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  double _lastScrollOffset = 0;
  String _searchQuery = '';
  bool _isEditingFavorites = false;
  // final List<String> _pinnedMockIds = [];

  final Map<String, int> _conversationSizes = {};
  Conversation? _previewConversation;
  Offset _previewPosition = Offset.zero;
  List<String> _previewDecryptedMessages = [];
  bool _isListView = false;
  Map<String, String> _conversationLabels = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversationSizes();
    _loadViewPreferences();
    _startRefreshTimer();
    _scrollController.addListener(_onScroll);

    if (widget.initialConversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _setInitialConversation(),
      );
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Unfocus on pause/inactive to prevent keyboard sync issues on Windows
      FocusManager.instance.primaryFocus?.unfocus();
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_refreshTimer == null || !_refreshTimer!.isActive) {
        _startRefreshTimer();
      }
    }
  }

  @override
  void didUpdateWidget(DirectMessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != oldWidget.initialConversationId &&
        widget.initialConversationId != null) {
      _setInitialConversation();
    }
  }

  void _setInitialConversation() {
    if (!mounted) return;
    // Unfocus before switching
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = Provider.of<ConversationProvider>(context, listen: false);
    final convId = widget.initialConversationId!;

    final realConv = provider.conversations
        .where((c) => c.id == convId)
        .firstOrNull;
    if (realConv != null) {
      setState(() => _selectedConversation = realConv);
      return;
    }

    // Check if we have extra data passed (e.g. from NewMessageScreen)
    if (widget.initialConversationData != null) {
      final data = widget.initialConversationData!;
      setState(() {
        _selectedConversation = Conversation(
          id: convId,
          otherUserId: data['otherUserId'] ?? '',
          otherUserName: data['otherUserName'] ?? 'Unknown',
          otherUserAvatar: data['otherUserAvatar'] ?? '',
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
        );
      });
      return;
    }

    // final mockConv =
    //     _generateMockConversations().where((c) => c.id == convId).firstOrNull;
    // if (mockConv != null) {
    //   setState(() => _selectedConversation = mockConv);
    // }
  }

  Future<void> _loadConversationSizes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('conversation_sizes');
      if (encoded != null) {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _conversationSizes.addAll(
            decoded.map((k, v) => MapEntry(k, v as int)),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading sizes: $e');
    }
  }

  Future<void> _saveConversationSizes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'conversation_sizes',
        jsonEncode(_conversationSizes),
      );
    } catch (e) {
      debugPrint('Error saving sizes: $e');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentOffset = _scrollController.offset;
    if (mounted) {
      _lastScrollOffset = currentOffset;
    }
  }

  void _toggleSize(String id) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      final currentSize = _conversationSizes[id] ?? 0;
      _conversationSizes[id] = (currentSize + 1) % 3;
    });
    _saveConversationSizes();
  }

  void _togglePin(String id) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    // if (id.startsWith('mock_')) {
    //   setState(() {
    //     if (_pinnedMockIds.contains(id)) {
    //       _pinnedMockIds.remove(id);
    //     } else {
    //       _pinnedMockIds.add(id);
    //     }
    //   });
    // } else {
    context.read<ConversationProvider>().togglePin(id);
    // }
  }

  Future<void> _loadViewPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isList = prefs.getBool('dm_view_is_list') ?? false;
      final labelsStr = prefs.getString('conversation_labels') ?? '{}';
      final Map<String, dynamic> decodedLabels = jsonDecode(labelsStr);
      if (!mounted) return;
      setState(() {
        _isListView = isList;
        _conversationLabels = decodedLabels.map((k, v) => MapEntry(k, v as String));
      });
    } catch (e) {
      debugPrint('Error loading view preferences: $e');
    }
  }

  Future<void> _saveViewPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dm_view_is_list', _isListView);
    } catch (e) {
      debugPrint('Error saving view preference: $e');
    }
  }

  Future<void> _saveConversationLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('conversation_labels', jsonEncode(_conversationLabels));
    } catch (e) {
      debugPrint('Error saving labels: $e');
    }
  }

  void _showLabelDialog(Conversation conversation) {
    final customController = TextEditingController(
      text: _conversationLabels[conversation.id] ?? '',
    );
    final standardLabels = ['Family', 'Friends', 'Work', 'School', 'Important'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Label for ${conversation.otherUserName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a label or enter a custom one:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: standardLabels.map((label) {
                final isSelected = _conversationLabels[conversation.id] == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    Navigator.pop(context);
                    _saveLabel(conversation.id, selected ? label : '');
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: customController,
              decoration: const InputDecoration(
                labelText: 'Custom Label',
                hintText: 'e.g., Neighbors, Gym',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveLabel(conversation.id, '');
            },
            child: const Text('Clear Label', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _saveLabel(conversation.id, customController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveLabel(String conversationId, String label) {
    setState(() {
      if (label.isEmpty) {
        _conversationLabels.remove(conversationId);
      } else {
        _conversationLabels[conversationId] = label;
      }
    });
    _saveConversationLabels();
  }


  void _handleLongPressBubble(Conversation conversation, Offset position) {
    _showContextMenu(context, position, conversation);
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    Conversation conversation,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 8,
      items: <PopupMenuEntry>[
        PopupMenuItem(
          onTap: () => _showStealthPreview(conversation, position),
          child: Row(
            children: [
              Icon(
                FluentIcons.eye_24_regular,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('Peek Preview'),
            ],
          ),
        ),
        PopupMenuItem(
          // onTap: () {
          //   if (conversation.id.startsWith('mock_')) {
          //     setState(() {
          //       if (_pinnedMockIds.contains(conversation.id)) {
          //         _pinnedMockIds.remove(conversation.id);
          //       } else {
          //         _pinnedMockIds.add(conversation.id);
          //       }
          //     });
          //     HapticFeedback.mediumImpact();
          //   } else {
          //     context.read<ConversationProvider>().togglePin(conversation.id);
          //   }
          // },
          onTap: () {
            context.read<ConversationProvider>().togglePin(conversation.id);
            HapticFeedback.mediumImpact();
          },
          child: Row(
            children: [
              Icon(
                conversation.isPinned
                    ? FluentIcons.pin_off_24_regular
                    : FluentIcons.pin_24_regular,
                size: 20,
                color: conversation.isPinned
                    ? Colors.redAccent
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(conversation.isPinned ? 'Unfavorite' : 'Add to Favorites'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            _toggleSize(conversation.id);
          },
          child: Row(
            children: [
              Icon(
                FluentIcons.resize_video_24_regular,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('Resize Grid'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            _showLabelDialog(conversation);
          },
          child: Row(
            children: [
              Icon(
                FluentIcons.tag_24_regular,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('Set Label'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () {
            // Future: Implement delete conversation
          },
          child: Row(
            children: [
              Icon(
                FluentIcons.delete_24_regular,
                size: 20,
                color: colorScheme.error,
              ),
              const SizedBox(width: 12),
              Text('Delete Chat', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }

  void _showStealthPreview(Conversation conversation, Offset position) async {
    if (!mounted) return;

    // If no unread messages, don't show peek (per request)
    if (conversation.unreadCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No new messages to peek')));
      return;
    }

    HapticFeedback.heavyImpact();

    // Fetch decrypted messages for the peek preview (without marking as read)
    final decryptedMessages = await Provider.of<ConversationProvider>(
      context,
      listen: false,
    ).getRecentUnreadMessages(conversation.id, conversation.unreadCount);

    if (!mounted) return;

    setState(() {
      _previewConversation = conversation;
      _previewPosition = position;
      _previewDecryptedMessages = decryptedMessages;
    });
  }

  void _hideStealthPreview() {
    if (_previewConversation != null && mounted) {
      setState(() {
        _previewConversation = null;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final useFluent = themeProvider.useFluentUI;

    final Widget desktopContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Pane 1: Inbox (Floating)
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: disableTransparency
                  ? colorScheme.surfaceContainer
                  : colorScheme.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
              border: isM3E
                  ? Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
              child: disableTransparency
                  ? _buildConversationList(isDesktop: true)
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: _buildConversationList(isDesktop: true),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Pane 2: Chat (Floating)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: disableTransparency
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
                border: isM3E
                    ? Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        width: 1,
                      )
                    : Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
                child: disableTransparency
                    ? _buildChatPane(isM3E, theme)
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: _buildChatPane(isM3E, theme),
                      ),
              ),
            ),
          ),
          // Pane 3: Details (Floating)
          if (_selectedConversation != null && _showDetails) ...[
            const SizedBox(width: 12),
            Container(
              width: 350,
              decoration: BoxDecoration(
                color: disableTransparency
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
                border: isM3E
                    ? Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        width: 1,
                      )
                    : Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
                child: disableTransparency
                    ? _buildDetailsPane()
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: _buildDetailsPane(),
                      ),
              ),
            ),
          ],
        ],
      ),
    );

    if (useFluent && isDesktop) {
      return AdaptiveScaffold(
        title: const Text('Messages'),
        actions: [
          fluent.Tooltip(
            message: _isListView ? 'Switch to Bubble Layout' : 'Switch to List Layout',
            child: fluent.IconButton(
              icon: Icon(_isListView ? Icons.bubble_chart_outlined : Icons.view_list_outlined, size: 20),
              onPressed: () {
                setState(() {
                  _isListView = !_isListView;
                });
                _saveViewPreferences();
                HapticFeedback.lightImpact();
              },
            ),
          ),
          fluent.Tooltip(
            message: 'New Group',
            child: fluent.IconButton(
              icon: const Icon(FluentIcons.people_add_24_regular, size: 20),
              onPressed: () => context.push('/messages/new-group'),
            ),
          ),
          fluent.Tooltip(
            message: 'New Message',
            child: fluent.IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => context.push('/new-message'),
            ),
          ),
        ],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveLayout.maxContentWidth,
            ),
            child: _buildFluentDesktopContent(context, isM3E, theme),
          ),
        ),
      );
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            DesktopHeader(
              title: 'Messages',
              actions: [
                IconButton(
                  icon: Icon(_isListView ? Icons.bubble_chart_outlined : Icons.view_list_outlined),
                  onPressed: () {
                    setState(() {
                      _isListView = !_isListView;
                    });
                    _saveViewPreferences();
                    HapticFeedback.lightImpact();
                  },
                  tooltip: _isListView ? 'Switch to Bubble Layout' : 'Switch to List Layout',
                ),
                IconButton(
                  icon: const Icon(FluentIcons.people_add_24_regular),
                  onPressed: () => context.push('/messages/new-group'),
                  tooltip: 'New Group',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/new-message'),
                  tooltip: 'New Message',
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ResponsiveLayout.maxContentWidth,
                  ),
                  child: Stack(
                    children: [
                      desktopContent,
                      if (_previewConversation != null)
                        _StealthPreviewPopup(
                          conversation: _previewConversation!,
                          position: _previewPosition,
                          onDismiss: _hideStealthPreview,
                          decryptedMessages: _previewDecryptedMessages,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Messages',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  _isListView ? Icons.bubble_chart_outlined : Icons.view_list_outlined,
                  color: colorScheme.onSurface,
                ),
                onPressed: () {
                  setState(() {
                    _isListView = !_isListView;
                  });
                  _saveViewPreferences();
                  HapticFeedback.lightImpact();
                },
                tooltip: _isListView ? 'Switch to Bubble Layout' : 'Switch to List Layout',
              ),
              IconButton(
                icon: const Icon(FluentIcons.people_add_24_regular),
                onPressed: () => context.push('/messages/new-group'),
                tooltip: 'New Group',
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colorScheme.onSurface),
                onPressed: () => context.push('/new-message'),
              ),
            ],
          ),
          body: _buildConversationList(isDesktop: false),
        ),
        if (_previewConversation != null)
          _StealthPreviewPopup(
            conversation: _previewConversation!,
            position: _previewPosition,
            onDismiss: _hideStealthPreview,
            decryptedMessages: _previewDecryptedMessages,
          ),
      ],
    );
  }

  Widget _buildFluentDesktopContent(
    BuildContext context,
    bool isM3E,
    ThemeData theme,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final fluentTheme = fluent.FluentTheme.of(context);
    final dividerColor = fluentTheme.resources.dividerStrokeColorDefault;

    return Stack(
      children: [
        Row(
          children: [
            // Pane 1: Inbox (Integrated)
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: dividerColor, width: 1),
                ),
              ),
              child: _buildConversationList(isDesktop: true),
            ),

            // Pane 2: Chat
            Expanded(child: _buildChatPane(isM3E, theme)),

            // Pane 3: Details (Integrated)
            if (_selectedConversation != null && _showDetails)
              Container(
                width: 350,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: dividerColor, width: 1),
                  ),
                ),
                child: _buildDetailsPane(),
              ),
          ],
        ),
        if (_previewConversation != null)
          _StealthPreviewPopup(
            conversation: _previewConversation!,
            position: _previewPosition,
            onDismiss: _hideStealthPreview,
            decryptedMessages: _previewDecryptedMessages,
          ),
      ],
    );
  }

  Widget _buildChatPane(bool isM3E, ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _selectedConversation == null
          ? Center(
              key: const ValueKey('empty'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.05),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 3.seconds),
                  const SizedBox(height: 16),
                  Text(
                    'SELECT A CONVERSATION',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            )
          : ChatScreen(
              key: ValueKey(_selectedConversation!.id),
              conversationId: _selectedConversation!.id,
              otherUserName: _selectedConversation!.otherUserName,
              otherUserAvatar: _selectedConversation!.otherUserAvatar,
              otherUserId: _selectedConversation!.otherUserId,
              isDetailsOpen: _showDetails,
              onDetailsToggle: () =>
                  setState(() => _showDetails = !_showDetails),
              bgOpacity: _bgOpacity,
              bgBrightness: _bgBrightness,
            ),
    );
  }

  Widget _buildDetailsPane() {
    return ChatDetailsScreen(
      conversationId: _selectedConversation!.id,
      otherUserName: _selectedConversation!.otherUserName,
      otherUserAvatar: _selectedConversation!.otherUserAvatar,
      otherUserId: _selectedConversation!.otherUserId,
      whisperMode: _selectedConversation!.whisperMode,
      onBackgroundSettingsChanged: (opacity, brightness) {
        setState(() {
          _bgOpacity = opacity;
          _bgBrightness = brightness;
        });
      },
    );
  }

  Widget _buildConversationList({required bool isDesktop}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Selector<ConversationProvider, List<Conversation>>(
      selector: (_, provider) => provider.conversations,
      builder: (context, conversations, child) {
        final provider = Provider.of<ConversationProvider>(
          context,
          listen: false,
        );
        if (provider.isLoading && conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<Conversation> allConversations = [
          ...conversations,
          // if (_useMockData) ..._generateMockConversations(),
        ];

        final List<Conversation> filteredConversations = allConversations.where(
          (c) {
            final query = _searchQuery.toLowerCase();
            return c.otherUserName.toLowerCase().contains(query) ||
                (c.lastMessage?.toLowerCase().contains(query) ?? false);
          },
        ).toList();

        final pinnedConversations = filteredConversations
            .where((c) => c.isPinned)
            .toList();
        final regularConversations = filteredConversations
            .where((c) => !c.isPinned)
            .toList();

        final themeProvider = Provider.of<ThemeProvider>(context);
        final useFluent = themeProvider.useFluentUI;
        final isM3E = themeProvider.isM3EEnabled;

        final List<Widget> slivers = [];

        // Search Box Sliver
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: useFluent && isDesktop
                  ? fluent.TextBox(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      placeholder: 'Search...',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(fluent.FluentIcons.search, size: 12),
                      ),
                      suffix: _searchController.text.isNotEmpty
                          ? fluent.IconButton(
                              icon: const Icon(
                                fluent.FluentIcons.chrome_close,
                                size: 8,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val),
                    )
                  : Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: CustomTextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        hint: 'Search...',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                        fillColor: Colors.transparent,
                        borderRadius: 32,
                        margin: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
            ),
          ),
        );

        if (_isListView) {
          // List View Layout
          if (pinnedConversations.isNotEmpty) {
            slivers.addAll([
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'FAVORITES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final c = pinnedConversations[index];
                    return _ConversationListTile(
                      conversation: c,
                      label: _conversationLabels[c.id],
                      onTap: () => _handleConversationTap(c, isDesktop),
                      onLongPress: _handleLongPressBubble,
                    );
                  },
                  childCount: pinnedConversations.length,
                ),
              ),
            ]);
          }

          if (regularConversations.isNotEmpty) {
            slivers.addAll([
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'ALL MESSAGES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final c = regularConversations[index];
                    return _ConversationListTile(
                      conversation: c,
                      label: _conversationLabels[c.id],
                      onTap: () => _handleConversationTap(c, isDesktop),
                      onLongPress: _handleLongPressBubble,
                    );
                  },
                  childCount: regularConversations.length,
                ),
              ),
            ]);
          }
        } else {
          // Bubble Grid Layout
          if (pinnedConversations.isNotEmpty) {
            slivers.addAll([
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FAVORITES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditingFavorites = !_isEditingFavorites;
                          });
                        },
                        child: Text(
                          _isEditingFavorites ? 'DONE' : 'EDIT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _BentoPinnedGrid(
                    conversations: pinnedConversations,
                    onTap: (c) => _handleConversationTap(c, isDesktop),
                    isSelected: (c) =>
                        isDesktop && _selectedConversation?.id == c.id,
                    conversationSizes: _conversationSizes,
                    onToggleSize: _toggleSize,
                    onTogglePin: _togglePin,
                    isEditing: _isEditingFavorites,
                  ),
                ),
              ),
            ]);
          }

          slivers.addAll([
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Text(
                  'RECENT BUBBLES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 24,
                  children: regularConversations
                      .map(
                        (c) => _FloatingBubble(
                          key: ValueKey(c.id),
                          conversation: c,
                          label: _conversationLabels[c.id],
                          onTap: () => _handleConversationTap(c, isDesktop),
                          onLongPress: _handleLongPressBubble,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ]);
        }

        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

        return RefreshIndicator(
          onRefresh: () => provider.loadConversations(silent: false),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: slivers,
          ),
        );
      },
    );
  }

  // List<Conversation> _generateMockConversations() {
  //   final names = [
  //     'Alex Rivera',
  //     'Sarah Chen',
  //     'Jordan Smith',
  //     'Mila Kunis',
  //     'David Bowie',
  //     'Elena Gilbert',
  //     'Marcus Aurelius',
  //     'Luna Lovegood',
  //     'Peter Parker',
  //     'Tony Stark',
  //     'Wanda Maximoff',
  //     'Steve Rogers',
  //     'Natasha Romanoff',
  //     'Bruce Banner',
  //     'Diana Prince',
  //     'Arthur Curry',
  //     'Barry Allen',
  //     'Victor Stone',
  //     'Hal Jordan',
  //     'Oliver Queen',
  //   ];
  //
  //   // Default some to pinned if none are set yet (first run experience)
  //   if (_pinnedMockIds.isEmpty && _searchQuery.isEmpty) {
  //     for (int i = 0; i < 6; i++) {
  //       _pinnedMockIds.add('mock_$i');
  //     }
  //   }
  //
  //   return List.generate(names.length, (index) {
  //     final id = 'mock_$index';
  //     int unread = 0;
  //     List<String> mockMessages = [];
  //     if (index == 0) {
  //       unread = 3;
  //       mockMessages = [
  //         "Hey!",
  //         "The bubbles look amazing 🫧",
  //         "Can't wait to test!",
  //       ];
  //     } else if (index == 12) {
  //       unread = 5;
  //       mockMessages = [
  //         "Wait, stealth preview?",
  //         "Cool",
  //         "Privacy game changer",
  //         "Coffee?",
  //         "Bubble tea!",
  //       ];
  //     }
  //     return Conversation(
  //       id: id,
  //       otherUserId: 'user_$index',
  //       otherUserName: names[index],
  //       otherUserAvatar: '',
  //       lastMessage: mockMessages.isNotEmpty ? mockMessages.last : 'Hello!',
  //       lastMessageTime: DateTime.now().subtract(Duration(minutes: index * 15)),
  //       unreadCount: unread,
  //       isPinned: _pinnedMockIds.contains(id),
  //       recentMessages: mockMessages,
  //     );
  //   });
  // }

  void _handleConversationTap(Conversation conversation, bool isDesktop) async {
    // Unfocus to prevent keyboard state sync issues during transition
    FocusManager.instance.primaryFocus?.unfocus();

    final vaultService = Provider.of<VaultService>(context, listen: false);

    // Ensure vault service is initialized
    await vaultService.isReady;

    if (vaultService.isInVaultSync(conversation.id) &&
        !vaultService.isItemUnlocked(conversation.id)) {
      final authorized = await vaultService.authenticate(
        itemId: conversation.id,
        context: context,
      );
      if (!authorized) return;
    }

    if (isDesktop) {
      // On desktop, we always setState to ensure the view refreshes,
      // but only load settings if the ID changed or we just unlocked.
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedConversation = conversation;
        _bgOpacity =
            prefs.getDouble('chat_bg_opacity_${conversation.id}') ?? 1.0;
        _bgBrightness =
            prefs.getDouble('chat_bg_brightness_${conversation.id}') ?? 0.7;
      });
    } else {
      if (mounted) {
        // Await the push so that we can handle state changes upon return
        await context.push(
          '/messages/${conversation.id}',
          extra: {
            'otherUserName': conversation.otherUserName,
            'otherUserAvatar': conversation.otherUserAvatar,
            'otherUserId': conversation.otherUserId,
          },
        );
        // Refresh UI state when returning from chat
        if (mounted) setState(() {});
      }
    }
  }
}

class _BentoPinnedGrid extends StatelessWidget {
  final List<Conversation> conversations;
  final Function(Conversation) onTap;
  final bool Function(Conversation) isSelected;
  final Map<String, int> conversationSizes;
  final Function(String) onToggleSize;
  final Function(String) onTogglePin;
  final bool isEditing;
  const _BentoPinnedGrid({
    required this.conversations,
    required this.onTap,
    required this.isSelected,
    required this.conversationSizes,
    required this.onToggleSize,
    required this.onTogglePin,
    this.isEditing = false,
  });
  @override
  Widget build(BuildContext context) {
    return StaggeredGrid.count(
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: conversations.map((conversation) {
        final sizeTier = conversationSizes[conversation.id] ?? 0;
        int crossAxis = 2;
        int mainAxis = 1;
        if (sizeTier == 1) {
          mainAxis = 2;
        } else if (sizeTier == 2) {
          crossAxis = 4;
        }
        return StaggeredGridTile.count(
          crossAxisCellCount: crossAxis,
          mainAxisCellCount: mainAxis,
          child: _BentoItem(
            key: ValueKey(conversation.id),
            conversation: conversation,
            onTap: () => onTap(conversation),
            onLongPress: () => onToggleSize(conversation.id),
            onTogglePin: () => onTogglePin(conversation.id),
            selected: isSelected(conversation),
            isLarge: mainAxis > 1,
            isWide: crossAxis > 2,
            isEditing: isEditing,
          ),
        );
      }).toList(),
    );
  }
}

class _BentoItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onTogglePin;
  final bool selected;
  final bool isLarge;
  final bool isWide;
  final bool isEditing;
  const _BentoItem({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    required this.onTogglePin,
    required this.selected,
    required this.isLarge,
    this.isWide = false,
    this.isEditing = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vibeColor = _getVibeColor(conversation.otherUserName);

    // Vault check
    final vault = context.watch<VaultService>();
    final isLocked =
        vault.isInVaultSync(conversation.id) &&
        !vault.isItemUnlocked(conversation.id);

    debugPrint(
      'BentoItem(${conversation.otherUserName}): isLocked=$isLocked, lastMsg=${conversation.lastMessage?.length} chars',
    );

    // Current user ID for 'You: ' prefix
    final currentUserId =
        AppRouter.rootNavigatorKey.currentContext
                ?.read<ConversationProvider>()
                .conversations
                .where((c) => c.id == conversation.id)
                .firstOrNull
                ?.lastMessageSenderId ==
            AuthService().currentUser?.id
        ? AuthService().currentUser?.id
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTapDown: (details) {
          // Desktop right-click support
          _showBentoMenu(context, details.globalPosition);
        },
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              vibeColor.withValues(alpha: 0.12),
              vibeColor.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Stack(
              children: [
                Positioned(
                  top: -15,
                  right: -15,
                  child:
                      Container(
                            width: isWide ? 150 : 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  vibeColor.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.2, 1.2),
                            duration: 3.seconds,
                          ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: isLarge
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Consumer<PresenceProvider>(
                                  builder: (context, provider, child) =>
                                      _PresenceRipple(
                                        active:
                                            conversation.type == 'direct' &&
                                            provider.isUserOnline(
                                              conversation.otherUserId,
                                            ),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundImage:
                                              conversation
                                                  .otherUserAvatar
                                                  .isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  conversation.otherUserAvatar,
                                                )
                                              : null,
                                          onBackgroundImageError:
                                              (exception, stackTrace) {
                                                debugPrint(
                                                  'Avatar image error: $exception',
                                                );
                                              },
                                          child:
                                              conversation
                                                  .otherUserAvatar
                                                  .isEmpty
                                              ? (conversation.type == 'group'
                                                    ? const Icon(
                                                        Icons.group,
                                                        size: 20,
                                                      )
                                                    : Text(
                                                        conversation
                                                                .otherUserName
                                                                .isNotEmpty
                                                            ? conversation
                                                                  .otherUserName[0]
                                                                  .toUpperCase()
                                                            : 'U',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ))
                                              : null,
                                        ),
                                      ),
                                ),
                                if (conversation.unreadCount > 0)
                                  UnreadBadgeWidget(
                                    count: conversation.unreadCount,
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              conversation.otherUserName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isLocked
                                  ? 'Locked bubble'
                                  : conversation.getLastMessageDisplay(
                                      currentUserId,
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Consumer<PresenceProvider>(
                              builder: (context, provider, child) =>
                                  _PresenceRipple(
                                    active: provider.isUserOnline(
                                      conversation.otherUserId,
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundImage:
                                          conversation
                                              .otherUserAvatar
                                              .isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              conversation.otherUserAvatar,
                                            )
                                          : null,
                                      child: conversation.otherUserName.isEmpty
                                          ? const Text('')
                                          : Text(
                                              conversation.otherUserName[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    conversation.otherUserName,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (isWide)
                                    Text(
                                      isLocked
                                          ? 'Locked bubble'
                                          : conversation.getLastMessageDisplay(
                                              currentUserId,
                                            ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 10,
                                            color: colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (conversation.unreadCount > 0)
                              UnreadBadgeWidget(
                                count: conversation.unreadCount,
                              ),
                          ],
                        ),
                ),
                if (isEditing)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onTogglePin,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withAlpha(200),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    )).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  void _showBentoMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: <PopupMenuEntry>[
        PopupMenuItem(
          onTap: onLongPress,
          child: const Row(
            children: [
              Icon(Icons.aspect_ratio_rounded, size: 20),
              SizedBox(width: 12),
              Text('Resize Grid'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onTogglePin,
          child: Row(
            children: [
              Icon(
                conversation.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                size: 20,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 12),
              Text(conversation.isPinned ? 'Unfavorite' : 'Add to Favorites'),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  final Conversation conversation;
  final String? label;
  final VoidCallback onTap;
  final Function(Conversation, Offset) onLongPress;
  const _FloatingBubble({
    super.key,
    required this.conversation,
    this.label,
    required this.onTap,
    required this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vibeColor = _getVibeColor(conversation.otherUserName);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: (details) =>
            onLongPress(conversation, details.globalPosition),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: -2,
                right: 18,
                child:
                    Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.05, 1.05),
                          duration: 2.seconds,
                        ),
              ),
              Positioned(
                bottom: -6,
                right: 10,
                child:
                    Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.black, width: 0.5),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.1, 1.1),
                          duration: 2.5.seconds,
                        ),
              ),
              Consumer<PresenceProvider>(
                builder: (context, provider, child) => _PresenceRipple(
                  active:
                      conversation.type == 'direct' &&
                      provider.isUserOnline(conversation.otherUserId),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.surface,
                      border: Border.all(
                        color: colorScheme.primary,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          color: vibeColor.withValues(alpha: 0.05),
                          child: conversation.otherUserAvatar.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: conversation.otherUserAvatar,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: conversation.type == 'group'
                                      ? Icon(
                                          Icons.group,
                                          color: vibeColor.withValues(
                                            alpha: 0.8,
                                          ),
                                          size: 30,
                                        )
                                      : Text(
                                          conversation.otherUserName.isNotEmpty
                                              ? conversation.otherUserName[0]
                                                    .toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            color: vibeColor.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (conversation.unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: UnreadBadgeWidget(count: conversation.unreadCount),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  conversation.otherUserName.split(' ')[0],
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: conversation.unreadCount > 0
                        ? FontWeight.w900
                        : FontWeight.w600,
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (label != null && label!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    )).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn();
  }
}

class _StealthPreviewPopup extends StatelessWidget {
  final Conversation conversation;
  final Offset position;
  final VoidCallback onDismiss;
  final List<String> decryptedMessages;

  const _StealthPreviewPopup({
    required this.conversation,
    required this.position,
    required this.onDismiss,
    required this.decryptedMessages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final vibeColor = _getVibeColor(conversation.otherUserName);
    const double popupHeight = 380;
    const double popupWidth = 280;
    final double safeTop = padding.top + kToolbarHeight + 10;
    final double safeBottom = size.height - padding.bottom - 20;

    double left = position.dx - (popupWidth / 2);
    if (left < 20) left = 20;
    if (left + popupWidth > size.width - 20) {
      left = size.width - popupWidth - 20;
    }

    double top = position.dy - popupHeight - 20;
    if (top < safeTop) top = position.dy + 30;
    if (top + popupHeight > safeBottom) top = safeBottom - popupHeight;
    if (top < safeTop) top = safeTop;

    final messages = decryptedMessages.isNotEmpty
        ? decryptedMessages
        : [conversation.lastMessage ?? 'No preview available'];

    return GestureDetector(
      onTap: onDismiss,
      onVerticalDragStart: (_) => onDismiss(),
      onHorizontalDragStart: (_) => onDismiss(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child:
                  Container(
                        width: popupWidth,
                        height: popupHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: vibeColor.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: vibeColor.withValues(alpha: 0.25),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                            child: Container(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.8,
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage:
                                              conversation
                                                  .otherUserAvatar
                                                  .isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  conversation.otherUserAvatar,
                                                )
                                              : null,
                                          child:
                                              conversation
                                                  .otherUserAvatar
                                                  .isEmpty
                                              ? Text(
                                                  conversation.otherUserName[0],
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            conversation.otherUserName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.visibility_off_rounded,
                                          size: 16,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                    height: 1,
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.2),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: messages.length,
                                      itemBuilder: (context, index) =>
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    16,
                                                  ).copyWith(
                                                    bottomLeft:
                                                        const Radius.circular(
                                                          4,
                                                        ),
                                                  ),
                                              border: Border.all(
                                                color: theme
                                                    .colorScheme
                                                    .outlineVariant
                                                    .withValues(alpha: 0.1),
                                              ),
                                            ),
                                            child: Text(
                                              messages[index],
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      8,
                                      12,
                                      16,
                                    ),
                                    child: Text(
                                      'PEEKING • ${messages.length} UNREAD',
                                      style: TextStyle(
                                        color: vibeColor.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 9,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .scale(
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.8, 0.8),
                      ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _PresenceRipple extends StatelessWidget {
  final Widget child;
  final bool active;
  const _PresenceRipple({required this.child, this.active = false});
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (active)
          Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.2, 1.2),
                duration: 1.seconds,
              )
              .fadeOut(),
        child,
      ],
    );
  }
}

Color _getVibeColor(String name) {
  final int hash = name.hashCode;
  final colors = [
    Colors.blue,
    Colors.purple,
    const Color(0xFFD946EF),
    Colors.teal,
    Colors.indigo,
    Colors.cyan,
    const Color(0xFF3B82F6),
    const Color(0xFFA3E635),
  ];
  return colors[hash.abs() % colors.length];
}

class _ConversationListTile extends StatelessWidget {
  final Conversation conversation;
  final String? label;
  final VoidCallback onTap;
  final Function(Conversation, Offset) onLongPress;

  const _ConversationListTile({
    required this.conversation,
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vibeColor = _getVibeColor(conversation.otherUserName);
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      onLongPress: () {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        onLongPress(conversation, position + const Offset(100, 30));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Consumer<PresenceProvider>(
                  builder: (context, provider, child) => Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: provider.isUserOnline(conversation.otherUserId)
                            ? Colors.green
                            : colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: conversation.otherUserAvatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: conversation.otherUserAvatar,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                conversation.otherUserName.isNotEmpty
                                    ? conversation.otherUserName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: vibeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: UnreadBadgeWidget(count: conversation.unreadCount),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherUserName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (label != null && label!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage.isNotEmpty ? conversation.lastMessage : 'No messages yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasUnread
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _formatLastMessageTime(conversation.lastMessageTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasUnread ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }
}

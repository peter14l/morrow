import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/messages/presentation/providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/messages/presentation/screens/shared_content_screen.dart';
import 'package:oasis/widgets/moderation_dialogs.dart';
import 'package:oasis/widgets/custom_text_field.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class ChatDetailsScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserAvatar;
  final String otherUserId;
  final int whisperMode;
  final String? currentBackground;
  final Function(double opacity, double brightness)?
  onBackgroundSettingsChanged;

  const ChatDetailsScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.otherUserId,
    required this.whisperMode,
    this.currentBackground,
    this.onBackgroundSettingsChanged,
  });

  @override
  State<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class VerticalLineThumbShape extends SliderComponentShape {
  final double thumbWidth;
  final double thumbHeight;

  const VerticalLineThumbShape({
    this.thumbWidth = 4.0,
    this.thumbHeight = 24.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final rect = Rect.fromCenter(
      center: center,
      width: thumbWidth,
      height: thumbHeight,
    );

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );
  }
}

class _ChatDetailsScreenState extends State<ChatDetailsScreen> {
  late MessagingService _messagingService;
  late VaultService _vaultService;
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  int _whisperMode = 0;
  bool _isLocked = false;
  bool _isMuted = false;
  bool _isBlocked = false;
  String? _selectedBackground;
  double _bgOpacity = 1.0;
  double _bgBrightness = 0.7;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Message> _allMessages = [];
  List<Message> _searchResults = [];
  Timer? _searchDebounce;
  RealtimeChannel? _conversationChannel;

  @override
  void initState() {
    super.initState();
    _whisperMode = widget.whisperMode;
    _selectedBackground = widget.currentBackground;
    _loadPersistedSettings();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    // Note: messages for search are read from ChatProvider.state.messages
    // (already decrypted) — no re-initialization of SignalService needed here.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messagingService = Provider.of<MessagingService>(context);
    _vaultService = Provider.of<VaultService>(context);
    if (_conversationChannel == null) {
      _subscribeToConversationUpdates();
      _checkMuteStatus();
      _checkBlockStatus();
      _checkLockStatus();
    }
  }

  void _subscribeToConversationUpdates() {
    _conversationChannel = _messagingService.subscribeToConversation(
      conversationId: widget.conversationId,
      onUpdate: (mode) {
        if (mounted && mode != _whisperMode) {
          setState(() {
            _whisperMode = mode;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_conversationChannel != null) {
      _messagingService.unsubscribeFromMessages(_conversationChannel!);
    }
    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  Future<void> _checkMuteStatus() async {
    try {
      final muted = await _messagingService.getMuteStatus(
        widget.conversationId,
      );
      if (mounted) {
        setState(() => _isMuted = muted);
      }
    } catch (e) {
      debugPrint('Error checking mute status: $e');
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final blocked = await _messagingService.isUserBlocked(widget.otherUserId);
      if (mounted) {
        setState(() => _isBlocked = blocked);
      }
    } catch (e) {
      debugPrint('Error checking block status: $e');
    }
  }

  Future<void> _toggleMute(bool value) async {
    try {
      await _messagingService.toggleMute(widget.conversationId, value);
      setState(() => _isMuted = value);

      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        final useFluent = themeProvider.useFluentUI;
        final isDesktop = MediaQuery.of(context).size.width >= 1000;

        if (useFluent && isDesktop) {
          fluent.displayInfoBar(
            context,
            builder: (context, close) => fluent.InfoBar(
              title: Text(value ? 'Muted' : 'Unmuted'),
              content: Text(
                value
                    ? 'Notifications for this chat are now silent.'
                    : 'Notifications for this chat are enabled.',
              ),
              severity: fluent.InfoBarSeverity.info,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? 'Notifications muted' : 'Notifications unmuted',
              ),
              backgroundColor: value ? Colors.orange : Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating mute status: $e')),
        );
      }
    }
  }

  Future<void> _toggleBlock() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _isBlocked
              ? 'Unblock ${widget.otherUserName}?'
              : 'Block ${widget.otherUserName}?',
        ),
        content: Text(
          _isBlocked
              ? 'They will be able to message you again.'
              : 'They will no longer be able to message you or see your posts.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (_isBlocked) {
          await _messagingService.unblockUser(widget.otherUserId);
        } else {
          await _messagingService.blockUser(widget.otherUserId);
        }

        setState(() => _isBlocked = !_isBlocked);

        if (mounted) {
          if (useFluent && isDesktop) {
            fluent.displayInfoBar(
              context,
              builder: (context, close) => fluent.InfoBar(
                title: Text(_isBlocked ? 'User Blocked' : 'User Unblocked'),
                severity: _isBlocked
                    ? fluent.InfoBarSeverity.error
                    : fluent.InfoBarSeverity.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isBlocked ? 'User blocked' : 'User unblocked'),
                backgroundColor: _isBlocked ? Colors.red : Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating block status: $e')),
          );
        }
      }
    }
  }

  void _navigateToSharedContent(BuildContext context) {
    List<Message> messagesToPass;
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      messagesToPass = chatProvider.state.messages;
    } catch (_) {
      messagesToPass = _allMessages;
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 800,
            height: 600,
            child: SharedContentScreen(
              conversationId: widget.conversationId,
              otherUserName: widget.otherUserName,
              messages: messagesToPass,
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedContentScreen(
            conversationId: widget.conversationId,
            otherUserName: widget.otherUserName,
            messages: messagesToPass,
          ),
        ),
      );
    }
  }

  void _onSearchChanged(String query, [VoidCallback? onDebounceComplete]) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      onDebounceComplete?.call();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      // Read already-decrypted messages from the ambient ChatProvider
      // to avoid re-initializing Signal (which causes InvalidKeyIdException)
      List<Message> allMessages;
      try {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        allMessages = chatProvider.state.messages;
      } catch (_) {
        allMessages = _allMessages; // fallback if provider not in tree
      }

      final results = allMessages.where((m) {
        return m.content.toLowerCase().contains(query.toLowerCase());
      }).toList();

      setState(() {
        _searchResults = results;
      });
      onDebounceComplete?.call();
    });
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: widget.otherUserName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New group name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      try {
        await context.read<ChatProvider>().updateGroupName(newName);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error renaming group: $e')));
      }
    }
  }

  Future<void> _addParticipants() async {
    // Navigate to GroupMemberSelectionScreen but with "Add" mode
    final List<String>? selectedUserIds = await context.push<List<String>>(
      '/messages/add-members',
    );

    if (selectedUserIds != null && selectedUserIds.isNotEmpty && mounted) {
      try {
        await context.read<ChatProvider>().addMembers(selectedUserIds);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding members: $e')));
      }
    }
  }

  void _showSearchModal() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (modalContext) => SafeArea(
        child: StatefulBuilder(
          builder: (statefulContext, setModalState) {
            final theme = Theme.of(statefulContext);
            return Container(
              height: MediaQuery.of(statefulContext).size.height * 0.8,
              decoration: BoxDecoration(
                color: context.shouldUseSolidBackground
                    ? (theme.brightness == Brightness.dark
                          ? const Color(0xFF1A1D24)
                          : Colors.white)
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CustomTextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      onChanged: (val) {
                        final wasEmpty = _searchController.text.length <= 1 && val.isNotEmpty;
                        final becameEmpty = val.isEmpty;
                        _onSearchChanged(val, () {
                          setModalState(() {});
                        });
                        if (wasEmpty || becameEmpty) {
                          setModalState(() {});
                        }
                      },
                      hint: 'Search in this chat...',
                      prefixIcon: FluentIcons.search_24_regular,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(FluentIcons.dismiss_24_regular),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('', () {
                                  setModalState(() {});
                                });
                                setModalState(() {});
                              },
                            )
                          : null,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      borderRadius: 20,
                    ),
                  ),
                  Expanded(
                    child: _searchController.text.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FluentIcons.chat_24_regular,
                                  size: 48,
                                  color: Colors.white24,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Search for keywords',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ],
                            ),
                          )
                        : _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'No messages found',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _searchResults.length,
                            itemBuilder: (listContext, index) {
                              final msg = _searchResults[index];
                              return ListTile(
                                leading: const Icon(
                                  FluentIcons.history_24_regular,
                                  size: 20,
                                  color: Colors.white24,
                                ),
                                title: Text(
                                  msg.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _formatTimestamp(msg.timestamp),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () {
                                  chatProvider.scrollToMessage(msg.id);
                                  Navigator.pop(
                                    modalContext,
                                  ); // Close bottom sheet
                                  Navigator.pop(
                                    context,
                                  ); // Close ChatDetailsScreen
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('E, d MMM').format(timestamp);
  }

  Future<void> _checkLockStatus() async {
    try {
      final vaultService = Provider.of<VaultService>(context, listen: false);
      final isLocked = await vaultService.isInVault(widget.conversationId);
      if (mounted) {
        setState(() => _isLocked = isLocked);
      }
    } catch (e) {
      debugPrint('Error checking lock status: $e');
    }
  }

  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bgOpacity =
            prefs.getDouble('chat_bg_opacity_${widget.conversationId}') ?? 1.0;
        _bgBrightness =
            prefs.getDouble('chat_bg_brightness_${widget.conversationId}') ??
            0.7;
      });
    }
  }

  Future<void> _toggleChatLock(bool value) async {
    final vaultService = Provider.of<VaultService>(context, listen: false);
    final isVaultEnabled = await vaultService.isVaultEnabled();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    if (!isVaultEnabled && value) {
      if (mounted) {
        if (useFluent && isDesktop) {
          fluent.displayInfoBar(
            context,
            builder: (context, close) => const fluent.InfoBar(
              title: Text('Vault Disabled'),
              content: Text('Please enable Vault in Settings first'),
              severity: fluent.InfoBarSeverity.warning,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Vault in Settings first'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    try {
      if (value) {
        await vaultService.addToVault(
          itemId: widget.conversationId,
          type: VaultItemType.conversation,
        );
      } else {
        await vaultService.removeFromVault(widget.conversationId);
      }

      setState(() => _isLocked = value);

      if (mounted) {
        if (useFluent && isDesktop) {
          fluent.displayInfoBar(
            context,
            builder: (context, close) => fluent.InfoBar(
              title: Text(value ? 'Chat Locked' : 'Chat Unlocked'),
              content: Text(
                value
                    ? 'This conversation is now protected in your Vault.'
                    : 'Conversation removed from Vault.',
              ),
              severity: value
                  ? fluent.InfoBarSeverity.success
                  : fluent.InfoBarSeverity.info,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? 'Chat locked to Vault' : 'Chat unlocked'),
              backgroundColor: value ? Colors.indigo : Colors.grey,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (useFluent && isDesktop) {
          fluent.displayInfoBar(
            context,
            builder: (context, close) => fluent.InfoBar(
              title: const Text('Vault Error'),
              content: Text('Error updating vault: $e'),
              severity: fluent.InfoBarSeverity.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating vault: $e')));
        }
      }
    }
  }

  Future<void> _updateBgOpacity(double value) async {
    setState(() => _bgOpacity = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chat_bg_opacity_${widget.conversationId}', value);
    widget.onBackgroundSettingsChanged?.call(_bgOpacity, _bgBrightness);
  }

  Future<void> _updateBgBrightness(double value) async {
    setState(() => _bgBrightness = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chat_bg_brightness_${widget.conversationId}', value);
    widget.onBackgroundSettingsChanged?.call(_bgOpacity, _bgBrightness);
  }

  Future<String?> _getInitialDirectory() async {
    if (Platform.isWindows) {
      try {
        final dir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        return dir.path;
      } catch (e) {
        debugPrint('Error getting initial directory: $e');
      }
    }
    return null;
  }

  Future<void> _pickBackground() async {
    try {
      XFile? image;
      if (Platform.isWindows) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          initialDirectory: await _getInitialDirectory(),
        );
        if (result != null && result.files.single.path != null) {
          image = XFile(result.files.single.path!);
        }
      } else {
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
        );
      }

      if (image != null) {
        final backgroundUrl = await _messagingService.uploadChatMedia(
          image.path,
          folder: 'backgrounds',
        );

        setState(() => _selectedBackground = backgroundUrl);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'chat_bg_${widget.conversationId}',
          backgroundUrl,
        );

        try {
          await _messagingService.updateChatBackground(
            widget.conversationId,
            backgroundUrl,
          );
          if (mounted) {
            context.read<ChatProvider>().updateBackground(backgroundUrl);
          }
        } catch (e) {
          debugPrint('Failed to sync chat theme to Supabase: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking background: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeBackground() async {
    setState(() => _selectedBackground = null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_bg_${widget.conversationId}');

    try {
      await _messagingService.removeChatBackground(widget.conversationId);
      if (mounted) {
        context.read<ChatProvider>().updateBackground(null);
      }
    } catch (e) {
      debugPrint('Failed to sync chat theme removal to Supabase: $e');
    }
  }

  Future<void> _clearChat() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text(
          'This will remove all messages from this conversation.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('me'),
            child: const Text('Clear for me'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('everyone'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear for everyone'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        if (result == 'everyone') {
          await _messagingService.clearConversationMessages(
            widget.conversationId,
          );
        } else {
          await _messagingService.clearChatForMe(widget.conversationId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == 'everyone'
                    ? 'Chat cleared for everyone'
                    : 'Chat cleared for you',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error clearing chat: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;
    final vault = context.watch<VaultService>();
    final current = vault.getLockInterval(widget.conversationId);

    final canPop = Navigator.of(context).canPop();

    final Widget bodyContent = Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 600 : double.infinity,
        ),
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: isDesktop ? (kToolbarHeight + 20) : 16,
            bottom: 48,
          ),
          children: [
            _buildProfileHeader(theme, colorScheme),
            _buildParticipantsSection(theme, colorScheme),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'Personalization'),
            _buildDetailCard(
              colorScheme,
              child: Column(
                children: [
                  _buildActionTile(
                    icon: FluentIcons.color_24_regular,
                    title: 'Chat Background',
                    subtitle: 'Custom image for this chat',
                    trailing: _selectedBackground != null
                        ? const Icon(
                            FluentIcons.checkmark_circle_24_filled,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
                    onTap: _pickBackground,
                  ),
                  if (_selectedBackground != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: _selectedBackground!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(
                                  FluentIcons.dismiss_12_filled,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                onPressed: _removeBackground,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black45,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(28, 28),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildSliderTile(
                      icon: FluentIcons.eye_24_regular,
                      title: 'Background Opacity',
                      value: _bgOpacity,
                      onChanged: _updateBgOpacity,
                    ),
                    _buildSliderTile(
                      icon: FluentIcons.brightness_high_24_regular,
                      title: 'Background Brightness',
                      value: _bgBrightness,
                      onChanged: _updateBgBrightness,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildActionTile(
                    icon: FluentIcons.image_24_regular,
                    title: 'Media, Files & Links',
                    subtitle: 'Shared content',
                    onTap: () => _navigateToSharedContent(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'Privacy & Safety'),
            _buildDetailCard(
              colorScheme,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: _isLocked
                        ? FluentIcons.lock_closed_24_filled
                        : FluentIcons.lock_open_24_regular,
                    title: 'Vault Lock',
                    subtitle: 'Hide and protect this chat',
                    value: _isLocked,
                    activeColor: Colors.indigo,
                    onChanged: _toggleChatLock,
                  ),
                  if (_isLocked)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lock Interval',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          fluent.RadioGroup<String>(
                            groupValue: current,
                            onChanged: (val) {
                              if (val != null) {
                                context.read<VaultService>().setLockInterval(
                                  widget.conversationId,
                                  val,
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCompactRadio(
                                  'App close',
                                  'app_close',
                                  colorScheme,
                                ),
                                _buildCompactRadio(
                                  'Chat close',
                                  'chat_close',
                                  colorScheme,
                                ),
                                _buildCompactRadio(
                                  '5 mins',
                                  '5mins',
                                  colorScheme,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'Whisper Mode'),
            _buildDetailCard(
              colorScheme,
              child: Column(
                children: [
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      final settings = chatProvider.settingsProvider;
                      return Column(
                        children: [
                          _buildSwitchTile(
                            icon: settings.whisperMode > 0
                                ? Icons.auto_delete
                                : Icons.auto_delete_outlined,
                            title: 'Whisper Mode',
                            subtitle: 'Messages disappear after being read',
                            value: settings.whisperMode > 0,
                            activeColor: Colors.orange,
                            onChanged: (val) {
                              settings.toggleWhisperMode(
                                currentWhisperMode: settings.whisperMode,
                                onModeChanged: (newMode, _) {
                                  chatProvider.setState(
                                    (s) => s.copyWith(whisperMode: newMode),
                                  );
                                },
                              );
                            },
                          ),
                          if (settings.whisperMode > 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Disappearing Duration',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildModeChip(
                                        context: context,
                                        label: 'Instant',
                                        isSelected: settings.whisperMode == 1,
                                        onTap: () {
                                          settings.setWhisperMode(1);
                                          chatProvider.setState(
                                            (s) => s.copyWith(whisperMode: 1),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildModeChip(
                                        context: context,
                                        label: '24 Hours',
                                        isSelected: settings.whisperMode == 2,
                                        onTap: () {
                                          settings.setWhisperMode(2);
                                          chatProvider.setState(
                                            (s) => s.copyWith(whisperMode: 2),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'Manage'),
            _buildDetailCard(
              colorScheme,
              child: Column(
                children: [
                  _buildActionTile(
                    icon: FluentIcons.search_24_regular,
                    title: 'Search in Chat',
                    subtitle: 'Find keywords',
                    onTap: _showSearchModal,
                  ),
                  _buildSwitchTile(
                    icon: _isMuted
                        ? FluentIcons.alert_off_24_regular
                        : FluentIcons.alert_24_regular,
                    title: 'Mute Notifications',
                    subtitle: 'Silence alerts for this chat',
                    value: _isMuted,
                    activeColor: Colors.orange,
                    onChanged: _toggleMute,
                  ),
                  _buildActionTile(
                    icon: FluentIcons.delete_24_regular,
                    title: 'Clear Chat',
                    titleColor: colorScheme.error,
                    iconColor: colorScheme.error,
                    onTap: _clearChat,
                  ),
                  _buildActionTile(
                    icon: _isBlocked
                        ? FluentIcons.person_available_24_regular
                        : FluentIcons.person_prohibited_24_regular,
                    title: _isBlocked
                        ? 'Unblock ${widget.otherUserName}'
                        : 'Block ${widget.otherUserName}',
                    titleColor: colorScheme.error,
                    iconColor: colorScheme.error,
                    onTap: _toggleBlock,
                  ),
                  _buildActionTile(
                    icon: FluentIcons.flag_24_regular,
                    title: 'Report ${widget.otherUserName}',
                    titleColor: colorScheme.error,
                    iconColor: colorScheme.error,
                    onTap: () {
                      ReportDialog.show(context, userId: widget.otherUserId);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );

    if (useFluent && isDesktop) {
      return PopScope(
        canPop: !_searchFocusNode.hasFocus,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
            setState(() {
              _searchController.clear();
              _searchResults = [];
            });
          }
        },
        child: fluent.ScaffoldPage(
          header: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: fluent.PageHeader(
              title: Text(
                'Details',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                  color: colorScheme.onSurface,
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.chevron_left),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          content: Material(color: Colors.transparent, child: bodyContent),
        ),
      );
    }

    return PopScope(
      canPop: !_searchFocusNode.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          setState(() {
            _searchController.clear();
            _searchResults = [];
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDesktop ? Colors.transparent : colorScheme.surface,
        extendBodyBehindAppBar: isDesktop,
        appBar: AppBar(
          title: Text(
            isDesktop ? 'Details' : 'Chat Details',
            style: TextStyle(
              fontWeight: isDesktop ? FontWeight.w900 : FontWeight.bold,
              fontSize: isDesktop ? 24 : 18,
              letterSpacing: isDesktop ? -0.5 : null,
              color: colorScheme.onSurface,
            ),
          ),
          centerTitle: !isDesktop,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          titleSpacing: isDesktop ? 24 : null,
          automaticallyImplyLeading: false,
          leading: isDesktop
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.chevron_left_24_regular),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back to chat',
                    ),
                    if (widget.onBackgroundSettingsChanged != null)
                      IconButton(
                        icon: const Icon(FluentIcons.dismiss_24_regular),
                        onPressed: () =>
                            widget.onBackgroundSettingsChanged!(0, 0),
                        tooltip: 'Close',
                      ),
                  ],
                )
              : (canPop
                    ? IconButton(
                        icon: const Icon(FluentIcons.chevron_left_24_regular),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null),
        ),
        body: bodyContent,
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, ColorScheme colorScheme) {
    final chatState = context.watch<ChatProvider>().state;
    final isGroup = chatState.conversationType == 'group';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: widget.otherUserAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserAvatar)
                  : null,
              child: widget.otherUserAvatar.isEmpty
                  ? Icon(
                      isGroup ? Icons.group : Icons.person,
                      size: 48,
                      color: colorScheme.primary,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.otherUserName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isGroup)
                IconButton(
                  icon: const Icon(FluentIcons.edit_24_regular, size: 20),
                  onPressed: _renameGroup,
                  tooltip: 'Rename Group',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.shield_task_24_regular,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'End-to-End Encrypted',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(ThemeData theme, ColorScheme colorScheme) {
    final chatState = context.watch<ChatProvider>().state;
    if (chatState.conversationType != 'group') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle(theme, 'Participants'),
        _buildDetailCard(
          colorScheme,
          child: Column(
            children: [
              _buildActionTile(
                icon: FluentIcons.person_add_24_regular,
                title: 'Add Members',
                onTap: _addParticipants,
              ),
              const Divider(indent: 56),
              ...chatState.participantIds.map((userId) {
                // Ideally we'd have a UserProvider to resolve these names
                return ListTile(
                  leading: const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 16),
                  ),
                  title: FutureBuilder<String>(
                    future: _resolveUsername(userId),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? 'Loading...',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  trailing: userId == _authService.currentUser?.id
                      ? const Text(
                          'You',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<String> _resolveUsername(String userId) async {
    try {
      final response = await SupabaseService().client
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .single();
      return response['username'] as String;
    } catch (e) {
      return 'Unknown User';
    }
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDetailCard(ColorScheme colorScheme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    if (useFluent && isDesktop) {
      return fluent.ListTile.selectable(
        leading: Icon(icon, color: iconColor ?? titleColor),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing:
            trailing ??
            const Icon(FluentIcons.chevron_right_24_regular, size: 20),
        onSelectionChange: (_) => onTap(),
      );
    }

    return ListTile(
      leading: Icon(icon, color: iconColor ?? titleColor),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing:
          trailing ??
          const Icon(FluentIcons.chevron_right_24_regular, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildModeChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required Function(bool) onChanged,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    if (useFluent && isDesktop) {
      return fluent.ListTile(
        leading: Icon(icon, color: value ? activeColor : null),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: Text(subtitle),
        trailing: fluent.ToggleSwitch(checked: value, onChanged: onChanged),
      );
    }

    return SwitchListTile(
      secondary: Icon(icon, color: value ? activeColor : null),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: activeColor,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required double value,
    required Function(double) onChanged,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final colorScheme = Theme.of(context).colorScheme;

    if (useFluent && isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  fluent.Slider(
                    value: value * 100,
                    onChanged: (v) => onChanged(v / 100),
                    min: 0,
                    max: 100,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isM3E ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                    letterSpacing: isM3E ? -0.2 : null,
                  ),
                ),
                isM3E
                    ? SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8.0,
                          activeTrackColor: colorScheme.primary,
                          inactiveTrackColor: colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          thumbColor: colorScheme.primary,
                          overlayColor: colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          thumbShape: const VerticalLineThumbShape(),
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                        child: Slider(
                          value: value,
                          onChanged: onChanged,
                          min: 0.0,
                          max: 1.0,
                        ),
                      )
                    : Slider(
                        value: value,
                        onChanged: onChanged,
                        min: 0.0,
                        max: 1.0,
                      ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: isM3E
                ? BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isM3E ? colorScheme.onPrimaryContainer : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRadio(
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final vault = context.watch<VaultService>();
    final current = vault.getLockInterval(widget.conversationId);
    final isSelected = current == value;

    if (useFluent && isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: fluent.RadioButton<String>(
          value: value,
          content: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSelected
                  ? fluent.FluentTheme.of(context).accentColor
                  : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.read<VaultService>().setLockInterval(
        widget.conversationId,
        value,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Radio<String>(
                value: value,
                // ignore: deprecated_member_use
                groupValue: current,
                activeColor: Colors.indigo,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) {
                    context.read<VaultService>().setLockInterval(
                      widget.conversationId,
                      val,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.indigo : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

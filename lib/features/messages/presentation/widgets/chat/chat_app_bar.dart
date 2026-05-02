import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:oasis/providers/presence_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/features/messages/presentation/providers/chat_provider.dart';

/// Chat app bar with avatar, presence indicator, encryption lock, and action buttons.
/// Extracted floating glassmorphic header from chat_screen.dart.
class ChatAppBar extends StatelessWidget {
  const ChatAppBar({
    super.key,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserId,
    this.isEncryptionReady = false,
    this.isDesktop = false,
    this.isDetailsOpen = false,
    this.onDetailsToggle,
    this.onCallPressed,
    this.onVideoCallPressed,
    this.onSearchPressed,
    this.backgroundUrl,
  });

  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserId;
  final bool isEncryptionReady;
  final bool isDesktop;
  final bool isDetailsOpen;
  final VoidCallback? onDetailsToggle;
  final VoidCallback? onCallPressed;
  final VoidCallback? onVideoCallPressed;
  final VoidCallback? onSearchPressed;
  final String? backgroundUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final useFluent = Provider.of<ThemeProvider>(context).useFluentUI;

    if (useFluent && isDesktop) {
      return _buildFluentAppBar(context, theme);
    }

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Left: Back button (mobile only)
          if (!isDesktop)
            _FloatingContainer(
              isCircular: true,
              backgroundUrl: backgroundUrl,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () {
                  final keyboardHeight = MediaQuery.of(
                    context,
                  ).viewInsets.bottom;
                  if (keyboardHeight > 0) {
                    FocusScope.of(context).unfocus();
                  } else {
                    if (context.mounted) context.pop();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          if (!isDesktop) const SizedBox(width: 8),

          // Middle: Avatar, name, status
          Expanded(
            child: GestureDetector(
              onTap: isDesktop ? null : onDetailsToggle,
              behavior: HitTestBehavior.opaque,
              child: _FloatingContainer(
                isCircular: false,
                backgroundUrl: backgroundUrl,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: isDesktop ? 18 : 16,
                            backgroundColor: colorScheme.primaryContainer,
                            backgroundImage: (otherUserAvatar ?? '').isNotEmpty
                                ? CachedNetworkImageProvider(otherUserAvatar!)
                                : null,
                            child: (otherUserAvatar ?? '').isEmpty
                                ? Text(
                                    (otherUserName.isNotEmpty
                                            ? otherUserName[0]
                                            : 'U')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                          Consumer<PresenceProvider>(
                            builder: (context, presenceProvider, child) {
                              final isOnline =
                                  otherUserId != null &&
                                  presenceProvider.isUserOnline(otherUserId!);
                              return Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              otherUserName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: isDesktop ? 15 : 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                                color: backgroundUrl != null ? Colors.white : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Consumer2<PresenceProvider, ChatProvider>(
                              builder: (context, presenceProvider, chatProvider, child) {
                                final presence = otherUserId != null
                                    ? presenceProvider.getUserPresence(
                                        otherUserId!,
                                      )
                                    : null;
                                final isOnline = presence?.status == 'online';
                                final isPQ = chatProvider.isQuantumSecure;

                                return Row(
                                  children: [
                                    if (isEncryptionReady) ...[
                                      Icon(
                                        isPQ 
                                          ? FluentIcons.shield_lock_24_filled 
                                          : FluentIcons.lock_closed_12_filled,
                                        size: 10,
                                        color: isPQ 
                                          ? Colors.cyanAccent 
                                          : (backgroundUrl != null
                                            ? Colors.white70
                                            : colorScheme.primary.withValues(
                                                alpha: 0.7,
                                              )),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    if (isPQ) ...[
                                      Text(
                                        'Quantum',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.cyanAccent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isOnline
                                                ? Colors.green.withValues(
                                                    alpha: 0.8,
                                                  )
                                                : (backgroundUrl != null
                                                    ? Colors.white60
                                                    : colorScheme.onSurfaceVariant
                                                      .withValues(alpha: 0.7)),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Right: Action buttons
          _FloatingContainer(
            isCircular: true,
            backgroundUrl: backgroundUrl,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onCallPressed != null && AppConfig.enableCalls)
                      IconButton(
                        icon: const Icon(FluentIcons.call_24_regular, size: 20),
                        onPressed: onCallPressed,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        color: backgroundUrl != null ? Colors.white : null,
                      ),
                    if (onVideoCallPressed != null && AppConfig.enableCalls)
                      IconButton(
                        icon: const Icon(FluentIcons.video_24_regular, size: 20),
                        onPressed: onVideoCallPressed,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        color: backgroundUrl != null ? Colors.white : null,
                      ),
                    if (isDesktop) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          isDetailsOpen
                              ? FluentIcons.info_24_filled
                              : FluentIcons.info_24_regular,
                          size: 20,
                        ),
                        onPressed: onDetailsToggle,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        color: backgroundUrl != null ? Colors.white : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentAppBar(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final fluentTheme = fluent.FluentTheme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: fluentTheme.scaffoldBackgroundColor.withValues(alpha: 0.8),
          border: Border(
            bottom: BorderSide(
              color: fluentTheme.resources.dividerStrokeColorDefault,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar & Name
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: (otherUserAvatar ?? '').isNotEmpty
                      ? CachedNetworkImageProvider(otherUserAvatar!)
                      : null,
                  child: (otherUserAvatar ?? '').isEmpty
                      ? Text(
                          (otherUserName.isNotEmpty ? otherUserName[0] : 'U').toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                Consumer<PresenceProvider>(
                  builder: (context, presenceProvider, child) {
                    final isOnline = otherUserId != null &&
                        presenceProvider.isUserOnline(otherUserId!);
                    return Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    otherUserName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Consumer<PresenceProvider>(
                    builder: (context, presenceProvider, child) {
                      final presence = otherUserId != null
                          ? presenceProvider.getUserPresence(otherUserId!)
                          : null;
                      final isOnline = presence?.status == 'online';

                      return Row(
                        children: [
                          if (isEncryptionReady) ...[
                            Icon(
                              FluentIcons.lock_closed_12_filled,
                              size: 10,
                              color: colorScheme.primary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isOnline
                                  ? Colors.green.withValues(alpha: 0.8)
                                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Actions
            fluent.CommandBar(
              overflowBehavior: fluent.CommandBarOverflowBehavior.noWrap,
              primaryItems: [
                if (AppConfig.enableCalls) ...[
                  fluent.CommandBarButton(
                    icon: const Icon(FluentIcons.call_24_regular, size: 18),
                    onPressed: onCallPressed,
                  ),
                  fluent.CommandBarButton(
                    icon: const Icon(FluentIcons.video_24_regular, size: 18),
                    onPressed: onVideoCallPressed,
                  ),
                ],
                fluent.CommandBarButton(
                  icon: const Icon(FluentIcons.search_24_regular, size: 18),
                  onPressed: onSearchPressed,
                ),
                fluent.CommandBarSeparator(),
                fluent.CommandBarButton(
                  icon: Icon(
                    isDetailsOpen
                        ? FluentIcons.info_24_filled
                        : FluentIcons.info_24_regular,
                    size: 18,
                  ),
                  onPressed: onDetailsToggle,
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeenTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _FloatingContainer extends StatelessWidget {
  final Widget child;
  final bool isCircular;
  final String? backgroundUrl;

  const _FloatingContainer({
    required this.child, 
    required this.isCircular,
    this.backgroundUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: backgroundUrl != null 
            ? Colors.black.withValues(alpha: 0.3)
            : colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: isCircular
            ? BorderRadius.circular(20)
            : BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: isCircular
            ? BorderRadius.circular(20)
            : BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

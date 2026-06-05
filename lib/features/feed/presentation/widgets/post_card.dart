import 'package:oasis/core/extensions/context_extensions.dart';
import 'dart:ui';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        Theme,
        ColorScheme,
        ThemeData,
        Brightness,
        Icons,
        CircularProgressIndicator,
        Hero,
        PageView,
        Builder,
        AspectRatio,
        BoxConstraints,
        TextSpan,
        RichText,
        InkWell,
        Curves,
        HapticFeedback,
        RelativeRect,
        RenderBox,
        Overlay,
        showMenu,
        PopupMenuItem,
        RoundedRectangleBorder,
        BorderSide,
        ListTile,
        SafeArea,
        EdgeInsets,
        Column,
        MainAxisSize,
        Row,
        Expanded,
        CircleAvatar,
        CrossAxisAlignment,
        Container,
        BoxDecoration,
        LinearGradient,
        Alignment,
        Padding,
        SizedBox,
        Widget,
        Stack,
        Positioned,
        ClipRRect,
        BackdropFilter,
        GestureDetector,
        IconButton,
        Wrap,
        WrapCrossAlignment,
        Icon,
        Text,
        TextStyle,
        FontWeight,
        VisualDensity,
        MouseRegion,
        AnimatedScale,
        AnimationController,
        Animation,
        TweenSequence,
        TweenSequenceItem,
        Tween,
        CurveTween,
        GlobalKey,
        ValueKey,
        State,
        StatefulWidget,
        BuildContext,
        List,
        Offset,
        Rect,
        Navigator,
        VoidCallback,
        ScaleTransition,
        SingleTickerProviderStateMixin,
        IconData,
        MediaQuery,
        BorderRadius,
        Border,
        showModalBottomSheet,
        showDialog,
        BoxShape,
        BoxShadow,
        Center,
        MainAxisAlignment,
        TextButton,
        AlertDialog,
        SnackBar,
        ScaffoldMessenger,
        BoxFit,
        Spacer,
        Image,
        FileImage,
        ImageProvider;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/widgets/moderation_dialogs.dart';
import 'package:oasis/features/feed/presentation/widgets/polls/poll_widgets.dart';
import 'package:oasis/widgets/spoiler_widget.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final Function(String optionId)? onVote;
  final bool isOwnPost;
  final bool showInteractionButtons;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onBookmark,
    this.onComment,
    this.onShare,
    this.onDelete,
    this.onVote,
    this.isOwnPost = false,
    this.showInteractionButtons = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;
  bool _isHovered = false;
  final GlobalKey _moreButtonKey = GlobalKey();
  final fluent.FlyoutController _flyoutController = fluent.FlyoutController();

  @override
  void initState() {
    super.initState();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50,
      ),
    ]).animate(_likeAnimationController);
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _flyoutController.dispose();
    super.dispose();
  }

  void _handleLike({bool forceLike = false}) {
    HapticFeedback.lightImpact();

    final wasLiked = widget.post.isLiked;

    if (forceLike && wasLiked) {
      // Already liked, just show animation
      _likeAnimationController.forward().then((_) {
        _likeAnimationController.reverse();
      });
      return;
    }

    if (wasLiked) {
      _likeAnimationController.reverse();
    } else {
      _likeAnimationController.forward().then((_) {
        _likeAnimationController.reverse();
      });
    }

    // Call onLike only if we are toggling OR if we want to ensure it's liked
    if (!forceLike || !wasLiked) {
      widget.onLike?.call();
    }
  }

  String _getAuthorsText() {
    final authors = [widget.post.username];
    final acceptedCollabs = widget.post.collaborators
        .where((c) => c['status'] == 'accepted')
        .map((c) => c['username'] as String? ?? 'User')
        .toList();
    authors.addAll(acceptedCollabs);

    if (authors.length == 1) return authors.first;
    if (authors.length == 2) return '${authors[0]} and ${authors[1]}';
    return '${authors[0]} and ${authors.length - 1} others';
  }

  void _showMoreOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final useFluent = context.read<ThemeProvider>().useFluentUI;

    if (useFluent && isDesktop) {
      _flyoutController.showFlyout(
        builder: (context) {
          return fluent.MenuFlyout(
            items: [
              if (widget.isOwnPost)
                fluent.MenuFlyoutItem(
                  onPressed: _confirmDelete,
                  leading: const Icon(fluent.FluentIcons.delete),
                  text: const Text('Delete Post'),
                )
              else
                fluent.MenuFlyoutItem(
                  onPressed: _showReportDialog,
                  leading: const Icon(fluent.FluentIcons.flag),
                  text: const Text('Report Post'),
                ),
              fluent.MenuFlyoutItem(
                onPressed: _copyPostLink,
                leading: const Icon(fluent.FluentIcons.link),
                text: const Text('Copy Link'),
              ),
              fluent.MenuFlyoutItem(
                onPressed: () {
                  // External sharing is disabled for intentionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'External sharing is disabled to protect your community privacy.',
                      ),
                    ),
                  );
                },
                leading: const Icon(fluent.FluentIcons.lock),
                text: const Text('Privacy Protected'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (isDesktop) {
      final RenderBox? button =
          _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (button == null) return;

      final RenderBox overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      );

      showMenu(
        context: context,
        position: position,
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1A1D24)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        items: [
          if (widget.isOwnPost)
            PopupMenuItem(
              onTap: _confirmDelete,
              child: _buildMenuRow(
                FluentIcons.delete_24_regular,
                'Delete Post',
                colorScheme.error,
              ),
            )
          else
            PopupMenuItem(
              onTap: _showReportDialog,
              child: _buildMenuRow(
                FluentIcons.flag_24_regular,
                'Report Post',
                colorScheme.error,
              ),
            ),
          PopupMenuItem(
            onTap: _copyPostLink,
            child: _buildMenuRow(
              FluentIcons.link_24_regular,
              'Copy Link',
              colorScheme.onSurface,
            ),
          ),
          PopupMenuItem(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'External sharing is disabled for your privacy.',
                  ),
                ),
              );
            },
            child: _buildMenuRow(
              FluentIcons.lock_shield_24_regular,
              'Privacy Protected',
              colorScheme.onSurface,
            ),
          ),
        ],
      );
      return;
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    context.showResponsiveSheet(
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: disableTransparency
                ? colorScheme.surface
                : colorScheme.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: disableTransparency
                ? _buildMoreMenuContent(context, colorScheme)
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: _buildMoreMenuContent(context, colorScheme),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuContent(BuildContext context, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (widget.isOwnPost) ...[
          _buildMoreTile(
            context,
            icon: FluentIcons.delete_24_regular,
            title: 'Delete Post',
            titleColor: colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete();
            },
          ),
        ] else ...[
          _buildMoreTile(
            context,
            icon: FluentIcons.flag_24_regular,
            title: 'Report Post',
            titleColor: colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              _showReportDialog();
            },
          ),
        ],
        _buildMoreTile(
          context,
          icon: FluentIcons.link_24_regular,
          title: 'Copy Link',
          onTap: () {
            Navigator.pop(context);
            _copyPostLink();
          },
        ),
        _buildMoreTile(
          context,
          icon: fluent.FluentIcons.lock,
          title: 'Privacy Protected',
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sharing is disabled to protect community privacy.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMenuRow(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }

  Widget _buildMoreTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: titleColor ?? colorScheme.onSurface, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    ReportDialog.show(
      context,
      postId: widget.post.id,
      userId: widget.post.userId,
    );
  }

  void _copyPostLink() {
    final postLink = AppConfig.getWebUrl('/post/${widget.post.id}');
    Clipboard.setData(
      ClipboardData(text: ClipboardData(text: postLink).text ?? ''),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildImageItem(String url, ColorScheme colorScheme) {
    if (url.isEmpty) {
      return Container(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: const Center(child: Icon(Icons.broken_image)),
      );
    }

    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: const Center(child: Icon(Icons.broken_image)),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      width: double.infinity,
      placeholder: (context, url) => Container(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: const Center(child: Icon(Icons.error_outline)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userSettings = Provider.of<UserSettingsProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final micaEnabled = userSettings.micaEnabled;

    // Explicitly disable transparency if Mica is off OR if forced by theme provider
    final disableTransparency =
        themeProvider.isM3ETransparencyDisabled || !micaEnabled;

    // Reduce radius on desktop or when Mica is off for a cleaner, more professional look
    final cardRadius = isM3E
        ? (isDesktop ? (micaEnabled ? 20.0 : 12.0) : 28.0)
        : (isDesktop ? 12.0 : 16.0);

    final currentUserId = AuthService().currentUser?.id;
    final isCirclePost = widget.post.circleId != null;

    bool showMembershipOverlay = false;
    final circleProvider = context.read<CircleProvider>();
    final activeCircle = circleProvider.activeCircle;

    // Check if we should show the membership overlay
    if (isCirclePost) {
      final isOwnPost =
          currentUserId != null && currentUserId == widget.post.userId;
      final isInActiveCircle =
          activeCircle != null && activeCircle.id == widget.post.circleId;

      // If it's not our own post and we aren't in the active circle context,
      // we check if we are a member of the post's circle.
      if (!isOwnPost && !isInActiveCircle) {
        final circle = circleProvider.circles.firstWhere(
          (c) => c.id == widget.post.circleId,
          orElse: () => CircleEntity(
            id: '',
            name: '',
            emoji: '',
            createdBy: '',
            createdAt: DateTime.now(),
            memberIds: [],
          ),
        );

        final isMember =
            currentUserId != null && circle.memberIds.contains(currentUserId);
        if (!isMember) {
          showMembershipOverlay = true;
        }
      }
    }

    final cardDecoration = BoxDecoration(
      gradient: (isM3E && !disableTransparency)
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainer.withValues(alpha: 0.8),
                colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
              ],
            )
          : null,
      color: isM3E
          ? (disableTransparency
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLow)
          : (disableTransparency
                ? colorScheme.surface
                : colorScheme.surface.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(cardRadius),
      border: isM3E
          ? Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: disableTransparency ? 0.8 : 0.5,
              ),
              width: 1,
            )
          : Border.all(
              color: Colors.white.withValues(
                alpha: disableTransparency ? 0.1 : 0.05,
              ),
            ),
      boxShadow: isM3E && disableTransparency
          ? [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );

    final useFluent = themeProvider.useFluentUI;

    final Widget cardContent = useFluent && isDesktop
        ? fluent.Card(
            padding: EdgeInsets.zero,
            backgroundColor: disableTransparency
                ? fluent.FluentTheme.of(context).cardColor
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.push('/profile/${widget.post.userId}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: widget.post.userAvatar.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.post.userAvatar,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Center(
                                      child: Text(
                                        widget.post.username[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/profile/${widget.post.userId}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post.username,
                                style: fluent.FluentTheme.of(
                                  context,
                                ).typography.bodyStrong,
                              ),
                              Text(
                                timeago.format(widget.post.timestamp),
                                style: fluent.FluentTheme.of(
                                  context,
                                ).typography.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                      fluent.FlyoutTarget(
                        controller: _flyoutController,
                        child: fluent.IconButton(
                          key: _moreButtonKey,
                          icon: const Icon(fluent.FluentIcons.more, size: 20),
                          onPressed: _showMoreOptions,
                        ),
                      ),
                    ],
                  ),
                ),

                // Post Image(s)
                if (widget.post.mediaUrls.isNotEmpty ||
                    (widget.post.imageUrl != null &&
                        widget.post.imageUrl!.isNotEmpty)) ...[
                  Builder(
                    builder: (context) {
                      final images = widget.post.mediaUrls.isNotEmpty
                          ? widget.post.mediaUrls
                          : (widget.post.imageUrl != null &&
                                    widget.post.imageUrl!.isNotEmpty
                                ? [widget.post.imageUrl!]
                                : <String>[]);

                      if (images.isEmpty) return const SizedBox.shrink();

                      return Column(
                        children: [
                          GestureDetector(
                            onLongPress: _showMoreOptions,
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 600),
                              child: images.length > 1
                                  ? AspectRatio(
                                      aspectRatio: 1.2,
                                      child: PageView.builder(
                                        itemCount: images.length,
                                        itemBuilder: (context, index) {
                                          return _buildImageItem(
                                            images[index],
                                            colorScheme,
                                          );
                                        },
                                      ),
                                    )
                                  : Hero(
                                      tag: 'post_${widget.post.id}',
                                      child: widget.post.isSpoiler
                                          ? SpoilerWidget(
                                              child: _buildImageItem(
                                                images.first,
                                                colorScheme,
                                              ),
                                            )
                                          : _buildImageItem(
                                              images.first,
                                              colorScheme,
                                            ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],

                // Caption
                if (widget.post.content != null &&
                    widget.post.content!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCaption(context, theme, colorScheme),
                        if (widget.post.hashtags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: widget.post.hashtags.map((tag) {
                              return GestureDetector(
                                onTap: () {
                                  // Navigate to hashtag search
                                },
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (widget.showInteractionButtons) ...[
                        ScaleTransition(
                          scale: _likeAnimation,
                          child: fluent.IconButton(
                            icon: Icon(
                              widget.post.isLiked
                                  ? fluent.FluentIcons.heart_fill
                                  : fluent.FluentIcons.heart,
                              color: widget.post.isLiked ? Colors.red : null,
                              size: 20,
                            ),
                            onPressed: _handleLike,
                          ),
                        ),
                        if (widget.post.likes > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${widget.post.likes}',
                            style: fluent.FluentTheme.of(
                              context,
                            ).typography.caption,
                          ),
                        ],
                        const SizedBox(width: 16),
                        fluent.IconButton(
                          icon: const Icon(
                            fluent.FluentIcons.comment,
                            size: 20,
                          ),
                          onPressed: widget.onComment,
                        ),
                        const SizedBox(width: 16),
                      ],
                      fluent.IconButton(
                        icon: const Icon(fluent.FluentIcons.share, size: 20),
                        onPressed: widget.onShare,
                      ),
                      const Spacer(),
                      fluent.IconButton(
                        icon: Icon(
                          widget.post.isBookmarked
                              ? fluent.FluentIcons.single_bookmark_solid
                              : fluent.FluentIcons.single_bookmark,
                          color: widget.post.isBookmarked
                              ? colorScheme.primary
                              : null,
                          size: 20,
                        ),
                        onPressed: widget.onBookmark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Container(
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 8 : 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.push('/profile/${widget.post.userId}'),
                        child: Container(
                          padding: EdgeInsets.all(isM3E ? 2 : 0),
                          decoration: BoxDecoration(
                            shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: isM3E
                                ? BorderRadius.circular(12)
                                : null,
                            border: isM3E
                                ? Border.all(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: isM3E
                                ? BorderRadius.circular(14)
                                : BorderRadius.circular(28),
                            child: SizedBox(
                              width: isDesktop ? 48 : 40,
                              height: isDesktop ? 48 : 40,
                              child: widget.post.userAvatar.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.post.userAvatar,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        child: Text(
                                          widget.post.username[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: isDesktop ? 16 : 14,
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/profile/${widget.post.userId}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _getAuthorsText(),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: isM3E
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                          letterSpacing: isM3E ? -0.5 : 0,
                                          fontSize: isDesktop ? 17 : null,
                                        ),
                                  ),
                                  if (widget.post.isVerified) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.verified,
                                      size: isDesktop ? 18 : 16,
                                      color: colorScheme.primary,
                                    ),
                                  ],
                                  if (!widget.isOwnPost &&
                                      widget.post.userId !=
                                          AuthService().currentUser?.id)
                                    Consumer<ProfileProvider>(
                                      builder:
                                          (context, profileProvider, child) {
                                            final isFollowing = profileProvider
                                                .following
                                                .any(
                                                  (p) =>
                                                      p.id ==
                                                      widget.post.userId,
                                                );
                                            if (isFollowing) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8.0,
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  final currentUserId =
                                                      AuthService()
                                                          .currentUser
                                                          ?.id;
                                                  if (currentUserId != null) {
                                                    profileProvider.followUser(
                                                      followerId: currentUserId,
                                                      followingId:
                                                          widget.post.userId,
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  'Follow',
                                                  style: theme
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: isDesktop
                                                            ? 15
                                                            : null,
                                                      ),
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                ],
                              ),
                              Text(
                                timeago.format(widget.post.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: isDesktop ? 13 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        key: _moreButtonKey,
                        icon: Icon(
                          FluentIcons.more_vertical_24_regular,
                          size: isDesktop ? 26 : 24,
                        ),
                        onPressed: _showMoreOptions,
                        visualDensity: VisualDensity.standard,
                      ),
                    ],
                  ),
                ),

                // Post Image(s)
                if (widget.post.mediaUrls.isNotEmpty ||
                    (widget.post.imageUrl != null &&
                        widget.post.imageUrl!.isNotEmpty)) ...[
                  Builder(
                    builder: (context) {
                      final images = widget.post.mediaUrls.isNotEmpty
                          ? widget.post.mediaUrls
                          : [widget.post.imageUrl!];

                      final mediaContent = Column(
                        children: [
                          GestureDetector(
                            onLongPress: _showMoreOptions,
                            child: Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxHeight: isDesktop
                                    ? 600
                                    : MediaQuery.of(context).size.height * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                              ),
                              child: images.length > 1
                                  ? AspectRatio(
                                      aspectRatio: isDesktop ? 1.2 : 4 / 5,
                                      child: PageView.builder(
                                        itemCount: images.length,
                                        itemBuilder: (context, index) {
                                          return _buildImageItem(
                                            images[index],
                                            colorScheme,
                                          );
                                        },
                                      ),
                                    )
                                  : Hero(
                                      tag: 'post_${widget.post.id}',
                                      child: _buildImageItem(
                                        images.first,
                                        colorScheme,
                                      ),
                                    ),
                            ),
                          ),
                          if (images.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (index) {
                                  return Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      );

                      if (widget.post.isSpoiler) {
                        return SpoilerWidget(child: mediaContent);
                      }
                      return mediaContent;
                    },
                  ),
                ],

                // Caption
                if (widget.post.content != null &&
                    widget.post.content!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      isDesktop ? 12 : 12,
                      16,
                      isDesktop ? 8 : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        widget.post.isSpoiler
                            ? SpoilerWidget(
                                child: _buildCaption(
                                  context,
                                  theme,
                                  colorScheme,
                                  isDesktop,
                                  isM3E,
                                ),
                              )
                            : _buildCaption(
                                context,
                                theme,
                                colorScheme,
                                isDesktop,
                                isM3E,
                              ),
                        if (widget.post.hashtags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: widget.post.hashtags.map((tag) {
                              return GestureDetector(
                                onTap: () {
                                  // Navigate to hashtag search
                                },
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Poll
                if (widget.post.poll != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: PollDisplay(
                      poll: widget.post.poll!,
                      onVote: (optionId) {
                        widget.onVote?.call(optionId);
                      },
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: isDesktop ? 4 : 8,
                    bottom: isDesktop ? 12 : 20,
                  ),
                  child: Row(
                    children: [
                      if (widget.showInteractionButtons) ...[
                        ScaleTransition(
                          scale: _likeAnimation,
                          child: IconButton(
                            key: const ValueKey('post_card_like_button'),
                            icon: Icon(
                              widget.post.isLiked
                                  ? FluentIcons.heart_24_filled
                                  : FluentIcons.heart_24_regular,
                              color: widget.post.isLiked
                                  ? (isM3E ? colorScheme.tertiary : Colors.red)
                                  : null,
                              size: isDesktop ? 28 : 32,
                            ),
                            onPressed: _handleLike,
                            padding: const EdgeInsets.all(8),
                            constraints: null,
                          ),
                        ),
                        if (widget.post.likes > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${widget.post.likes}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        IconButton(
                          key: const ValueKey('post_card_comment_button'),
                          icon: Icon(
                            FluentIcons.chat_24_regular,
                            size: isDesktop ? 26 : 28,
                          ),
                          onPressed: widget.onComment,
                          padding: const EdgeInsets.all(8),
                          constraints: null,
                        ),
                        const SizedBox(width: 12),
                      ],
                      IconButton(
                        key: const ValueKey('post_card_share_button'),
                        icon: Icon(
                          FluentIcons.share_24_regular,
                          size: isDesktop ? 26 : 28,
                        ),
                        onPressed: widget.onShare,
                        padding: const EdgeInsets.all(8),
                        constraints: null,
                      ),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('post_card_bookmark_button'),
                        icon: Icon(
                          widget.post.isBookmarked
                              ? FluentIcons.bookmark_24_filled
                              : FluentIcons.bookmark_24_regular,
                          color: widget.post.isBookmarked
                              ? colorScheme.primary
                              : null,
                          size: isDesktop ? 26 : 28,
                        ),
                        onPressed: widget.onBookmark,
                        padding: const EdgeInsets.all(8),
                        constraints: null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              details.globalPosition.dx,
              details.globalPosition.dy,
            ),
            items: [
              const PopupMenuItem(
                value: 'share',
                child: Row(children: [Icon(FluentIcons.share_24_regular, size: 20), SizedBox(width: 8), Text('Share')]),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(children: [Icon(FluentIcons.flag_24_regular, size: 20), SizedBox(width: 8), Text('Report')]),
              ),
            ],
          ).then((value) {
            if (value == 'share' && widget.onShare != null) widget.onShare!();
          });
        },
        child: AnimatedScale(
        scale: isDesktop && _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: isDesktop ? 12 : 16,
            left: isDesktop ? 8 : 16,
            right: isDesktop ? 8 : 16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: Stack(
              children: [
                disableTransparency
                    ? cardContent
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: cardContent,
                      ),
                if (showMembershipOverlay)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(cardRadius),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  FluentIcons.lock_shield_24_filled,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Private Circle Post',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Text(
                                    'You cannot view this post. You are not a Circle Member.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaption(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme, [
    bool isDesktop = true,
    bool isM3E = false,
  ]) {
    final String content = (widget.post.content ?? '');

    final RegExp spoilerRegExp = RegExp(r'\|\|(.*?)\|\|');

    final baseStyle = isDesktop
        ? theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4)
        : theme.textTheme.bodyMedium;

    final usernameStyle = TextStyle(
      fontWeight: isM3E ? FontWeight.w900 : FontWeight.w600,
      letterSpacing: isM3E ? -0.2 : 0,
    );

    final List<Widget> wrapChildren = [];
    wrapChildren.add(
      Text('${widget.post.username} ', style: baseStyle?.merge(usernameStyle)),
    );

    int lastMatchEnd = 0;
    final Iterable<RegExpMatch> contentMatches = spoilerRegExp.allMatches(
      content,
    );

    for (final match in contentMatches) {
      if (match.start > lastMatchEnd) {
        wrapChildren.add(
          Text(content.substring(lastMatchEnd, match.start), style: baseStyle),
        );
      }

      wrapChildren.add(
        SpoilerWidget(child: Text(match.group(1) ?? '', style: baseStyle)),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      wrapChildren.add(Text(content.substring(lastMatchEnd), style: baseStyle));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: wrapChildren,
    );
  }
}

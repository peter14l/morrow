import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';
import 'package:oasis/features/stories/presentation/widgets/story_viewers_sheet.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import 'package:oasis/widgets/moderation_dialogs.dart';

class StoryViewScreen extends StatefulWidget {
  final String initialStoryId;
  final List<StoryEntity> stories;

  const StoryViewScreen({
    super.key,
    required this.initialStoryId,
    required this.stories,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _replyController = TextEditingController();

  int _currentIndex = 0;
  bool _isPaused = false;
  bool _isReplying = false;

  AuthService get _authService => context.read<AuthService>();
  StoriesProvider get _storiesProvider => context.read<StoriesProvider>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.stories.indexWhere(
      (s) => s.id == widget.initialStoryId,
    );
    if (_currentIndex == -1) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);

    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.stories[_currentIndex].duration),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _startStory();
    _markAsViewed();
  }

  void _markAsViewed() {
    final story = widget.stories[_currentIndex];
    if (!story.hasViewed) {
      _storiesProvider.viewStory(story.id);
    }
  }

  void _startStory() {
    _animController.reset();
    final story = widget.stories[_currentIndex];
    _animController.duration = Duration(seconds: story.duration);
    _animController.forward();

    // Play music if present
    if (story.hasMusic) {
      _playMusic(story.musicMetadata!.previewUrl);
    } else {
      _stopMusic();
    }
  }

  Future<void> _playMusic(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Error playing story music: $e');
    }
  }

  Future<void> _stopMusic() async {
    await _audioPlayer.stop();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.jumpToPage(_currentIndex);
      _startStory();
      _markAsViewed();
    } else {
      context.pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.jumpToPage(_currentIndex);
      _startStory();
      _markAsViewed();
    } else {
      _startStory();
    }
  }

  void _pauseStory() {
    if (_isPaused) return;
    setState(() {
      _isPaused = true;
    });
    _animController.stop();
    _audioPlayer.pause();
  }

  void _resumeStory() {
    if (!_isPaused || _isReplying) return;
    setState(() {
      _isPaused = false;
    });
    _animController.forward();
    _audioPlayer.resume();
  }

  Future<void> _sendReply(String text) async {
    if (text.trim().isEmpty) return;

    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return;

    setState(() {
      _isReplying = false;
      _isPaused = false;
    });

    _replyController.clear();
    FocusScope.of(context).unfocus();
    _resumeStory();

    try {
      // Use the new ChatProvider for messaging
      // This is a placeholder for actual messaging integration in new arch
      // For now, we'll keep it simple or use a dedicated service if available
      // await context.read<ChatProvider>().sendStoryReply(story, text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      HapticUtils.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
      }
    }
  }

  void _showViewers() {
    _pauseStory();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StoryViewersSheet(storyId: widget.stories[_currentIndex].id),
    ).then((_) => _resumeStory());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _replyController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final isOwner = _authService.currentUser?.id == story.userId;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story Content
          GestureDetector(
            onTapDown: (details) => _pauseStory(),
            onTapUp: (details) {
              if (_isReplying) return;
              _resumeStory();
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 3) {
                _previousStory();
              } else {
                _nextStory();
              }
            },
            onLongPressStart: (_) => _pauseStory(),
            onLongPressEnd: (_) => _resumeStory(),
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 500) {
                context.pop();
              } else if (details.primaryVelocity! < -500 && isOwner) {
                _showViewers();
              }
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                return _buildStoryContent(widget.stories[index]);
              },
            ),
          ),

          // Interactive Stickers Layer
          if (story.interactiveMetadata != null && !_isReplying)
            ...story.interactiveMetadata!.map(
              (sticker) => _buildSticker(sticker),
            ),

          // Top Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Progress Bars
          Positioned(
            top: 60,
            left: 12,
            right: 12,
            child: Row(
              children: widget.stories.asMap().entries.map((entry) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: _buildProgressBar(entry.key, isM3E),
                  ),
                );
              }).toList(),
            ),
          ),

          // User Info & Close
          Positioned(
            top: 75,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isM3E ? BorderRadius.circular(12) : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: CachedNetworkImageProvider(
                      story.userAvatar ?? '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.username ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isM3E ? FontWeight.w800 : FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: isM3E ? -0.5 : null,
                        ),
                      ),
                      Text(
                        _getTimeAgo(story.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                  onPressed: () {
                    _showOptionsSheet(story, isOwner);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: isOwner
                ? _buildOwnerControls(story)
                : _buildViewerControls(isM3E),
          ),

          // Story Caption
          if (story.caption != null &&
              story.caption!.isNotEmpty &&
              !_isReplying)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 80,
              left: 32,
              right: 32,
              child: Text(
                story.caption!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: isM3E ? FontWeight.bold : null,
                  shadows: const [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoryContent(StoryEntity story) {
    return CachedNetworkImage(
      imageUrl: story.mediaUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      errorWidget: (context, url, error) =>
          const Center(child: Icon(Icons.error, color: Colors.white54)),
    );
  }

  Widget _buildSticker(StoryStickerEntity sticker) {
    return Positioned(
      left: sticker.x * MediaQuery.of(context).size.width,
      top: sticker.y * MediaQuery.of(context).size.height,
      child: Transform.rotate(
        angle: sticker.rotation,
        child: Transform.scale(
          scale: sticker.scale,
          child: _getStickerWidget(sticker),
        ),
      ),
    );
  }

  Widget _getStickerWidget(StoryStickerEntity sticker) {
    switch (sticker.type) {
      case 'text':
        return Text(
          sticker.data['text'] ?? '',
          style: TextStyle(
            color: Color(int.parse(sticker.data['color'] ?? '0xFFFFFFFF')),
            fontSize: (sticker.data['fontSize'] ?? 20).toDouble(),
            fontWeight: FontWeight.bold,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressBar(int index, bool isM3E) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isM3E ? 4 : 2),
      child: Container(
        height: isM3E ? 4 : 3,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3)),
        child: index < _currentIndex
            ? const Divider(color: Colors.white, thickness: 4, height: 4)
            : index == _currentIndex
            ? AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _animController.value,
                    child: Divider(
                      color: Colors.white,
                      thickness: isM3E ? 4 : 3,
                      height: isM3E ? 4 : 3,
                    ),
                  );
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildOwnerControls(StoryEntity story) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _showViewers,
          child: Column(
            children: [
              const Icon(Icons.keyboard_arrow_up, color: Colors.white),
              Text(
                'Activity',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${story.viewCount}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewerControls(bool isM3E) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: isM3E ? 56 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isM3E ? 28 : 24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              color: isM3E ? Colors.white.withValues(alpha: 0.1) : null,
            ),
            child: TextField(
              controller: _replyController,
              onTap: () {
                _pauseStory();
                setState(() => _isReplying = true);
              },
              onSubmitted: _sendReply,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Send message...',
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isM3E ? 14 : 10,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(
            Icons.favorite_border,
            color: Colors.white,
            size: isM3E ? 32 : 28,
          ),
          onPressed: () {
            _storiesProvider.reactToStory(
              widget.stories[_currentIndex].id,
              '❤️',
            );
            HapticUtils.lightImpact();
          },
        ),
        IconButton(
          icon: Icon(
            Icons.send_outlined,
            color: Colors.white,
            size: isM3E ? 32 : 28,
          ),
          onPressed: () {
            // Share story
          },
        ),
      ],
    );
  }

  void _showOptionsSheet(StoryEntity story, bool isOwner) {
    _pauseStory();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Story',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final success = await _storiesProvider.deleteStory(story.id);
                  if (success && mounted) {
                    Navigator.pop(context);
                    context.pop();
                  }
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.report_problem_outlined),
                title: const Text('Report Story'),
                onTap: () {
                  Navigator.pop(context);
                  ReportDialog.show(
                    context,
                    postId: story
                        .id, // Stories are treated like posts in moderation
                    userId: story.userId,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Save Media'),
              onTap: () {
                Navigator.pop(context);
                // Implement saving
              },
            ),
          ],
        ),
      ),
    ).then((_) => _resumeStory());
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Just now';
  }
}

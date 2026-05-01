import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/features/ripples/domain/models/ripple_entity.dart'
    show RipplesLayoutType;
import 'package:oasis/core/network/supabase_client.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/widgets/messages/share_to_dm_modal.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/app_initializer.dart'; // For ThemeProvider
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart' as motion;
import 'package:oasis/widgets/wellbeing/grayscale_detox.dart';

class RipplesScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final String? initialRippleId;

  const RipplesScreen({super.key, this.onExit, this.initialRippleId});

  @override
  State<RipplesScreen> createState() => _RipplesScreenState();
}

class _RipplesScreenState extends State<RipplesScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  StreamSubscription? _sessionSub;
  int _currentIndex = 0;
  DateTime? _sessionStartTime;
  final ValueNotifier<double> _rippleProgress = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStartTime = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DigitalWellbeingService>().startTracking('ripples');
      final service = context.read<RipplesProvider>();
      service.refreshRipples().then((_) {
        if (widget.initialRippleId != null) {
          final index = service.ripples.indexWhere(
            (r) => r['id'] == widget.initialRippleId,
          );
          if (index >= 0) {
            setState(() {
              _currentIndex = index;
              _pageController.jumpToPage(index);
            });
          }
        }
      });
    });

    final ripplesService = context.read<RipplesProvider>();
    _sessionSub = ripplesService.onSessionEnd.listen((_) {
      if (mounted) {
        if (widget.onExit != null) {
          widget.onExit!();
        } else {
          context.go('/feed');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your Ripples session has ended. Time to reconnect!'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    context.read<DigitalWellbeingService>().stopTracking();
    _sessionSub?.cancel();
    _pageController.dispose();
    _rippleProgress.dispose();
    super.dispose();
  }

  void _handleExit() {
    context.read<DigitalWellbeingService>().stopTracking();
    if (_sessionStartTime != null) {
      final elapsed = DateTime.now().difference(_sessionStartTime!);
      final service = context.read<RipplesProvider>();
      if (service.remainingDuration != null) {
        final newRemaining = service.remainingDuration! - elapsed;
        if (newRemaining.isNegative) {
          service.endSession();
        } else {
          service.pauseSession(newRemaining);
        }
      }
    }

    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final ripplesService = context.watch<RipplesProvider>();
    final ripples = ripplesService.ripples;

    if (ripplesService.isLoading && ripples.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    if (ripples.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No ripples yet.',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
              const SizedBox(height: 16),
              _buildGlassCircleButton(
                icon: Icons.close,
                onTap: _handleExit,
                isM3E: isM3E,
                disableTransparency: disableTransparency,
              ),
            ],
          ),
        ),
      );
    }

    final currentRipple = ripples[_currentIndex];

    return GrayscaleDetox(
      child: LayoutBuilder(
        builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1000;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // Time tracking info
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildTimeInfoBanner(context),
                ),
                // Immersive Blurred Background
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child:
                        Image.network(
                              currentRipple['thumbnail_url'] ?? '',
                              key: ValueKey('bg_${currentRipple['id']}'),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.black),
                            )
                            .animate(
                              key: ValueKey('anim_bg_${currentRipple['id']}'),
                            )
                            .scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.2, 1.2),
                              duration: 20.seconds,
                              curve: Curves.linear,
                            )
                            .move(
                              begin: const Offset(-20, -20),
                              end: const Offset(20, 20),
                              duration: 20.seconds,
                              curve: Curves.linear,
                            ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),

                // Desktop Layout
                Row(
                  children: [
                    // Left: Navigation Queue
                    Container(
                      width: 300,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGlassCircleButton(
                            icon: Icons.arrow_back,
                            onTap: _handleExit,
                            isM3E: isM3E,
                            disableTransparency: disableTransparency,
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Coming Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.separated(
                              itemCount: ripples.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final ripple = ripples[index];
                                final isCurrent = index == _currentIndex;
                                return _ComingUpItem(
                                  ripple: ripple,
                                  isCurrent: isCurrent,
                                  isM3E: isM3E,
                                  onTap: () {
                                    setState(() {
                                      _currentIndex = index;
                                      _pageController.jumpToPage(index);
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Center: Video Player
                    Expanded(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 500),
                          margin: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              isM3E ? 48 : 24,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isM3E ? 48 : 24,
                            ),
                            child: _buildActiveLayout(
                              ripplesService.currentLayout,
                              ripples,
                              isM3E,
                              Theme.of(context).colorScheme,
                              disableTransparency,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right: Info & Comments
                    Container(
                      width: 400,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage:
                                    currentRipple['profiles']['avatar_url'] !=
                                        null
                                    ? NetworkImage(
                                        currentRipple['profiles']['avatar_url'],
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentRipple['profiles']?['username'] ??
                                          'User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              _buildGlassCircleButton(
                                icon: FluentIcons.grid_24_regular,
                                onTap: () => _showLayoutSwitcher(
                                  context,
                                  ripplesService,
                                  isM3E,
                                  disableTransparency,
                                ),
                                isM3E: isM3E,
                                disableTransparency: disableTransparency,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            currentRipple['caption'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildDesktopAction(
                                icon: currentRipple['is_liked']
                                    ? FluentIcons.heart_24_filled
                                    : FluentIcons.heart_24_regular,
                                label: '${currentRipple['likes_count']}',
                                color: currentRipple['is_liked']
                                    ? Colors.redAccent
                                    : Colors.white,
                                onTap: () => _toggleLikeInBuild(currentRipple),
                              ),
                              _buildDesktopAction(
                                icon: FluentIcons.comment_24_regular,
                                label: '${currentRipple['comments_count']}',
                                onTap: () => _showMobileComments(
                                  context,
                                  currentRipple['id'],
                                  isM3E,
                                  disableTransparency,
                                ),
                              ),
                              _buildDesktopAction(
                                icon: currentRipple['is_saved']
                                    ? FluentIcons.bookmark_24_filled
                                    : FluentIcons.bookmark_24_regular,
                                label: 'Save',
                                color: currentRipple['is_saved']
                                    ? Colors.blueAccent
                                    : Colors.white,
                                onTap: () => _toggleSaveInBuild(currentRipple),
                              ),
                              _buildDesktopAction(
                                icon: FluentIcons.send_24_regular,
                                label: 'Send',
                                onTap: () => _shareToDM(currentRipple),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 16),
                          const Text(
                            'Comments',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: RippleCommentsList(
                              rippleId: currentRipple['id'],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Mobile Layout
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              _buildActiveLayout(
                ripplesService.currentLayout,
                ripples,
                isM3E,
                Theme.of(context).colorScheme,
                disableTransparency,
              ),
              // Bottom Pill for Mobile (removed top buttons - no layout switcher or close at top)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 16,
                right: 16,
                child: motion.Animate(
                  effects: [
                    motion.FadeEffect(duration: 400.ms),
                    const motion.MoveEffect(
                      begin: Offset(0, 20),
                      curve: Curves.easeOutQuad,
                    ),
                  ],
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isM3E ? 24 : 32),
                    child: disableTransparency
                        ? Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(
                                isM3E ? 24 : 32,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                _buildMobileBottomPillContent(currentRipple),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildPillProgressBar(),
                                ),
                              ],
                            ),
                          )
                        : BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  isM3E ? 24 : 32,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 40,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  _buildMobileBottomPillContent(currentRipple),
                                  Positioned(
                                    top: 0,
                                    left: 20,
                                    right: 20,
                                    child: _buildPillProgressBar(),
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
        );
      },
    ),
    );
  }

  Widget _buildTimeInfoBanner(BuildContext context) {
    final wellbeing = context.watch<DigitalWellbeingService>();
    final threshold = wellbeing.lockoutThresholdMinutes;
    final usedMinutes = wellbeing.feedMinutes + wellbeing.ripplesMinutes;
    final remaining = threshold - usedMinutes > 0 ? threshold - usedMinutes : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            'Ripples time: ${wellbeing.ripplesMinutes}m / ${wellbeing.lockoutThresholdMinutes}m (Feed + Ripples)',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildPillProgressBar() {
    return ValueListenableBuilder<double>(
      valueListenable: _rippleProgress,
      builder: (context, progress, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
            minHeight: 2,
          ),
        );
      },
    );
  }

  Widget _buildMobileBottomPillContent(dynamic currentRipple) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Creator Info Section
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueAccent,
                        Colors.purpleAccent.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black,
                    backgroundImage:
                        currentRipple['profiles']?['avatar_url'] != null
                        ? NetworkImage(currentRipple['profiles']['avatar_url'])
                        : null,
                    child: currentRipple['profiles']?['avatar_url'] == null
                        ? Text(
                            (currentRipple['profiles']?['username']
                                        as String? ??
                                    'U')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentRipple['profiles']?['username'] ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions Section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMobileAction(
                icon: currentRipple['is_liked'] == true
                    ? FluentIcons.heart_24_filled
                    : FluentIcons.heart_24_regular,
                color: currentRipple['is_liked'] == true
                    ? Colors.redAccent
                    : Colors.white,
                onTap: () => _toggleLikeInBuild(currentRipple),
              ),
              _buildMobileAction(
                icon: FluentIcons.comment_24_regular,
                color: Colors.white,
                onTap: () => _showMobileComments(
                  context,
                  currentRipple['id'],
                  false,
                  false,
                ), // Actual values will come from context
              ),
              _buildMobileAction(
                icon: currentRipple['is_saved'] == true
                    ? FluentIcons.bookmark_24_filled
                    : FluentIcons.bookmark_24_regular,
                color: currentRipple['is_saved'] == true
                    ? Colors.blueAccent
                    : Colors.white,
                onTap: () => _toggleSaveInBuild(currentRipple),
              ),
              _buildMobileAction(
                icon: FluentIcons.send_24_regular,
                color: Colors.white,
                onTap: () => _shareToDM(currentRipple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 28)
            .animate(key: ValueKey('icon_$icon'))
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 300.ms,
              curve: Curves.elasticOut,
            ),
      ),
    );
  }

  void _showMobileComments(
    BuildContext context,
    String rippleId,
    bool isM3E,
    bool disableTransparency,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isM3E ? 48 : 32),
          ),
        ),
        child: Column(
          children: [
            const Text(
              'Comments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Expanded(child: RippleCommentsList(rippleId: rippleId)),
          ],
        ),
      ),
    );
  }

  void _showLayoutSwitcher(
    BuildContext context,
    RipplesProvider service,
    bool isM3E,
    bool disableTransparency,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isM3E ? 48 : 32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Layout Style',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLayoutOption(
                  context,
                  service,
                  RipplesLayoutType.kineticCardStack,
                  'Kinetic',
                  Icons.view_carousel,
                  isM3E,
                ),
                _buildLayoutOption(
                  context,
                  service,
                  RipplesLayoutType.choiceMosaic,
                  'Mosaic',
                  Icons.grid_view_rounded,
                  isM3E,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutOption(
    BuildContext context,
    RipplesProvider service,
    RipplesLayoutType type,
    String label,
    IconData icon,
    bool isM3E,
  ) {
    final isSelected = service.currentLayout == type;
    return GestureDetector(
      onTap: () {
        service.setLayoutPreference(type);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(isM3E ? 24 : 100),
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isM3E = false,
    bool disableTransparency = false,
  }) {
    final radius = isM3E ? 16.0 : 30.0;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: disableTransparency
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (icon == FluentIcons.dismiss_24_filled ||
                          icon == Icons.arrow_back)
                        _buildWellbeingCircularTimer(),
                      Icon(icon, color: Colors.white, size: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWellbeingCircularTimer() {
    final service = context.watch<DigitalWellbeingService>();

    final thresholdMs = service.lockoutThresholdMinutes * 60 * 1000.0;
    final remainingMs = (thresholdMs - (service.totalSeconds * 1000.0)).clamp(
      0.0,
      thresholdMs,
    );
    final progress = (remainingMs / thresholdMs).clamp(0.0, 1.0);

    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 2,
        backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation<Color>(
          progress < 0.2 ? Colors.redAccent : Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildActiveLayout(
    RipplesLayoutType layout,
    List<dynamic> ripples,
    bool isM3E,
    ColorScheme colorScheme,
    bool disableTransparency,
  ) {
    switch (layout) {
      case RipplesLayoutType.kineticCardStack:
        return _buildKineticCardStack(
          ripples,
          isM3E,
          colorScheme,
          disableTransparency,
        );
      case RipplesLayoutType.choiceMosaic:
        return _buildChoiceMosaic(ripples, isM3E);
    }
  }

  Widget _buildKineticCardStack(
    List<dynamic> ripples,
    bool isM3E,
    ColorScheme colorScheme,
    bool disableTransparency,
  ) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: ripples.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double value = 0;
            if (_pageController.position.haveDimensions) {
              value = _pageController.page! - index;
            }
            final scale = 1.0 - (value.abs() * 0.2).clamp(0.0, 1.0);

            final videoPlayer = RepaintBoundary(
              child: RippleVideoPlayer(
                rippleId: ripples[index]['id'],
                videoUrl: ripples[index]['video_url'],
                isPlaying: _currentIndex == index,
                progressNotifier: _currentIndex == index ? _rippleProgress : null,
              ),
            );

            final rotation = value * 0.1; // Subtle rotation
            final opacity = 1.0 - value.abs().clamp(0.0, 0.5);

            if (!isM3E) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..scale(scale, scale, 1.0)
                  ..rotateX(rotation),
                alignment: Alignment.center,
                child: Opacity(opacity: opacity, child: videoPlayer),
              );
            }

            // M3E Enclosed Card Style
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..scale(scale, scale, 1.0)
                ..rotateX(rotation),
              alignment: Alignment.center,
              child: Opacity(
                opacity: opacity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    60,
                    12,
                    140,
                  ), // Adjusted padding to make card bigger while keeping space for bottom pill
                  child: Container(
                    decoration: BoxDecoration(
                      color: disableTransparency
                          ? colorScheme.surfaceContainerHigh
                          : colorScheme.surfaceContainerLow.withValues(
                              alpha: 0.8,
                            ),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 40,
                          offset: Offset(0, 20 * (1 - value.abs())),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: videoPlayer,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChoiceMosaic(List<dynamic> ripples, bool isM3E) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 9 / 16,
      ),
      itemCount: ripples.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentIndex = index;
              _pageController.jumpToPage(index);
            });
            context.read<RipplesProvider>().setLayoutPreference(
              RipplesLayoutType.kineticCardStack,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isM3E ? 24 : 16),
            child: Image.network(
              ripples[index]['thumbnail_url'] ?? '',
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopAction({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 28),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  void _toggleLikeInBuild(Map<String, dynamic> ripple) {
    final service = context.read<RipplesProvider>();
    if (ripple['is_liked'] == true) {
      service.unlikeRipple(ripple['id']);
    } else {
      service.likeRipple(ripple['id']);
    }
  }

  void _toggleSaveInBuild(Map<String, dynamic> ripple) {
    final service = context.read<RipplesProvider>();
    if (ripple['is_saved'] == true) {
      service.unsaveRipple(ripple['id']);
    } else {
      service.saveRipple(ripple['id']);
    }
  }

  void _shareToDM(Map<String, dynamic> ripple) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareToDirectMessageModal(
        title: 'Share Ripple',
        content: ripple['caption'] ?? 'Shared a ripple',
        messageType: MessageType.ripple,
        rippleId: ripple['id'],
        mediaUrl: ripple['thumbnail_url'],
        shareData: {
          'username': ripple['profiles']['username'],
          'user_avatar': ripple['profiles']['avatar_url'],
          'caption': ripple['caption'],
          'video_url': ripple['video_url'],
          'thumbnail_url': ripple['thumbnail_url'],
        },
      ),
    );
  }
}

class RippleVideoPlayer extends StatefulWidget {
  final String rippleId;
  final String videoUrl;
  final bool isPlaying;
  final ValueNotifier<double>? progressNotifier;

  const RippleVideoPlayer({
    super.key,
    required this.rippleId,
    required this.videoUrl,
    required this.isPlaying,
    this.progressNotifier,
  });

  @override
  State<RippleVideoPlayer> createState() => _RippleVideoPlayerState();
}

class _RippleVideoPlayerState extends State<RippleVideoPlayer>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        if (widget.isPlaying) _controller.play();
      })
      ..setLooping(true)
      ..addListener(_handleProgress);
  }

  void _handleProgress() {
    if (widget.isPlaying &&
        widget.progressNotifier != null &&
        _controller.value.isInitialized) {
      final progress =
          _controller.value.position.inMilliseconds /
          _controller.value.duration.inMilliseconds;
      widget.progressNotifier!.value = progress.clamp(0.0, 1.0);
    }
  }

  @override
  void didUpdateWidget(RippleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isPlaying) {
        _controller.play();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

class RippleCommentsList extends StatefulWidget {
  final String rippleId;
  const RippleCommentsList({super.key, required this.rippleId});

  @override
  State<RippleCommentsList> createState() => _RippleCommentsListState();
}

class _RippleCommentsListState extends State<RippleCommentsList> {
  List<dynamic> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RippleCommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rippleId != widget.rippleId) {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final response = await context.read<RipplesProvider>().getComments(
        widget.rippleId,
      );

      if (mounted) {
        setState(() {
          _comments = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty || _isPosting) return;

    setState(() => _isPosting = true);

    try {
      await context.read<RipplesProvider>().commentOnRipple(
        widget.rippleId,
        _commentController.text.trim(),
      );

      _commentController.clear();
      await _loadComments();
    } catch (e) {
      debugPrint('Error posting comment: $e');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Theme.of(context).platform == TargetPlatform.iOS ||
                     Theme.of(context).platform == TargetPlatform.android;
    
    return Column(
      children: [
        // Comments list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _comments.isEmpty
              ? const Center(
                  child: Text(
                    'No comments yet',
                    style: TextStyle(color: Colors.white24),
                  ),
                )
              : ListView.separated(
                  itemCount: _comments.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage:
                              comment['profiles']?['avatar_url'] != null
                              ? NetworkImage(comment['profiles']['avatar_url'])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment['profiles']?['username'] ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comment['content'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // Comment input field
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
          decoration: BoxDecoration(
            color: isMobile ? Theme.of(context).colorScheme.surface : Colors.white.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: isMobile 
                    ? InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        isDense: true,
                      )
                    : InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                    : const Icon(
                        FluentIcons.send_24_regular,
                        color: Colors.white70,
                      ),
                onPressed: _isPosting ? null : _postComment,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComingUpItem extends StatefulWidget {
  final Map<String, dynamic> ripple;
  final bool isCurrent;
  final bool isM3E;
  final VoidCallback onTap;

  const _ComingUpItem({
    required this.ripple,
    required this.isCurrent,
    required this.isM3E,
    required this.onTap,
  });

  @override
  State<_ComingUpItem> createState() => _ComingUpItemState();
}

class _ComingUpItemState extends State<_ComingUpItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isCurrent || _isHovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.isM3E ? 16 : 12),
            border: Border.all(
              color: widget.isCurrent
                  ? Colors.white.withValues(alpha: 0.3)
                  : _isHovered
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.isM3E ? 12 : 8),
                child:
                    Image.network(
                          widget.ripple['thumbnail_url'] ?? '',
                          width: 60,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                        .animate(target: _isHovered ? 1 : 0)
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.1, 1.1),
                          duration: 200.ms,
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ripple['profiles']?['username'] ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.ripple['caption'] ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


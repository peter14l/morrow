import 'package:oasis/core/config/app_config.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/models/pulse_node_position.dart';
import 'package:oasis/models/feed_layout_strategy.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/services/energy_meter_service.dart';
import 'package:oasis/core/utils/map_positioner.dart';
import 'package:oasis/widgets/pulse_node_widget.dart';
import 'package:oasis/features/wellness/presentation/widgets/energy_meter_widget.dart';
import 'package:oasis/features/feed/presentation/widgets/feed_layout_switcher.dart';
import 'package:oasis/painters/pulse_background_painter.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/widgets/comments_modal.dart';
import 'package:share_plus/share_plus.dart';

/// Pulse Map feed screen - spatial exploration of posts
class PulseFeedScreen extends StatefulWidget {
  final ValueChanged<FeedLayoutType>? onLayoutChanged;

  const PulseFeedScreen({super.key, this.onLayoutChanged});

  @override
  State<PulseFeedScreen> createState() => _PulseFeedScreenState();
}

class _PulseFeedScreenState extends State<PulseFeedScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _backgroundController;

  Offset _cameraOffset = Offset.zero;
  double _scale = 1.0;
  Offset _gyroscopeOffset = Offset.zero;

  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Map<String, PulseNodePosition> _nodePositions = {};

  bool _showSnapBack = false;
  Post? _expandedPost;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGyroscope();
    _transformationController.addListener(_onTransformChanged);

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _gyroscopeSubscription?.pause();
      _backgroundController.stop();
      debugPrint('PulseFeed: Gyroscope and animation paused (background)');
    } else if (state == AppLifecycleState.resumed) {
      _gyroscopeSubscription?.resume();
      _backgroundController.repeat();
      debugPrint('PulseFeed: Gyroscope and animation resumed');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gyroscopeSubscription?.cancel();
    _transformationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _initializeGyroscope() {
    // Throttle gyroscope updates to 30 FPS
    _gyroscopeSubscription =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 33),
        ).listen((GyroscopeEvent event) {
          if (mounted) {
            setState(() {
              // Convert gyroscope rotation to parallax offset
              _gyroscopeOffset = Offset(
                (_gyroscopeOffset.dx + event.y * 0.5).clamp(-20.0, 20.0),
                (_gyroscopeOffset.dy + event.x * 0.5).clamp(-20.0, 20.0),
              );
            });
          }
        });
  }

  void _onTransformChanged() {
    final matrix = _transformationController.value;
    setState(() {
      _scale = matrix.getMaxScaleOnAxis();
      _cameraOffset = Offset(
        matrix.getTranslation().x,
        matrix.getTranslation().y,
      );

      // Show snap-back button if camera is far from center
      final distanceFromCenter = sqrt(
        _cameraOffset.dx * _cameraOffset.dx +
            _cameraOffset.dy * _cameraOffset.dy,
      );
      _showSnapBack = distanceFromCenter > 200;
    });
  }

  void _snapBackToCenter() {
    // Animate back to center with smooth transition
    _transformationController.value = Matrix4.identity();
  }

  void _generateNodePositions(List<Post> posts) {
    if (_nodePositions.isEmpty || _nodePositions.length != posts.length) {
      _nodePositions = {};
      for (int i = 0; i < posts.length; i++) {
        _nodePositions[posts[i].id] =
            PulseNodePosition.generateClusteredPosition(
              index: i,
              postTimestamp: posts[i].timestamp,
              clusterSize: 8,
              clusterRadius: 120.0,
              clusterSpacing: 250.0,
            );
      }
    }
  }

  Future<void> _onNodeTap(Post post) async {
    final energyService = context.read<EnergyMeterService>();
    final canExpand = await energyService.deductEnergy(InteractionType.expand);

    if (canExpand) {
      setState(() {
        _expandedPost = post;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough energy to expand post'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _closeExpandedPost() {
    setState(() {
      _expandedPost = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pulse Map'),
        actions: [
          FeedLayoutSwitcher(
            currentLayout: FeedLayoutType.pulseMap,
            onLayoutChanged: widget.onLayoutChanged ?? (layout) {},
          ),
        ],
      ),
      body: Consumer<FeedProvider>(
        builder: (context, feedProvider, _) {
          final posts = feedProvider.posts;
          _generateNodePositions(posts);

          if (posts.isEmpty && feedProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Prepare node positions for connections
          final connectionNodes = _nodePositions.values
              .map(
                (pos) =>
                    pos.toCartesian() +
                    Offset(size.width * 2.5, size.height * 2.5),
              )
              .toList();

          return EnergyMeterWidget(
            showLabel: true,
            child: Stack(
              children: [
                // Main Pulse Map
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.3,
                  maxScale: 4.0,
                  boundaryMargin: EdgeInsets.all(size.width * 2),
                  constrained: false,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: SizedBox(
                    width: size.width * 5,
                    height: size.height * 5,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background with grid and stars
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _backgroundController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: PulseBackgroundPainter(
                                  gridColor: theme.colorScheme.primary,
                                  starColor: theme.colorScheme.onSurface,
                                  nodePositions: connectionNodes,
                                  animationValue: _backgroundController.value,
                                ),
                              );
                            },
                          ),
                        ),

                        // User node (center)
                        Positioned(
                          left: size.width * 2.5 - 50,
                          top: size.height * 2.5 - 50,
                          child: _buildUserNode(),
                        ),

                        // Post nodes
                        ...posts.asMap().entries.map((entry) {
                          final post = entry.value;
                          final position = _nodePositions[post.id];

                          if (position == null) return const SizedBox.shrink();

                          // Cull nodes outside viewport
                          final cartesian = position.toCartesian();
                          final nodePosition = Offset(
                            size.width * 2.5 + cartesian.dx,
                            size.height * 2.5 + cartesian.dy,
                          );

                          if (!MapPositioner.isInViewport(
                            nodePosition,
                            size,
                            cameraOffset: _cameraOffset,
                            scale: _scale,
                          )) {
                            return const SizedBox.shrink();
                          }

                          return Positioned(
                            left: nodePosition.dx - 40,
                            top: nodePosition.dy - 40,
                            child: PulseNodeWidget(
                              post: post,
                              parallaxOffset: _gyroscopeOffset,
                              scale: _scale,
                              onTap: () => _onNodeTap(post),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Snap-back button
                if (_showSnapBack)
                  Positioned(
                    bottom: 100,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _snapBackToCenter,
                      child: const Icon(Icons.my_location),
                    ),
                  ),

                // Expanded post overlay
                if (_expandedPost != null) _buildExpandedPostOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserNode() {
    final theme = Theme.of(context);

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.person, size: 50, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildExpandedPostOverlay() {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        // Find the latest version of this post in the provider's state
        final post = feedProvider.posts.firstWhere(
          (p) => p.id == _expandedPost!.id,
          orElse: () => _expandedPost!,
        );

        return Positioned.fill(
          child: GestureDetector(
            onTap: _closeExpandedPost,
            child: Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Hero(
                  tag: 'post_${post.id}',
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 600,
                        maxHeight: MediaQuery.of(context).size.height * 0.9,
                      ),
                      margin: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Close button
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: _closeExpandedPost,
                            ),
                          ),

                          // Post card
                          Expanded(
                            child: SingleChildScrollView(
                              child: PostCard(
                                post: post,
                                onLike: () {
                                  final userId = context
                                      .read<AuthService>()
                                      .currentUser
                                      ?.id;
                                  if (userId == null) return;

                                  if (post.isLiked) {
                                    feedProvider.unlikePost(
                                      userId: userId,
                                      postId: post.id,
                                    );
                                  } else {
                                    feedProvider.likePost(
                                      userId: userId,
                                      postId: post.id,
                                    );
                                  }
                                },
                                onBookmark: () {
                                  final userId = context
                                      .read<AuthService>()
                                      .currentUser
                                      ?.id;
                                  if (userId == null) return;

                                  if (post.isBookmarked) {
                                    feedProvider.unbookmarkPost(
                                      userId: userId,
                                      postId: post.id,
                                    );
                                  } else {
                                    feedProvider.bookmarkPost(
                                      userId: userId,
                                      postId: post.id,
                                    );
                                  }
                                },
                                onComment: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useRootNavigator: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        CommentsModal(postId: post.id),
                                  );
                                },
                                onShare: () {
                                  final deepLink = AppConfig.getWebUrl(
                                    '/post/${post.id}',
                                  );
                                  Share.share(
                                    'Check out this post on Oasis! $deepLink',
                                  );
                                },
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
          ),
        );
      },
    );
  }
}

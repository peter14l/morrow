import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

/// Widget representing a post node in the Pulse Map
/// Displays as a circular orb with parallax effect
class PulseNodeWidget extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Offset parallaxOffset;
  final double scale;

  const PulseNodeWidget({
    super.key,
    required this.post,
    required this.onTap,
    this.onLongPress,
    this.parallaxOffset = Offset.zero,
    this.scale = 1.0,
  });

  @override
  State<PulseNodeWidget> createState() => _PulseNodeWidgetState();
}

class _PulseNodeWidgetState extends State<PulseNodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Subtle pulsing animation (scale)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Floating animation (bobbing)
    // Randomize duration slightly to avoid robotic uniformity
    final random = Random();
    _floatController = AnimationController(
      duration: Duration(milliseconds: 3000 + random.nextInt(1000)),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation =
        Tween<Offset>(
          begin: const Offset(0, -5),
          end: const Offset(0, 5),
        ).animate(
          CurvedAnimation(
            parent: _floatController,
            curve: Curves.easeInOutSine,
          ),
        );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl =
        widget.post.thumbnailUrl ??
        widget.post.imageUrl ??
        (widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : null);

    // Engagement score for glow effect
    final engagementScore = widget.post.likes + (widget.post.comments * 2);
    final hasHighEngagement = engagementScore > 10;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _floatAnimation]),
        builder: (context, child) {
          return Transform.translate(
            offset: _floatAnimation.value, // Apply floating movement
            child: Transform.scale(
              scale: _pulseAnimation.value * widget.scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Base shadow
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    // High engagement aura
                    if (hasHighEngagement)
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Orb background
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primary,
                          ],
                        ),
                        border: Border.all(
                          color: hasHighEngagement
                              ? Colors.amber.withValues(alpha: 0.6)
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                          width: hasHighEngagement ? 3 : 2,
                        ),
                      ),
                    ),

                    // Image with parallax effect
                    if (imageUrl != null)
                      ClipOval(
                        child: Transform.translate(
                          offset:
                              widget.parallaxOffset * 0.1, // Subtle parallax
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            placeholder: (context, url) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildFallbackOrb(),
                          ),
                        ),
                      )
                    else
                      _buildFallbackOrb(),

                    // Engagement indicator (small dot)
                    if (widget.post.likes > 0 || widget.post.comments > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasHighEngagement
                                ? Colors.amber
                                : Colors.red,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: hasHighEngagement
                              ? const Icon(
                                  Icons.star,
                                  size: 10,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackOrb() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.post.username[0].toUpperCase(),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

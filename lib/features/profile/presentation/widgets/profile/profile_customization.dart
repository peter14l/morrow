import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

/// Profile customization model
class ProfileCustomization {
  final String userId;
  final ProfileTheme theme;
  final String? animatedBannerUrl;
  final BannerAnimation bannerAnimation;
  final String? musicUrl;
  final String? musicTitle;
  final String? musicArtist;
  final String? currentMood;
  final String? moodEmoji;
  final Color? accentColor;

  ProfileCustomization({
    required this.userId,
    this.theme = ProfileTheme.defaultTheme,
    this.animatedBannerUrl,
    this.bannerAnimation = BannerAnimation.none,
    this.musicUrl,
    this.musicTitle,
    this.musicArtist,
    this.currentMood,
    this.moodEmoji,
    this.accentColor,
  });

  factory ProfileCustomization.fromJson(Map<String, dynamic> json) {
    return ProfileCustomization(
      userId: json['user_id'],
      theme: ProfileTheme.fromString(json['theme'] ?? 'default'),
      animatedBannerUrl: json['animated_banner_url'],
      bannerAnimation: BannerAnimation.fromString(
        json['banner_animation'] ?? 'none',
      ),
      musicUrl: json['music_url'],
      musicTitle: json['music_title'],
      musicArtist: json['music_artist'],
      currentMood: json['current_mood'],
      moodEmoji: json['mood_emoji'],
      accentColor: json['accent_color'] != null
          ? Color(int.parse(json['accent_color'].replaceFirst('#', '0xFF')))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'theme': theme.value,
      'animated_banner_url': animatedBannerUrl,
      'banner_animation': bannerAnimation.value,
      'music_url': musicUrl,
      'music_title': musicTitle,
      'music_artist': musicArtist,
      'current_mood': currentMood,
      'mood_emoji': moodEmoji,
      'accent_color': accentColor != null
          ? '#${accentColor!.toARGB32().toRadixString(16).substring(2)}'
          : null,
    };
  }

  ProfileCustomization copyWith({
    ProfileTheme? theme,
    String? animatedBannerUrl,
    BannerAnimation? bannerAnimation,
    String? musicUrl,
    String? musicTitle,
    String? musicArtist,
    String? currentMood,
    String? moodEmoji,
    Color? accentColor,
  }) {
    return ProfileCustomization(
      userId: userId,
      theme: theme ?? this.theme,
      animatedBannerUrl: animatedBannerUrl ?? this.animatedBannerUrl,
      bannerAnimation: bannerAnimation ?? this.bannerAnimation,
      musicUrl: musicUrl ?? this.musicUrl,
      musicTitle: musicTitle ?? this.musicTitle,
      musicArtist: musicArtist ?? this.musicArtist,
      currentMood: currentMood ?? this.currentMood,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

enum ProfileTheme {
  defaultTheme('default', 'Default', null, null),
  midnight('midnight', 'Midnight', Color(0xFF1A1A2E), Color(0xFF16213E)),
  forest('forest', 'Forest', Color(0xFF1B4332), Color(0xFF2D6A4F)),
  sunset('sunset', 'Sunset', Color(0xFFFF6B6B), Color(0xFFFFE66D)),
  ocean('ocean', 'Ocean', Color(0xFF0077B6), Color(0xFF00B4D8)),
  lavender('lavender', 'Lavender', Color(0xFFE6E6FA), Color(0xFFB19CD9)),
  neon('neon', 'Neon', Color(0xFFFF00FF), Color(0xFF00FFFF)),
  minimal('minimal', 'Minimal', Color(0xFFF5F5F5), Color(0xFFE0E0E0));

  final String value;
  final String label;
  final Color? primaryColor;
  final Color? secondaryColor;

  const ProfileTheme(
    this.value,
    this.label,
    this.primaryColor,
    this.secondaryColor,
  );

  static ProfileTheme fromString(String value) {
    return ProfileTheme.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ProfileTheme.defaultTheme,
    );
  }
}

enum BannerAnimation {
  none('none', 'None'),
  gradient('gradient', 'Gradient Flow'),
  particles('particles', 'Particles'),
  wave('wave', 'Wave'),
  sparkle('sparkle', 'Sparkle');

  final String value;
  final String label;

  const BannerAnimation(this.value, this.label);

  static BannerAnimation fromString(String value) {
    return BannerAnimation.values.firstWhere(
      (a) => a.value == value,
      orElse: () => BannerAnimation.none,
    );
  }
}

/// Widget for animated profile banner
class AnimatedProfileBanner extends StatefulWidget {
  final String? imageUrl;
  final BannerAnimation animation;
  final double height;
  final Color? overlayColor;

  const AnimatedProfileBanner({
    super.key,
    this.imageUrl,
    this.animation = BannerAnimation.none,
    this.height = 200,
    this.overlayColor,
  });

  @override
  State<AnimatedProfileBanner> createState() => _AnimatedProfileBannerState();
}

class _AnimatedProfileBannerState extends State<AnimatedProfileBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (widget.imageUrl != null)
            CachedNetworkImage(
              imageUrl: widget.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _buildDefaultBanner(),
            )
          else
            _buildDefaultBanner(),

          // Animation overlay
          if (widget.animation != BannerAnimation.none)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _BannerAnimationPainter(
                    animation: widget.animation,
                    progress: _controller.value,
                    color:
                        widget.overlayColor ??
                        Colors.white.withValues(alpha: 0.3),
                  ),
                );
              },
            ),

          // Gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
    );
  }
}

class _BannerAnimationPainter extends CustomPainter {
  final BannerAnimation animation;
  final double progress;
  final Color color;

  _BannerAnimationPainter({
    required this.animation,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (animation) {
      case BannerAnimation.gradient:
        _paintGradientFlow(canvas, size);
        break;
      case BannerAnimation.wave:
        _paintWave(canvas, size);
        break;
      case BannerAnimation.sparkle:
        _paintSparkle(canvas, size);
        break;
      case BannerAnimation.particles:
        _paintParticles(canvas, size);
        break;
      default:
        break;
    }
  }

  void _paintGradientFlow(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + progress * 2, 0),
        end: Alignment(progress * 2, 0),
        colors: [Colors.transparent, color, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _paintWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    for (var x = 0.0; x <= size.width; x += 5) {
      final y =
          size.height * 0.5 +
          10 *
              (x / 50 + progress * 10).remainder(1) *
              (x.toInt() % 2 == 0 ? 1 : -1);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _paintSparkle(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final random = (progress * 1000).toInt();

    for (var i = 0; i < 20; i++) {
      final x = ((random + i * 37) % size.width.toInt()).toDouble();
      final y = ((random + i * 53) % size.height.toInt()).toDouble();
      final sparkleProgress = ((progress * 2 + i * 0.1) % 1);
      final sparkleSize = 3 * (1 - sparkleProgress);

      paint.color = color.withValues(alpha: 1 - sparkleProgress);
      canvas.drawCircle(Offset(x, y), sparkleSize, paint);
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (var i = 0; i < 15; i++) {
      final baseX = (i * 73) % size.width.toInt();
      final y = size.height * (1 - ((progress + i * 0.1) % 1));
      final particleSize = 2 + (i % 3);

      paint.color = color.withValues(alpha: 0.5);
      canvas.drawCircle(
        Offset(baseX.toDouble(), y),
        particleSize.toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BannerAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Music status display widget
class MusicStatusWidget extends StatelessWidget {
  final String? title;
  final String? artist;
  final VoidCallback? onTap;

  const MusicStatusWidget({super.key, this.title, this.artist, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (title == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticUtils.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                artist != null ? '$title • $artist' : title!,
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mood status display widget
class MoodStatusWidget extends StatelessWidget {
  final String? mood;
  final String? emoji;
  final VoidCallback? onTap;

  const MoodStatusWidget({super.key, this.mood, this.emoji, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (mood == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticUtils.lightImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 14)),
            if (emoji != null) const SizedBox(width: 4),
            Text(
              mood!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile theme selector
class ProfileThemeSelector extends StatelessWidget {
  final ProfileTheme selectedTheme;
  final ValueChanged<ProfileTheme> onThemeSelected;

  const ProfileThemeSelector({
    super.key,
    required this.selectedTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Theme',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ProfileTheme.values.map((profileTheme) {
            final isSelected = selectedTheme == profileTheme;
            return GestureDetector(
              onTap: () {
                HapticUtils.selectionClick();
                onThemeSelected(profileTheme);
              },
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: profileTheme.primaryColor != null
                          ? LinearGradient(
                              colors: [
                                profileTheme.primaryColor!,
                                profileTheme.secondaryColor ??
                                    profileTheme.primaryColor!,
                              ],
                            )
                          : null,
                      color: profileTheme.primaryColor == null
                          ? colorScheme.surface
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: profileTheme == ProfileTheme.defaultTheme
                        ? Icon(Icons.auto_awesome, color: colorScheme.onSurface)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileTheme.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

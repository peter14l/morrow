import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class VoiceMemoWidget extends StatefulWidget {
  final String content; // URL to the audio file
  final DateTime createdAt;

  const VoiceMemoWidget({
    super.key,
    required this.content,
    required this.createdAt,
  });

  @override
  State<VoiceMemoWidget> createState() => _VoiceMemoWidgetState();
}

class _VoiceMemoWidgetState extends State<VoiceMemoWidget>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late final AnimationController _waveformController;

  @override
  void initState() {
    super.initState();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _waveformController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _waveformController.repeat(reverse: true);
      } else {
        _waveformController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying
                    ? FluentIcons.pause_24_filled
                    : FluentIcons.play_24_filled,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _WaveformPainter(
                  isAnimating: _isPlaying,
                  animation: _waveformController,
                ),
                const SizedBox(height: 4),
                Text(
                  'Voice Note · 0:42', // Mock duration for now
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${widget.createdAt.hour}:${widget.createdAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends StatelessWidget {
  final bool isAnimating;
  final Animation<double> animation;

  const _WaveformPainter({required this.isAnimating, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(25, (index) {
            // Generate some random-looking but stable heights
            final double baseHeight = 4 + (index % 5) * 3.0 + (index % 3) * 2.0;
            final double animatedHeight = isAnimating
                ? baseHeight + (sin(animation.value * 2 * 3.14159 + index) * 5)
                : baseHeight;

            return Container(
              width: 3,
              height: animatedHeight.clamp(4, 24),
              decoration: BoxDecoration(
                color: isAnimating
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

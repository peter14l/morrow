import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// An overlay that can display animated emoji explosions or heart effects.
class ReactionAnimationOverlay extends StatefulWidget {
  final Stream<ReactionAnimationEvent> animationStream;

  const ReactionAnimationOverlay({super.key, required this.animationStream});

  @override
  State<ReactionAnimationOverlay> createState() =>
      _ReactionAnimationOverlayState();
}

class _ReactionAnimationOverlayState extends State<ReactionAnimationOverlay> {
  final List<_AnimatedReaction> _reactions = [];
  final Random _random = Random();

  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.animationStream.listen(_onAnimationEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onAnimationEvent(ReactionAnimationEvent event) {
    if (!mounted) return;

    setState(() {
      _reactions.add(
        _AnimatedReaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          emoji: event.emoji,
          position: event.position,
          type: event.type,
        ),
      );
    });
  }

  void _removeReaction(String id) {
    if (!mounted) return;
    setState(() {
      _reactions.removeWhere((r) => r.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _reactions.map((reaction) {
        if (reaction.type == ReactionAnimationType.burst) {
          return _buildBurstReaction(reaction);
        } else {
          return _buildHeartReaction(reaction);
        }
      }).toList(),
    );
  }

  Widget _buildBurstReaction(_AnimatedReaction reaction) {
    return Stack(
      children: List.generate(8, (index) {
        final angle = (index * 45) * (pi / 180);
        final distance = 60.0 + _random.nextDouble() * 40.0;
        final dx = cos(angle) * distance;
        final dy = sin(angle) * distance;

        return Positioned(
          left: reaction.position.dx - 10,
          top: reaction.position.dy - 10,
          child: Text(reaction.emoji, style: const TextStyle(fontSize: 24))
              .animate(
                onComplete: (controller) {
                  if (index == 7) _removeReaction(reaction.id);
                },
              )
              .move(
                begin: Offset.zero,
                end: Offset(dx, dy),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              )
              .fadeOut(duration: 600.ms)
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.2, 1.2),
              ),
        );
      }),
    );
  }

  Widget _buildHeartReaction(_AnimatedReaction reaction) {
    return Positioned(
      left: reaction.position.dx - 40,
      top: reaction.position.dy - 40,
      child: Icon(Icons.favorite, color: Colors.red.shade400, size: 80)
          .animate(onComplete: (_) => _removeReaction(reaction.id))
          .scale(
            begin: const Offset(0, 0),
            end: const Offset(1.5, 1.5),
            duration: 400.ms,
            curve: Curves.elasticOut,
          )
          .fadeOut(begin: 1, delay: 400.ms, duration: 400.ms)
          .moveY(begin: 0, end: -100, duration: 800.ms, curve: Curves.easeOut),
    );
  }
}

enum ReactionAnimationType { burst, heart }

class ReactionAnimationEvent {
  final String emoji;
  final Offset position;
  final ReactionAnimationType type;

  ReactionAnimationEvent({
    required this.emoji,
    required this.position,
    this.type = ReactionAnimationType.burst,
  });
}

class _AnimatedReaction {
  final String id;
  final String emoji;
  final Offset position;
  final ReactionAnimationType type;

  _AnimatedReaction({
    required this.id,
    required this.emoji,
    required this.position,
    required this.type,
  });
}

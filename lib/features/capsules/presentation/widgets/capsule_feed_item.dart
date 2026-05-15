import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:oasis/themes/app_colors.dart';

class CapsuleFeedItem extends StatelessWidget {
  final TimeCapsule capsule;

  const CapsuleFeedItem({super.key, required this.capsule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = capsule.isLocked;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: AspectRatio(
        aspectRatio: 1.6, // Envelope shape
        child: Stack(
          children: [
            // Envelope Body
            Container(
              decoration: BoxDecoration(
                color: OasisColors.sand,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),

            // Envelope Flap Lines (using CustomPaint)
            Positioned.fill(
              child: CustomPaint(
                painter: EnvelopePainter(
                  color: OasisColors.sage.withValues(alpha: 0.2),
                ),
              ),
            ),

            // Content (Peeking through if unlocked)
            if (!isLocked)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capsule.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: OasisColors.deep.withValues(alpha: 0.8),
                          fontFamily: 'Inter',
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            'From: ${capsule.username}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: OasisColors.deep.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeago.format(capsule.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: OasisColors.deep.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Wax Seal (if locked)
            if (isLocked)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B0000), // Wax Red
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF5D0000),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFFFD700), // Gold icon
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: OasisColors.deep.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(capsule.timeRemaining),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: OasisColors.deep.withValues(alpha: 0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Address Label style
            if (isLocked)
              Positioned(
                top: 24,
                left: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TO BE OPENED BY:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: OasisColors.deep.withValues(alpha: 0.3),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      capsule.username.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: OasisColors.deep.withValues(alpha: 0.7),
                        fontFamily: 'Cormorant Garamond',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 365) {
      return 'UNSEALS IN ${(d.inDays / 365).toStringAsFixed(1)}Y';
    } else if (d.inDays > 0) {
      return 'UNSEALS IN ${d.inDays}D';
    } else if (d.inHours > 0) {
      return 'UNSEALS IN ${d.inHours}H';
    } else {
      return 'UNSEALING SOON';
    }
  }
}

class EnvelopePainter extends CustomPainter {
  final Color color;

  EnvelopePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();

    // Top flap lines
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height * 0.45);
    path.lineTo(size.width, 0);

    // Bottom fold lines
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.4, size.height * 0.6);

    path.moveTo(size.width, size.height);
    path.lineTo(size.width * 0.6, size.height * 0.6);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

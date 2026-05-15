import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'dart:math' as math;
import 'package:oasis/core/utils/haptic_utils.dart';

class CommitmentCard extends StatefulWidget {
  final CommitmentEntity commitment;
  final String currentUserId;
  final VoidCallback onMarkComplete;
  final void Function(MemberIntent intent) onSetIntent;

  const CommitmentCard({
    super.key,
    required this.commitment,
    required this.currentUserId,
    required this.onMarkComplete,
    required this.onSetIntent,
  });

  @override
  State<CommitmentCard> createState() => _CommitmentCardState();
}

class _CommitmentCardState extends State<CommitmentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fillController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fillController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticUtils.heavyImpact();
        widget.onMarkComplete();
        _resetFill();
      }
    });
  }

  void _resetFill() {
    setState(() => _isHolding = false);
    _fillController.reverse();
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final myResponse = widget.commitment.responses[widget.currentUserId];
    final isCompleted = myResponse?.completed ?? false;
    final intent = myResponse?.intent;
    final totalResponses = widget.commitment.responses.length;

    return GestureDetector(
      onLongPressStart: (_) {
        if (!isCompleted && intent == MemberIntent.inTrying) {
          setState(() => _isHolding = true);
          _fillController.forward();
          HapticUtils.selectionClick();
        }
      },
      onLongPressEnd: (_) => _resetFill(),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: _isHolding ? 0.98 : 1.0,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colorScheme.surface,
            border: Border.all(
              color: isCompleted
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outline.withValues(alpha: 0.15),
              width: isCompleted ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Fluid Fill Background
              if (_isHolding || _fillController.value > 0)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _fillController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _FluidFillPainter(
                          progress: _fillController.value,
                          color: colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      );
                    },
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title row ─────────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Completion check icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isCompleted
                                  ? colorScheme.primary
                                  : colorScheme.outline.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(
                                  FluentIcons.checkmark_16_filled,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : _isHolding
                              ? Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      value: _fillController.value,
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.commitment.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isCompleted
                                      ? colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        )
                                      : null,
                                ),
                              ),
                              if (widget.commitment.description != null)
                                Text(
                                  widget.commitment.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Progress & Intent ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (totalResponses > 0)
                          _MemberProgressRow(commitment: widget.commitment),

                        if (!isCompleted)
                          Row(
                            children: [
                              _IntentChip(
                                label: '👊',
                                isSelected: intent == MemberIntent.inTrying,
                                onTap: () =>
                                    widget.onSetIntent(MemberIntent.inTrying),
                                activeColor: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              _IntentChip(
                                label: 'Skip',
                                isSelected: intent == MemberIntent.out,
                                onTap: () =>
                                    widget.onSetIntent(MemberIntent.out),
                                activeColor: colorScheme.error,
                              ),
                            ],
                          ),
                      ],
                    ),

                    if (isCompleted && myResponse?.note != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: colorScheme.primary.withValues(alpha: 0.08),
                        ),
                        child: Text(
                          '"${myResponse!.note}"',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],

                    if (!isCompleted &&
                        intent == MemberIntent.inTrying &&
                        !_isHolding)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text(
                            'HOLD TO VERIFY',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

class _FluidFillPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FluidFillPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    final fillHeight = size.height * progress;
    final y = size.height - fillHeight;

    path.moveTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, y);

    // Add some wave movement
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        size.width - i,
        y + math.sin((i / size.width * 2 * math.pi) + (progress * 10)) * 4,
      );
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidFillPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── sub-widgets ─────────────────────────────────────────────────────────────

class _IntentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _IntentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? activeColor
                : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? activeColor
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MemberProgressRow extends StatelessWidget {
  final CommitmentEntity commitment;
  const _MemberProgressRow({required this.commitment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responses = commitment.responses.values.toList();

    return Row(
      children: [
        ...responses.take(5).map((r) {
          final done = r.completed;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        Text(
          '${responses.where((r) => r.completed).length}/${responses.length} done',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

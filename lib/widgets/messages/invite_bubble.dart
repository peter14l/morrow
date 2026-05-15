import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class InviteBubble extends StatelessWidget {
  final String payload;
  final bool isSender;

  const InviteBubble({
    super.key,
    required this.payload,
    required this.isSender,
  });

  /// The payload is expected to be in the format: [INVITE:type:id:name]
  /// type: 'canvas' or 'circle'
  String get _type => payload.split(':')[1];
  String get _id => payload.split(':')[2];
  String get _name =>
      payload.split(':').sublist(3).join(':').replaceAll(']', '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isCanvas = _type == 'canvas';
    final icon = isCanvas
        ? FluentIcons.paint_brush_24_regular
        : FluentIcons.people_team_24_regular;
    final typeLabel = isCanvas ? 'Canvas' : 'Circle';
    final routeDetails = isCanvas
        ? '/spaces/canvas/$_id'
        : '/spaces/circles/$_id';

    return Container(
      width: 240, // Fixed width for nice card appearance in chat
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSender
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16).copyWith(
          topLeft: isSender
              ? const Radius.circular(16)
              : const Radius.circular(2),
          topRight: isSender
              ? const Radius.circular(2)
              : const Radius.circular(16),
        ),
        border: Border.all(
          color: isSender
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSender
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '$typeLabel Invite',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isSender
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSender
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 12),

          // Action Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isSender
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  context.push(routeDetails);
                },
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'View $typeLabel',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';

class InviteBubble extends StatelessWidget {
  final String content;
  final bool isMe;

  const InviteBubble({super.key, required this.content, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // Regex safely captures the type, id, and name.
    final match = RegExp(r'\[INVITE:(.*?):(.*?):(.*?)\]').firstMatch(content);

    if (match == null) {
      // Fallback if parsing fails for some reason
      return Padding(padding: const EdgeInsets.all(12), child: Text(content));
    }

    final entityType = match.group(1) ?? '';
    final entityId = match.group(2) ?? '';
    final entityName = match.group(3) ?? '';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isCircle = entityType.toLowerCase() == 'circle';
    final isCanvas = entityType.toLowerCase() == 'canvas';

    final title = isCircle
        ? 'Circle Invitation'
        : (isCanvas ? 'Canvas Invitation' : 'Invitation');
    final icon = isCircle
        ? FluentIcons.people_team_24_regular
        : (isCanvas
              ? FluentIcons.board_24_regular
              : FluentIcons.mail_24_regular);

    final actionText = isCircle
        ? (isMe ? 'View Circle' : 'Join Circle')
        : 'View Canvas';

    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? colorScheme.surfaceContainerHigh
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCircle
                        ? Colors.blue.withValues(alpha: 0.1)
                        : (isCanvas
                              ? Colors.purple.withValues(alpha: 0.1)
                              : colorScheme.primaryContainer),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isCircle
                        ? Colors.blue
                        : (isCanvas ? Colors.purple : colorScheme.primary),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entityName.isEmpty ? 'Untitled' : entityName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isCircle) {
                  context.pushNamed(
                    'join_circle',
                    pathParameters: {'circleId': entityId},
                  );
                } else if (isCanvas) {
                  context.pushNamed(
                    'canvas_detail',
                    pathParameters: {'canvasId': entityId},
                  );
                }
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      actionText,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

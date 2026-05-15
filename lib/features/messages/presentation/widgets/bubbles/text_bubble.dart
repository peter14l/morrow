import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:any_link_preview/any_link_preview.dart';

import 'package:oasis/widgets/spoiler_widget.dart';

/// Utilities for text message processing.
/// Extracted from _ChatScreenState helper methods in chat_screen.dart.
class MessageTextUtils {
  static const _urlRegExp =
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/[^\s]+)';

  static bool isDisplayableCaption(String text) {
    if (text.isEmpty) return false;
    if (text == 'Sent attachment') return false;
    if (text.contains('🔒')) return false;
    // Heuristic: if it looks like ciphertext (no spaces, long, and starts with ey or ends with =)
    if (text.length > 30 && !text.contains(' ')) {
      if (text.startsWith('ey') || text.endsWith('=')) return false;
    }
    return true;
  }

  static bool containsUrl(String text) {
    final urlRegExp = RegExp(_urlRegExp, caseSensitive: false);
    return urlRegExp.hasMatch(text);
  }

  static String extractUrl(String text) {
    final urlRegExp = RegExp(_urlRegExp, caseSensitive: false);
    return urlRegExp.firstMatch(text)?.group(0) ?? '';
  }
}

/// Text message bubble with optional link preview.
/// Extracted from the text branch of _buildMessageBubble() in chat_screen.dart.
class TextBubble extends StatelessWidget {
  const TextBubble({
    super.key,
    required this.content,
    required this.isMe,
    this.textColor,
    this.isSpoiler = false,
  });

  final String content;
  final bool isMe;
  final Color? textColor;
  final bool isSpoiler;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color =
        textColor ??
        (isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface);

    final bool isCiphertext = !MessageTextUtils.isDisplayableCaption(content);

    final Widget textContent = _buildTextContent(context, color, isCiphertext);

    // If text contains a URL and is not encrypted, show link preview
    if (content != '🔒 Message encrypted' &&
        MessageTextUtils.containsUrl(content)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          textContent,
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AnyLinkPreview(
              link: MessageTextUtils.extractUrl(content),
              displayDirection: UIDirection.uiDirectionVertical,
              showMultimedia: true,
              bodyMaxLines: 3,
              bodyTextOverflow: TextOverflow.ellipsis,
              titleStyle: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              bodyStyle: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.8),
                fontSize: 12,
              ),
              backgroundColor: isMe
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
              borderRadius: 12,
              removeElevation: true,
              onTap: () async {
                final url = MessageTextUtils.extractUrl(content);
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
        ],
      );
    }

    return textContent;
  }

  Widget _buildTextContent(
    BuildContext context,
    Color color,
    bool isCiphertext,
  ) {
    final theme = Theme.of(context);
    final String displayText = isCiphertext
        ? '🔒 Message encrypted'
        : content.trim();

    if (isCiphertext || displayText == '🔒 Message encrypted') {
      return Text(
        displayText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (isSpoiler) {
      return SpoilerWidget(
        child: Text(
          displayText,
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      );
    }

    // Parse Discord-style spoilers: ||spoiler||
    final List<Widget> children = [];
    final RegExp spoilerRegExp = RegExp(r'\|\|(.*?)\|\|');
    int lastMatchEnd = 0;

    final Iterable<RegExpMatch> matches = spoilerRegExp.allMatches(displayText);

    if (matches.isEmpty) {
      return Text(
        displayText,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      );
    }

    for (final match in matches) {
      // Add text before spoiler
      if (match.start > lastMatchEnd) {
        children.add(
          Text(
            displayText.substring(lastMatchEnd, match.start),
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        );
      }

      // Add spoiler
      children.add(
        SpoilerWidget(
          child: Text(
            match.group(1) ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < displayText.length) {
      children.add(
        Text(
          displayText.substring(lastMatchEnd),
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

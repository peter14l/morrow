import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TextParser {
  /// Parse text and return a TextSpan with clickable hashtags and mentions
  static TextSpan parseText(
    String text, {
    TextStyle? defaultStyle,
    TextStyle? hashtagStyle,
    TextStyle? mentionStyle,
    Function(String)? onHashtagTap,
    Function(String)? onMentionTap,
  }) {
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'(#[a-zA-Z0-9_]+|@[a-z0-9_]+)');

    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;
      final isHashtag = matchedText.startsWith('#');
      final isMention = matchedText.startsWith('@');

      if (isHashtag) {
        spans.add(
          TextSpan(
            text: matchedText,
            style:
                hashtagStyle ??
                const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onHashtagTap != null) {
                  onHashtagTap(matchedText.substring(1)); // Remove #
                }
              },
          ),
        );
      } else if (isMention) {
        spans.add(
          TextSpan(
            text: matchedText,
            style:
                mentionStyle ??
                const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onMentionTap != null) {
                  onMentionTap(matchedText.substring(1)); // Remove @
                }
              },
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(text: text.substring(lastMatchEnd), style: defaultStyle),
      );
    }

    return TextSpan(children: spans);
  }

  /// Extract hashtags from text
  static List<String> extractHashtags(String text) {
    final RegExp regex = RegExp(r'#([a-zA-Z0-9_]+)');
    return regex.allMatches(text).map((match) => match.group(1)!).toList();
  }

  /// Extract mentions from text
  static List<String> extractMentions(String text) {
    final RegExp regex = RegExp(r'@([a-z0-9_]+)');
    return regex.allMatches(text).map((match) => match.group(1)!).toList();
  }

  /// Check if text contains hashtags
  static bool hasHashtags(String text) {
    return RegExp(r'#[a-zA-Z0-9_]+').hasMatch(text);
  }

  /// Check if text contains mentions
  static bool hasMentions(String text) {
    return RegExp(r'@[a-z0-9_]+').hasMatch(text);
  }

  /// Get the last word being typed (for autocomplete)
  static String? getLastTypedWord(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) {
      return null;
    }

    // Get text up to cursor
    final textBeforeCursor = text.substring(0, cursorPosition);

    // Check for hashtag or mention at cursor
    final hashtagMatch = RegExp(
      r'#([a-zA-Z0-9_]*)$',
    ).firstMatch(textBeforeCursor);
    if (hashtagMatch != null) {
      return hashtagMatch.group(0); // Returns #word
    }

    final mentionMatch = RegExp(r'@([a-z0-9_]*)$').firstMatch(textBeforeCursor);
    if (mentionMatch != null) {
      return mentionMatch.group(0); // Returns @word
    }

    return null;
  }

  /// Replace the last word with a suggestion
  static String replaceLastWord(
    String text,
    int cursorPosition,
    String replacement,
  ) {
    final textBeforeCursor = text.substring(0, cursorPosition);
    final textAfterCursor = text.substring(cursorPosition);

    // Find the start of the last word
    final hashtagMatch = RegExp(
      r'#([a-zA-Z0-9_]*)$',
    ).firstMatch(textBeforeCursor);
    final mentionMatch = RegExp(r'@([a-z0-9_]*)$').firstMatch(textBeforeCursor);

    if (hashtagMatch != null) {
      final beforeWord = textBeforeCursor.substring(0, hashtagMatch.start);
      return '$beforeWord$replacement $textAfterCursor';
    }

    if (mentionMatch != null) {
      final beforeWord = textBeforeCursor.substring(0, mentionMatch.start);
      return '$beforeWord$replacement $textAfterCursor';
    }

    return text;
  }

  /// Validate hashtag format
  static bool isValidHashtag(String tag) {
    return RegExp(r'^[a-zA-Z0-9_]{2,50}$').hasMatch(tag);
  }

  /// Validate mention format
  static bool isValidMention(String mention) {
    return RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(mention);
  }
}

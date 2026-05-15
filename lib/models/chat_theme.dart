import 'package:flutter/material.dart';

/// Chat theme presets
enum ChatThemePreset {
  defaultTheme('Default', null, null, null),
  midnight('Midnight', Color(0xFF1A1A2E), Color(0xFF16213E), Colors.white),
  forest('Forest', Color(0xFF1B4332), Color(0xFF2D6A4F), Colors.white),
  sunset('Sunset', Color(0xFFFFE4C4), Color(0xFFFFB347), Colors.black87),
  ocean('Ocean', Color(0xFF0077B6), Color(0xFF00B4D8), Colors.white),
  lavender('Lavender', Color(0xFFE6E6FA), Color(0xFFB19CD9), Colors.black87),
  rose('Rose', Color(0xFFFFE4E1), Color(0xFFFFB6C1), Colors.black87),
  space('Space', Color(0xFF0D1B2A), Color(0xFF1B263B), Colors.white);

  final String name;
  final Color? backgroundColor;
  final Color? bubbleColor;
  final Color? textColor;

  const ChatThemePreset(
    this.name,
    this.backgroundColor,
    this.bubbleColor,
    this.textColor,
  );
}

/// Model for custom chat theme
class ChatTheme {
  final String id;
  final String conversationId;
  final String userId;
  final String themeName;
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final Color? bubbleColor;
  final Color? textColor;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatTheme({
    required this.id,
    required this.conversationId,
    required this.userId,
    this.themeName = 'default',
    this.backgroundColor,
    this.backgroundImageUrl,
    this.bubbleColor,
    this.textColor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatTheme.fromJson(Map<String, dynamic> json) {
    return ChatTheme(
      id: json['id'],
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      themeName: json['theme_name'] ?? 'default',
      backgroundColor: json['background_color'] != null
          ? Color(int.parse(json['background_color'].replaceFirst('#', '0xFF')))
          : null,
      backgroundImageUrl: json['background_image_url'],
      bubbleColor: json['bubble_color'] != null
          ? Color(int.parse(json['bubble_color'].replaceFirst('#', '0xFF')))
          : null,
      textColor: json['text_color'] != null
          ? Color(int.parse(json['text_color'].replaceFirst('#', '0xFF')))
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'theme_name': themeName,
      'background_color': backgroundColor != null
          ? '#${backgroundColor!.toARGB32().toRadixString(16).substring(2)}'
          : null,
      'background_image_url': backgroundImageUrl,
      'bubble_color': bubbleColor != null
          ? '#${bubbleColor!.toARGB32().toRadixString(16).substring(2)}'
          : null,
      'text_color': textColor != null
          ? '#${textColor!.toARGB32().toRadixString(16).substring(2)}'
          : null,
    };
  }

  ChatTheme copyWith({
    String? themeName,
    Color? backgroundColor,
    String? backgroundImageUrl,
    Color? bubbleColor,
    Color? textColor,
  }) {
    return ChatTheme(
      id: id,
      conversationId: conversationId,
      userId: userId,
      themeName: themeName ?? this.themeName,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      textColor: textColor ?? this.textColor,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static ChatTheme fromPreset(
    ChatThemePreset preset,
    String id,
    String conversationId,
    String userId,
  ) {
    return ChatTheme(
      id: id,
      conversationId: conversationId,
      userId: userId,
      themeName: preset.name.toLowerCase(),
      backgroundColor: preset.backgroundColor,
      bubbleColor: preset.bubbleColor,
      textColor: preset.textColor,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// Represents a shared media file from external sources
class SharedMediaEntity {
  final String path;
  final String? mimeType;
  final int? sizeInBytes;
  final DateTime? createdAt;

  const SharedMediaEntity({
    required this.path,
    this.mimeType,
    this.sizeInBytes,
    this.createdAt,
  });

  factory SharedMediaEntity.fromJson(Map<String, dynamic> json) {
    return SharedMediaEntity(
      path: json['path'] as String,
      mimeType: json['mimeType'] as String?,
      sizeInBytes: json['sizeInBytes'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'mimeType': mimeType,
      'sizeInBytes': sizeInBytes,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isImage {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  bool get isVideo {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
  }

  bool get isAudio {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac');
  }

  double get sizeInMb => (sizeInBytes ?? 0) / (1024 * 1024);
}

/// Represents a share intent received from external apps
class ShareIntentEntity {
  final List<SharedMediaEntity> media;
  final String? text;
  final DateTime receivedAt;

  const ShareIntentEntity({
    required this.media,
    this.text,
    required this.receivedAt,
  });

  bool get hasMedia => media.isNotEmpty;
  bool get hasText => text != null && text!.isNotEmpty;
  bool get isEmpty => !hasMedia && !hasText;
}

/// Represents the result of a share operation
class ShareResultEntity {
  final String? conversationId;
  final bool success;
  final String? errorMessage;
  final List<String> sentMessageIds;

  const ShareResultEntity({
    this.conversationId,
    required this.success,
    this.errorMessage,
    this.sentMessageIds = const [],
  });

  factory ShareResultEntity.success({
    String? conversationId,
    List<String> sentMessageIds = const [],
  }) {
    return ShareResultEntity(
      conversationId: conversationId,
      success: true,
      sentMessageIds: sentMessageIds,
    );
  }

  factory ShareResultEntity.failure(String errorMessage) {
    return ShareResultEntity(success: false, errorMessage: errorMessage);
  }
}

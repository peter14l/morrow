enum CanvasItemType {
  text,
  photo,
  voice,
  sticker,
  milestone,
  journal,
  doodle,
  shape,
}

class CanvasItemEntity {
  final String id;
  final String canvasId;
  final String authorId;
  final CanvasItemType type;
  final String content;
  final double xPos;
  final double yPos;
  final double rotation;
  final double scale;
  final String color;
  final DateTime createdAt;
  final DateTime? unlockAt;
  final String? groupId;
  final Map<String, dynamic> metadata;
  final Map<String, List<String>> reactions;
  final bool isLocked;
  final String? lastModifiedBy;
  final Map<String, dynamic>? encryptedKeys;
  final String? iv;

  const CanvasItemEntity({
    required this.id,
    required this.canvasId,
    required this.authorId,
    required this.type,
    required this.content,
    required this.xPos,
    required this.yPos,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.color = '#252930',
    required this.createdAt,
    this.unlockAt,
    this.groupId,
    this.metadata = const {},
    this.reactions = const {},
    this.isLocked = false,
    this.lastModifiedBy,
    this.encryptedKeys,
    this.iv,
  });

  factory CanvasItemEntity.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as Map<String, dynamic>? ?? {};
    final parsedReactions = rawReactions.map(
      (key, value) => MapEntry(key, (value as List).cast<String>()),
    );

    return CanvasItemEntity(
      id: json['id'] as String,
      canvasId: json['canvas_id'] as String,
      authorId: json['author_id'] as String,
      type: CanvasItemType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'text'),
        orElse: () => CanvasItemType.text,
      ),
      content: json['content'] as String? ?? '',
      xPos: (json['x_pos'] as num?)?.toDouble() ?? 0.1,
      yPos: (json['y_pos'] as num?)?.toDouble() ?? 0.1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      color: json['color'] as String? ?? '#252930',
      createdAt: DateTime.parse(json['created_at'] as String),
      unlockAt: json['unlock_at'] != null
          ? DateTime.parse(json['unlock_at'] as String)
          : null,
      groupId: json['group_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      reactions: parsedReactions,
      isLocked: json['is_locked'] as bool? ?? false,
      lastModifiedBy: json['last_modified_by'] as String?,
      encryptedKeys: json['encrypted_keys'] as Map<String, dynamic>?,
      iv: json['iv'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'canvas_id': canvasId,
      'author_id': authorId,
      'type': type.name,
      'content': content,
      'x_pos': xPos,
      'y_pos': yPos,
      'rotation': rotation,
      'scale': scale,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'unlock_at': unlockAt?.toIso8601String(),
      'group_id': groupId,
      'metadata': metadata,
      'reactions': reactions,
      'is_locked': isLocked,
      'last_modified_by': lastModifiedBy,
      'encrypted_keys': encryptedKeys,
      'iv': iv,
    };
  }

  CanvasItemEntity copyWith({
    String? id,
    String? canvasId,
    String? authorId,
    CanvasItemType? type,
    String? content,
    double? xPos,
    double? yPos,
    double? rotation,
    double? scale,
    String? color,
    DateTime? createdAt,
    DateTime? unlockAt,
    String? groupId,
    Map<String, dynamic>? metadata,
    Map<String, List<String>>? reactions,
    bool? isLocked,
    String? lastModifiedBy,
    Map<String, dynamic>? encryptedKeys,
    String? iv,
  }) {
    return CanvasItemEntity(
      id: id ?? this.id,
      canvasId: canvasId ?? this.canvasId,
      authorId: authorId ?? this.authorId,
      type: type ?? this.type,
      content: content ?? this.content,
      xPos: xPos ?? this.xPos,
      yPos: yPos ?? this.yPos,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      unlockAt: unlockAt ?? this.unlockAt,
      groupId: groupId ?? this.groupId,
      metadata: metadata ?? this.metadata,
      reactions: reactions ?? this.reactions,
      isLocked: isLocked ?? this.isLocked,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      encryptedKeys: encryptedKeys ?? this.encryptedKeys,
      iv: iv ?? this.iv,
    );
  }
}

class CanvasPresenceEntity {
  final String userId;
  final double x;
  final double y;
  final String? activeItemId;

  const CanvasPresenceEntity({
    required this.userId,
    required this.x,
    required this.y,
    this.activeItemId,
  });

  factory CanvasPresenceEntity.fromJson(
    String userId,
    Map<String, dynamic> json,
  ) {
    return CanvasPresenceEntity(
      userId: userId,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      activeItemId: json['active_item_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'active_item_id': activeItemId};
  }

  CanvasPresenceEntity copyWith({
    String? userId,
    double? x,
    double? y,
    String? activeItemId,
  }) {
    return CanvasPresenceEntity(
      userId: userId ?? this.userId,
      x: x ?? this.x,
      y: y ?? this.y,
      activeItemId: activeItemId ?? this.activeItemId,
    );
  }
}

class OasisCanvas {
  final String id;
  final String title;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String coverColor;
  final List<String> memberIds;

  const OasisCanvas({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.coverColor,
    required this.memberIds,
  });

  factory OasisCanvas.fromJson(Map<String, dynamic> json) {
    return OasisCanvas(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Our Canvas',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      coverColor: json['cover_color'] as String? ?? '#3B82F6',
      memberIds:
          (json['member_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'cover_color': coverColor,
      'member_ids': memberIds,
    };
  }

  OasisCanvas copyWith({
    String? id,
    String? title,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coverColor,
    List<String>? memberIds,
  }) {
    return OasisCanvas(
      id: id ?? this.id,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverColor: coverColor ?? this.coverColor,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

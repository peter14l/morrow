export 'canvas_models.dart';

/// Canvas entity representing a collaborative canvas space.
class OasisCanvas {
  final String id;
  final String title;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String coverColor; // hex string, e.g. '#3B82F6'
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OasisCanvas && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

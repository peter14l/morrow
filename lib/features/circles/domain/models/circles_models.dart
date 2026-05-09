import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';

enum CommitmentStatus { open, closed }

enum MemberIntent { inTrying, out, pending }

class CommitmentResponseEntity {
  final String userId;
  final MemberIntent intent;
  final bool completed;
  final DateTime? completedAt;
  final String? note;

  const CommitmentResponseEntity({
    required this.userId,
    required this.intent,
    this.completed = false,
    this.completedAt,
    this.note,
  });

  factory CommitmentResponseEntity.fromJson(Map<String, dynamic> json) {
    return CommitmentResponseEntity(
      userId: json['user_id'] as String,
      intent: MemberIntent.values.firstWhere(
        (e) => e.name == (json['intent'] as String? ?? 'pending'),
        orElse: () => MemberIntent.pending,
      ),
      completed: json['completed'] as bool? ?? false,
      completedAt:
          json['completed_at'] != null
              ? DateTime.parse(json['completed_at'] as String)
              : null,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'intent': intent.name,
      'completed': completed,
      'completed_at': completedAt?.toIso8601String(),
      'note': note,
    };
  }

  CommitmentResponseEntity copyWith({
    String? userId,
    MemberIntent? intent,
    bool? completed,
    DateTime? completedAt,
    String? note,
  }) {
    return CommitmentResponseEntity(
      userId: userId ?? this.userId,
      intent: intent ?? this.intent,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }
}

class CommitmentEntity {
  final String id;
  final String circleId;
  final String createdBy;
  final String title;
  final String? description;
  final DateTime dueDate;
  final CommitmentStatus status;
  final Map<String, CommitmentResponseEntity> responses;
  final DateTime createdAt;

  const CommitmentEntity({
    required this.id,
    required this.circleId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.dueDate,
    this.status = CommitmentStatus.open,
    this.responses = const {},
    required this.createdAt,
  });

  factory CommitmentEntity.fromJson(Map<String, dynamic> json) {
    final rawResponses = json['responses'] as Map<String, dynamic>? ?? {};
    final responses = rawResponses.map(
      (k, v) => MapEntry(
        k,
        CommitmentResponseEntity.fromJson(v as Map<String, dynamic>),
      ),
    );

    return CommitmentEntity(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: CommitmentStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'open'),
        orElse: () => CommitmentStatus.open,
      ),
      responses: responses,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'circle_id': circleId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'responses': responses.map((k, v) => MapEntry(k, v.toJson())),
      'created_at': createdAt.toIso8601String(),
    };
  }

  int get completedCount => responses.values.where((r) => r.completed).length;

  int get inCount =>
      responses.values.where((r) => r.intent == MemberIntent.inTrying).length;

  bool isCompletedBy(String userId) => responses[userId]?.completed ?? false;

  MemberIntent intentOf(String userId) =>
      responses[userId]?.intent ?? MemberIntent.pending;

  CommitmentEntity copyWith({
    String? id,
    String? circleId,
    String? createdBy,
    String? title,
    String? description,
    DateTime? dueDate,
    CommitmentStatus? status,
    Map<String, CommitmentResponseEntity>? responses,
    DateTime? createdAt,
  }) {
    return CommitmentEntity(
      id: id ?? this.id,
      circleId: circleId ?? this.circleId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      responses: responses ?? this.responses,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CircleEntity {
  final String id;
  final String name;
  final String emoji;
  final String createdBy;
  final DateTime createdAt;
  final int streakCount;
  final List<String> memberIds;
  final List<UserProfileEntity> members;

  const CircleEntity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdBy,
    required this.createdAt,
    this.streakCount = 0,
    required this.memberIds,
    this.members = const [],
  });

  factory CircleEntity.fromJson(Map<String, dynamic> json) {
    final memberIds = (json['member_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [];
    
    final members = (json['members'] as List<dynamic>?)
              ?.map((e) => UserProfileEntity.fromJson(e as Map<String, dynamic>))
              .toList() ?? [];

    return CircleEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'My Circle',
      emoji: json['emoji'] as String? ?? '🌊',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      streakCount: json['streak_count'] as int? ?? 0,
      memberIds: memberIds,
      members: members,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'streak_count': streakCount,
      'member_ids': memberIds,
      'members': members.map((e) => e.toJson()).toList(),
    };
  }

  CircleEntity copyWith({
    String? id,
    String? name,
    String? emoji,
    String? createdBy,
    DateTime? createdAt,
    int? streakCount,
    List<String>? memberIds,
    List<UserProfileEntity>? members,
  }) {
    return CircleEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      streakCount: streakCount ?? this.streakCount,
      memberIds: memberIds ?? this.memberIds,
      members: members ?? this.members,
    );
  }

  bool get hasActiveStreak => streakCount > 0;
}

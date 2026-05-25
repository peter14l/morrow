/// Call status enum
enum CallStatus { ringing, active, ended, declined, missed }

/// Call type enum
enum CallType { voice, video }

/// Domain entity representing a call
class CallEntity {
  final String id;
  final String conversationId;
  final String callerId;
  final String receiverId;
  final CallStatus status;
  final CallType type;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  const CallEntity({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.receiverId,
    this.status = CallStatus.ringing,
    this.type = CallType.voice,
    this.offer,
    this.answer,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  factory CallEntity.fromJson(Map<String, dynamic> json) {
    return CallEntity(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      callerId: json['caller_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: CallStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CallStatus.ringing,
      ),
      type: CallType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CallType.voice,
      ),
      offer: json['offer'] as Map<String, dynamic>?,
      answer: json['answer'] as Map<String, dynamic>?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'status': status.name,
      'type': type.name,
      'offer': offer,
      'answer': answer,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  CallEntity copyWith({
    String? id,
    String? conversationId,
    String? callerId,
    String? receiverId,
    CallStatus? status,
    CallType? type,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
  }) {
    return CallEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      type: type ?? this.type,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          conversationId == other.conversationId &&
          callerId == other.callerId &&
          receiverId == other.receiverId &&
          status == other.status &&
          type == other.type &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      conversationId.hashCode ^
      callerId.hashCode ^
      receiverId.hashCode ^
      status.hashCode ^
      type.hashCode ^
      startedAt.hashCode ^
      endedAt.hashCode ^
      createdAt.hashCode;

  bool get isActive => status == CallStatus.active;
  bool get isVoiceCall => type == CallType.voice;
  bool get isVideoCall => type == CallType.video;
  Duration? get duration => (endedAt != null && startedAt != null)
      ? endedAt!.difference(startedAt!)
      : null;

  String get roomName => offer?['room_name'] as String? ?? id;
}

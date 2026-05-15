class Report {
  final String id;
  final String reporterId;
  final String? reportedUserId;
  final String? postId;
  final String? commentId;
  final String? messageId;
  final String reason;
  final String category;
  final String? description;
  final String status;
  final DateTime createdAt;

  // Additional fields from joins
  final String? reportedUsername;
  final String? postContent;
  final String? commentContent;
  final String? messageContent;

  Report({
    required this.id,
    required this.reporterId,
    this.reportedUserId,
    this.postId,
    this.commentId,
    this.messageId,
    required this.reason,
    required this.category,
    this.description,
    this.status = 'pending',
    required this.createdAt,
    this.reportedUsername,
    this.postContent,
    this.commentContent,
    this.messageContent,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String?,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      messageId: json['message_id'] as String?,
      reason: json['reason'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      reportedUsername: json['reported_user_username'] as String?,
      postContent: json['post_content'] as String?,
      commentContent: json['comment_content'] as String?,
      messageContent: json['message_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'post_id': postId,
      'comment_id': commentId,
      'message_id': messageId,
      'reason': reason,
      'category': category,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isReviewing => status == 'reviewing';
}

class BlockedUser {
  final String id;
  final String blockerId;
  final String blockedId;
  final String? reason;
  final DateTime createdAt;

  // Additional fields from joins
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  BlockedUser({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    this.reason,
    required this.createdAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as String,
      blockerId: json['blocker_id'] as String,
      blockedId:
          json['blocked_id'] as String? ?? json['blocked_user_id'] as String,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? json['blocked_at'] as String,
      ),
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MutedUser {
  final String id;
  final String muterId;
  final String mutedId;
  final String? reason;
  final DateTime createdAt;
  final DateTime? expiresAt;

  // Additional fields from joins
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  MutedUser({
    required this.id,
    required this.muterId,
    required this.mutedId,
    this.reason,
    required this.createdAt,
    this.expiresAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory MutedUser.fromJson(Map<String, dynamic> json) {
    return MutedUser(
      id: json['id'] as String,
      muterId: json['muter_id'] as String,
      mutedId: json['muted_id'] as String? ?? json['muted_user_id'] as String,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? json['muted_at'] as String,
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'muter_id': muterId,
      'muted_id': mutedId,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  bool get isPermanent => expiresAt == null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isActive => !isExpired;
}

// Report categories enum
class ReportCategory {
  static const String spam = 'spam';
  static const String harassment = 'harassment';
  static const String hateSpeech = 'hate_speech';
  static const String violence = 'violence';
  static const String nudity = 'nudity';
  static const String misinformation = 'misinformation';
  static const String copyright = 'copyright';
  static const String illegalGoods = 'illegal_goods';
  static const String selfHarm = 'self_harm';
  static const String impersonation = 'impersonation';
  static const String scamFraud = 'scam_fraud';
  static const String bullying = 'bullying';
  static const String other = 'other';

  static const List<String> all = [
    spam,
    harassment,
    hateSpeech,
    bullying,
    violence,
    selfHarm,
    nudity,
    misinformation,
    impersonation,
    scamFraud,
    illegalGoods,
    copyright,
    other,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case spam:
        return 'Spam';
      case harassment:
        return 'Harassment';
      case hateSpeech:
        return 'Hate Speech';
      case bullying:
        return 'Bullying';
      case violence:
        return 'Violence';
      case selfHarm:
        return 'Self-Harm or Suicide';
      case nudity:
        return 'Nudity or Sexual Content';
      case misinformation:
        return 'False Information';
      case impersonation:
        return 'Impersonation';
      case scamFraud:
        return 'Scam or Fraud';
      case illegalGoods:
        return 'Illegal Goods';
      case copyright:
        return 'Copyright Violation';
      case other:
        return 'Other';
      default:
        return category;
    }
  }
}

class Poll {
  final String id;
  final String messageId;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool allowMultipleVotes;
  final bool isAnonymous;

  Poll({
    required this.id,
    required this.messageId,
    required this.question,
    required this.options,
    required this.createdAt,
    this.expiresAt,
    this.allowMultipleVotes = false,
    this.isAnonymous = false,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List<dynamic>)
          .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      allowMultipleVotes: json['allow_multiple_votes'] as bool? ?? false,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'question': question,
      'options': options.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'allow_multiple_votes': allowMultipleVotes,
      'is_anonymous': isAnonymous,
    };
  }

  Poll copyWith({
    String? id,
    String? messageId,
    String? question,
    List<PollOption>? options,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? allowMultipleVotes,
    bool? isAnonymous,
  }) {
    return Poll(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      question: question ?? this.question,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      allowMultipleVotes: allowMultipleVotes ?? this.allowMultipleVotes,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  // Helper methods
  int get totalVotes => options.fold(0, (sum, option) => sum + option.votes);

  bool hasUserVoted(String userId) {
    return options.any((option) => option.voters.contains(userId));
  }

  List<String> getUserVotes(String userId) {
    return options
        .where((option) => option.voters.contains(userId))
        .map((option) => option.id)
        .toList();
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class PollOption {
  final String id;
  final String text;
  final int votes;
  final List<String> voters; // user IDs

  PollOption({
    required this.id,
    required this.text,
    this.votes = 0,
    this.voters = const [],
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String,
      text: json['text'] as String,
      votes: json['votes'] as int? ?? 0,
      voters:
          (json['voters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'votes': votes, 'voters': voters};
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? votes,
    List<String>? voters,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      voters: voters ?? this.voters,
    );
  }

  double getVotePercentage(int totalVotes) {
    if (totalVotes == 0) return 0.0;
    return (votes / totalVotes) * 100;
  }
}

class PollVote {
  final String id;
  final String pollId;
  final String userId;
  final String optionId;
  final DateTime votedAt;

  PollVote({
    required this.id,
    required this.pollId,
    required this.userId,
    required this.optionId,
    required this.votedAt,
  });

  factory PollVote.fromJson(Map<String, dynamic> json) {
    return PollVote(
      id: json['id'] as String,
      pollId: json['poll_id'] as String,
      userId: json['user_id'] as String,
      optionId: json['option_id'] as String,
      votedAt: DateTime.parse(json['voted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poll_id': pollId,
      'user_id': userId,
      'option_id': optionId,
      'voted_at': votedAt.toIso8601String(),
    };
  }
}

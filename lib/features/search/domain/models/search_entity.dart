class SearchResult {
  final String id;
  final String type; // 'user', 'post', 'hashtag'
  final String? title;
  final String? subtitle;
  final String? avatarUrl;
  final String? imageUrl;
  final DateTime? createdAt;

  SearchResult({
    required this.id,
    required this.type,
    this.title,
    this.subtitle,
    this.avatarUrl,
    this.imageUrl,
    this.createdAt,
  });

  factory SearchResult.fromUser(Map<String, dynamic> user) {
    return SearchResult(
      id: user['id'] as String,
      type: 'user',
      title: user['full_name'] as String? ?? user['username'] as String?,
      subtitle: '@${user['username']}',
      avatarUrl: user['avatar_url'] as String?,
    );
  }

  factory SearchResult.fromHashtag(Map<String, dynamic> hashtag) {
    return SearchResult(
      id: hashtag['id']?.toString() ?? hashtag['tag'] as String,
      type: 'hashtag',
      title: '#${hashtag['tag']}',
      subtitle: '${hashtag['post_count'] ?? 0} posts',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'avatarUrl': avatarUrl,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class Hashtag {
  final String tag;
  final int postCount;
  final DateTime? lastUsed;

  Hashtag({required this.tag, this.postCount = 0, this.lastUsed});

  factory Hashtag.fromJson(Map<String, dynamic> json) {
    return Hashtag(
      tag: json['tag'] as String,
      postCount: json['post_count'] as int? ?? 0,
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'post_count': postCount,
      'last_used': lastUsed?.toIso8601String(),
    };
  }
}

class UserCustomization {
  final String id;
  final String userId;
  final String itemType;
  final String itemId;
  final bool isActive;
  final DateTime purchasedAt;

  UserCustomization({
    required this.id,
    required this.userId,
    required this.itemType,
    required this.itemId,
    required this.isActive,
    required this.purchasedAt,
  });

  factory UserCustomization.fromJson(Map<String, dynamic> json) {
    return UserCustomization(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      itemType: json['item_type'] as String,
      itemId: json['item_id'] as String,
      isActive: json['is_active'] as bool? ?? false,
      purchasedAt: DateTime.parse(json['purchased_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_type': itemType,
      'item_id': itemId,
      'is_active': isActive,
      'purchased_at': purchasedAt.toIso8601String(),
    };
  }
}

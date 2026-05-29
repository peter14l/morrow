class AdCampaign {
  final String id;
  final String title;
  final String description;
  final String bannerUrl;
  final String destinationUrl;
  final String categoryTarget; // 'wellness', 'productivity', 'tech', 'feed'
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const AdCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.destinationUrl,
    required this.categoryTarget,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      bannerUrl: json['banner_url'] as String,
      destinationUrl: json['destination_url'] as String,
      categoryTarget: json['category_target'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

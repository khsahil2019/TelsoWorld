class StoryItem {
  final int id;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final String caption;
  final DateTime createdAt;
  final int viewsCount;

  StoryItem({
    required this.id,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.caption = '',
    required this.createdAt,
    this.viewsCount = 0,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      mediaUrl: json['media_url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'image',
      caption: json['caption']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      viewsCount: json['views_count'] is int
          ? json['views_count']
          : int.tryParse(json['views_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class UserStoryGroup {
  final int userId;
  final String username;
  final String name;
  final String profileImage;
  final List<StoryItem> stories;

  UserStoryGroup({
    required this.userId,
    required this.username,
    required this.name,
    required this.profileImage,
    required this.stories,
  });

  factory UserStoryGroup.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'] as List? ?? [];
    return UserStoryGroup(
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? 'creator',
      name: json['name']?.toString() ?? 'Creator',
      profileImage: json['profile_image']?.toString() ?? '',
      stories: rawStories
          .map((s) => StoryItem.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

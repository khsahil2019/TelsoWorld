class VideoModel {
  final int id;
  final String title;
  final String? subject;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? reporterName;
  final String? videoType;
  final int views;
  final int likes;
  final int sharesCount;
  final bool isLiked;
  final int commentsCount;

  VideoModel({
    required this.id,
    required this.title,
    this.subject,
    required this.videoUrl,
    this.thumbnailUrl,
    this.reporterName,
    this.videoType,
    this.views = 0,
    this.likes = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.commentsCount = 0,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final titleVal = json['name']?.toString() ?? json['subject']?.toString() ?? json['title']?.toString() ?? '';
    final urlVal = json['video_url']?.toString() ?? json['url']?.toString() ?? '';

    return VideoModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: titleVal,
      subject: json['subject']?.toString(),
      videoUrl: urlVal,
      thumbnailUrl: json['thumbnail_url']?.toString() ?? json['image']?.toString(),
      reporterName: json['reporter_name']?.toString() ?? json['username']?.toString(),
      videoType: json['video_type']?.toString(),
      views: json['view_count'] is int
          ? json['view_count']
          : (json['views'] is int ? json['views'] : int.tryParse((json['view_count'] ?? json['views'] ?? 0).toString()) ?? 0),
      likes: json['likes_count'] is int
          ? json['likes_count']
          : (json['likes'] is int ? json['likes'] : int.tryParse((json['likes_count'] ?? json['likes'] ?? 0).toString()) ?? 0),
      sharesCount: json['shares_count'] is int
          ? json['shares_count']
          : int.tryParse((json['shares_count'] ?? 0).toString()) ?? 0,
      isLiked: json['liked'] == true || json['is_liked'] == true || json['liked'] == 1,
      commentsCount: json['comments_count'] is int
          ? json['comments_count']
          : int.tryParse((json['comments_count'] ?? 0).toString()) ?? 0,
    );
  }

  VideoModel copyWith({
    int? id,
    String? title,
    String? subject,
    String? videoUrl,
    String? thumbnailUrl,
    String? reporterName,
    String? videoType,
    int? views,
    int? likes,
    int? sharesCount,
    bool? isLiked,
    int? commentsCount,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      reporterName: reporterName ?? this.reporterName,
      videoType: videoType ?? this.videoType,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}

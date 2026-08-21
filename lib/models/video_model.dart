class VideoModel {
  final int id;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? reporterName;
  final int views;
  final int likes;
  final bool isLiked;
  final int commentsCount;

  VideoModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    this.reporterName,
    this.views = 0,
    this.likes = 0,
    this.isLiked = false,
    this.commentsCount = 0,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? json['url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? json['image']?.toString(),
      reporterName: json['reporter_name']?.toString() ?? json['username']?.toString(),
      views: json['views'] is int ? json['views'] : int.tryParse(json['views'].toString()) ?? 0,
      likes: json['likes'] is int ? json['likes'] : int.tryParse(json['likes'].toString()) ?? 0,
      isLiked: json['is_liked'] == true || json['liked'] == 1,
      commentsCount: json['comments_count'] is int
          ? json['comments_count']
          : int.tryParse(json['comments_count'].toString()) ?? 0,
    );
  }

  VideoModel copyWith({
    int? id,
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    String? reporterName,
    int? views,
    int? likes,
    bool? isLiked,
    int? commentsCount,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      reporterName: reporterName ?? this.reporterName,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}

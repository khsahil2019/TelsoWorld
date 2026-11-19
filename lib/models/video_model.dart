class VideoModel {
  final int id;
  final int userId;
  final String title;
  final String? subject;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? photoUrl;
  final String? reporterName;
  final String? videoType;
  final String mediaType; // 'video' | 'photo'
  final bool hasAudio;
  final String? audioTitle;
  final int views;
  final int likes;
  final int sharesCount;
  final bool isLiked;
  final int commentsCount;

  VideoModel({
    required this.id,
    this.userId = 0,
    required this.title,
    this.subject,
    required this.videoUrl,
    this.thumbnailUrl,
    this.photoUrl,
    this.reporterName,
    this.videoType,
    this.mediaType = 'video',
    this.hasAudio = true,
    this.audioTitle,
    this.views = 0,
    this.likes = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.commentsCount = 0,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final titleVal = json['name']?.toString() ?? json['subject']?.toString() ?? json['title']?.toString() ?? '';
    final urlVal = json['video_url']?.toString() ?? json['video_path']?.toString() ?? json['url']?.toString() ?? '';
    final rawPhoto = (json['photo_url'] ?? json['image'] ?? json['thumbnail_url'] ?? '').toString().trim();
    final rawType = json['media_type']?.toString().toLowerCase().trim() ?? '';
    final isPhoto = rawType == 'photo' ||
        urlVal.toLowerCase().endsWith('.jpg') ||
        urlVal.toLowerCase().endsWith('.png') ||
        urlVal.toLowerCase().endsWith('.jpeg') ||
        urlVal.toLowerCase().endsWith('.webp');
    final resolvedPhoto = rawPhoto.isNotEmpty ? rawPhoto : (isPhoto ? urlVal : null);

    return VideoModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      title: titleVal,
      subject: json['subject']?.toString(),
      videoUrl: urlVal,
      thumbnailUrl: json['thumbnail_url']?.toString() ?? json['image']?.toString(),
      photoUrl: resolvedPhoto,
      reporterName: json['reporter_name']?.toString() ?? json['username']?.toString(),
      videoType: json['video_type']?.toString(),
      mediaType: isPhoto ? 'photo' : 'video',
      hasAudio: json['has_audio'] != false && json['has_audio'] != 'false',
      audioTitle: json['audio_title']?.toString(),
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
    int? userId,
    String? title,
    String? subject,
    String? videoUrl,
    String? thumbnailUrl,
    String? photoUrl,
    String? reporterName,
    String? videoType,
    String? mediaType,
    bool? hasAudio,
    String? audioTitle,
    int? views,
    int? likes,
    int? sharesCount,
    bool? isLiked,
    int? commentsCount,
  }) {
    return VideoModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      reporterName: reporterName ?? this.reporterName,
      videoType: videoType ?? this.videoType,
      mediaType: mediaType ?? this.mediaType,
      hasAudio: hasAudio ?? this.hasAudio,
      audioTitle: audioTitle ?? this.audioTitle,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}

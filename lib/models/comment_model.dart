class CommentModel {
  final int id;
  final String userName;
  final String content;
  final String? createdAt;
  final int likes;
  final bool isLiked;
  final List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.userName,
    required this.content,
    this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    var repliesList = <CommentModel>[];
    if (json['replies'] != null && json['replies'] is List) {
      repliesList = (json['replies'] as List)
          .map((r) => CommentModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return CommentModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userName: json['user_name']?.toString() ?? json['username']?.toString() ?? 'User',
      content: json['content']?.toString() ?? json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      likes: json['likes'] is int ? json['likes'] : int.tryParse(json['likes'].toString()) ?? 0,
      isLiked: json['is_liked'] == true,
      replies: repliesList,
    );
  }
}

class ChatMessageItem {
  final int id;
  final int conversationId;
  final int senderId;
  final int receiverId;
  final String senderUsername;
  final String senderName;
  final String senderAvatar;
  final String message;
  final String mediaUrl;
  final bool isMe;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.senderUsername,
    required this.senderName,
    required this.senderAvatar,
    required this.message,
    this.mediaUrl = '',
    required this.isMe,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      conversationId: json['conversation_id'] is int ? json['conversation_id'] : int.tryParse(json['conversation_id']?.toString() ?? '0') ?? 0,
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id']?.toString() ?? '0') ?? 0,
      receiverId: json['receiver_id'] is int ? json['receiver_id'] : int.tryParse(json['receiver_id']?.toString() ?? '0') ?? 0,
      senderUsername: json['sender_username']?.toString() ?? 'creator',
      senderName: json['sender_name']?.toString() ?? 'Creator',
      senderAvatar: json['sender_avatar']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString() ?? '',
      isMe: json['is_me'] == true,
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class ConversationItem {
  final int id;
  final int userId;
  final String username;
  final String name;
  final String avatar;
  final String status; // 'accepted' | 'pending' | 'declined' | 'blocked'
  final int initiatedBy;
  final bool isRequest;
  final String lastMessage;
  final String? lastMessageTime;

  ConversationItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.name,
    required this.avatar,
    required this.status,
    required this.initiatedBy,
    required this.isRequest,
    this.lastMessage = '',
    this.lastMessageTime,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? 'creator',
      name: json['name']?.toString() ?? 'Creator',
      avatar: json['avatar']?.toString() ?? '',
      status: json['status']?.toString() ?? 'accepted',
      initiatedBy: json['initiated_by'] is int ? json['initiated_by'] : int.tryParse(json['initiated_by']?.toString() ?? '0') ?? 0,
      isRequest: json['is_request'] == true,
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageTime: json['last_message_time']?.toString(),
    );
  }
}

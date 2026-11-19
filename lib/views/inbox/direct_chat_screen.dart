import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/models/message_model.dart';

class DirectChatScreen extends StatefulWidget {
  final ConversationItem conversation;

  const DirectChatScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageItem> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  late String _convStatus;
  late bool _isRequest;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _convStatus = widget.conversation.status;
    _isRequest = widget.conversation.isRequest;
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/messages/chat/${widget.conversation.id}');
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          final list = (data['data'] as List)
              .map((m) => ChatMessageItem.fromJson(m as Map<String, dynamic>))
              .toList();

          if (mounted) {
            setState(() {
              _messages = list;
              _isLoading = false;
            });
            _scrollToBottom();
          }
        }
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final token = await SessionTokenStore.getToken();
    if (token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to send messages', backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
      return;
    }

    setState(() => _isSending = true);
    _textController.clear();

    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/messages/send');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'receiver_id': widget.conversation.userId,
          'message': text,
        }),
      );

      final data = jsonDecode(res.body);
      if (data is Map) {
        if (data['status'] == false) {
          final msg = data['message']?.toString() ?? 'Message delivery blocked.';
          Get.snackbar(
            'Message Notice',
            msg,
            backgroundColor: const Color(0xFF222230),
            colorText: Colors.amberAccent,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
        } else {
          _fetchMessages(silent: true);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to send message: $e', backgroundColor: const Color(0xFF1E1E24), colorText: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _respondToRequest(String action) async {
    final token = await SessionTokenStore.getToken();
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/messages/respond/${widget.conversation.id}');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'action': action}),
      );

      final data = jsonDecode(res.body);
      if (data is Map && data['status'] == true) {
        if (action == 'accept') {
          setState(() {
            _convStatus = 'accepted';
            _isRequest = false;
          });
          Get.snackbar('Request Accepted! 🎉', 'You can now chat freely.', backgroundColor: const Color(0xFF161622), colorText: const Color(0xFF10B981));
        } else if (action == 'decline') {
          Get.snackbar('Request Declined', 'Conversation removed.', backgroundColor: const Color(0xFF161622), colorText: Colors.white70);
          Navigator.of(context).pop();
        } else if (action == 'block') {
          Get.snackbar('User Blocked 🚫', 'You will no longer see reels or messages from this creator.', backgroundColor: const Color(0xFF161622), colorText: Colors.redAccent);
          Navigator.of(context).pop();
        }
      }
    } catch (_) {}
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A26),
        title: Text('Block @${widget.conversation.username}?', style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'They won\'t be able to message you or view your profile. Their reels, stories, and messages will be hidden from you.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A6D)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/block/${widget.conversation.userId}');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = jsonDecode(res.body);
      if (data is Map && data['status'] == true) {
        Get.snackbar(
          'User Blocked 🚫',
          'Creator blocked. You will no longer see their reels or messages.',
          backgroundColor: const Color(0xFF1E1E24),
          colorText: Colors.redAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFD70F64),
              backgroundImage: conv.avatar.isNotEmpty
                  ? NetworkImage(ApiEndpoints.mediaUrl(conv.avatar))
                  : null,
              child: conv.avatar.isEmpty
                  ? Text(conv.name.isNotEmpty ? conv.name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${conv.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1C1C28),
            onSelected: (val) {
              if (val == 'block') _blockUser();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Color(0xFFFF2A6D), size: 18),
                    SizedBox(width: 10),
                    Text('Block User', style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // If this is a pending request, show Instagram message request banner
          if (_isRequest && _convStatus == 'pending')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF191926),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${conv.name} wants to send you a message. Accept to reply?',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () => _respondToRequest('block'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Block'),
                      ),
                      OutlinedButton(
                        onPressed: () => _respondToRequest('decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Decline'),
                      ),
                      ElevatedButton(
                        onPressed: () => _respondToRequest('accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD70F64),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD70F64)))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: const Color(0xFF222232),
                              backgroundImage: conv.avatar.isNotEmpty
                                  ? NetworkImage(ApiEndpoints.mediaUrl(conv.avatar))
                                  : null,
                              child: conv.avatar.isEmpty
                                  ? Text(conv.name.isNotEmpty ? conv.name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 24))
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(conv.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('@${conv.username}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 8),
                            const Text('Say hello to start chatting! 👋', style: TextStyle(color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),

          // Bottom message input
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F18),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD70F64)),
                          )
                        : const Icon(Icons.send_rounded, color: Color(0xFFD70F64)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg) {
    final isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD70F64) : const Color(0xFF232332),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

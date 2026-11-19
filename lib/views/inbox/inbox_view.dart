import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/models/message_model.dart';
import 'package:telsoworld/views/inbox/direct_chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<ConversationItem> _chats = [];
  List<ConversationItem> _requests = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInbox();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInbox({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/messages/inbox');
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is Map) {
          final rawChats = (data['data']['chats'] as List? ?? [])
              .map((c) => ConversationItem.fromJson(c as Map<String, dynamic>))
              .toList();
          final rawRequests = (data['data']['requests'] as List? ?? [])
              .map((c) => ConversationItem.fromJson(c as Map<String, dynamic>))
              .toList();

          if (mounted) {
            setState(() {
              _chats = rawChats;
              _requests = rawRequests;
              _isLoading = false;
            });
          }
        }
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _openStartChatModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              const Text('New Message', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Start a conversation with a creator', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              // Quick suggestions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _creatorChip(ctx, id: 8, name: 'Rahul Mishra', username: 'rahul_m'),
                  _creatorChip(ctx, id: 1, name: 'Telso Star', username: 'star_creator'),
                  _creatorChip(ctx, id: 3, name: 'Pooja Roy', username: 'pooja_r'),
                  _creatorChip(ctx, id: 4, name: 'Alex Telso', username: 'alex_t'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _creatorChip(BuildContext ctx, {required int id, required String name, required String username}) {
    return ActionChip(
      backgroundColor: const Color(0xFF222230),
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: const Color(0xFFD70F64),
        child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
      label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
      onPressed: () {
        Navigator.of(ctx).pop();
        final conv = ConversationItem(
          id: id,
          userId: id,
          username: username,
          name: name,
          avatar: '',
          status: 'pending',
          initiatedBy: 0,
          isRequest: false,
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DirectChatScreen(conversation: conv)),
        ).then((_) => _fetchInbox(silent: true));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredRequests = _requests.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.username.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D14),
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26),
            onPressed: _openStartChatModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD70F64),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            const Tab(text: 'Chats'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Requests'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD70F64),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search creators or messages...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD70F64)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Chats
                      RefreshIndicator(
                        onRefresh: () => _fetchInbox(silent: false),
                        color: const Color(0xFFD70F64),
                        child: filteredChats.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'No messages yet',
                                subtitle: 'Start a conversation with your favorite creators!',
                                actionLabel: 'Send a Message',
                                onAction: _openStartChatModal,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: filteredChats.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 76),
                                itemBuilder: (context, index) {
                                  final item = filteredChats[index];
                                  return _buildConversationTile(item);
                                },
                              ),
                      ),

                      // Tab 2: Requests
                      RefreshIndicator(
                        onRefresh: () => _fetchInbox(silent: false),
                        color: const Color(0xFFD70F64),
                        child: filteredRequests.isEmpty
                            ? _buildEmptyState(
                                icon: Icons.mail_outline_rounded,
                                title: 'No message requests',
                                subtitle: 'Messages from people you don\'t follow will appear here.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: filteredRequests.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 76),
                                itemBuilder: (context, index) {
                                  final item = filteredRequests[index];
                                  return _buildConversationTile(item);
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(ConversationItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DirectChatScreen(conversation: item)),
        ).then((_) => _fetchInbox(silent: true));
      },
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFD70F64),
            backgroundImage: item.avatar.isNotEmpty
                ? NetworkImage(ApiEndpoints.mediaUrl(item.avatar))
                : null,
            child: item.avatar.isEmpty
                ? Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  )
                : null,
          ),
          if (item.status == 'accepted')
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        item.lastMessage.isNotEmpty ? item.lastMessage : '@${item.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: item.isRequest ? Colors.amberAccent : Colors.white60,
          fontSize: 13,
        ),
      ),
      trailing: item.isRequest
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amberAccent),
              ),
              child: const Text('Request', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(icon, color: Colors.white54, size: 44),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD70F64),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

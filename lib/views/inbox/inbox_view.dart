import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activityFilter = 'All';

  String _myNote = '';

  final List<Map<String, dynamic>> _onlineUsers = [
    {
      'id': '1',
      'name': 'Sarah J.',
      'handle': '@sarah_j',
      'avatar': 'SJ',
      'color': const Color(0xFF8A2387),
      'hasStory': true,
      'isOnline': true,
      'note': 'Shooting a dance reel 🔥',
      'noteTime': '15m ago',
    },
    {
      'id': '4',
      'name': 'Alex Telso',
      'handle': '@alex_t',
      'avatar': 'AT',
      'color': const Color(0xFFE94057),
      'hasStory': true,
      'isOnline': true,
      'note': 'Live in 10 mins 🎬',
      'noteTime': '1h ago',
    },
    {
      'id': '5',
      'name': 'Pooja R.',
      'handle': '@pooja_r',
      'avatar': 'PR',
      'color': const Color(0xFFF27121),
      'hasStory': false,
      'isOnline': true,
      'note': 'Bhojpuri folk hits 🎶',
      'noteTime': '3h ago',
    },
    {
      'id': '3',
      'name': 'Rahul M.',
      'handle': '@rahul_m',
      'avatar': 'RM',
      'color': const Color(0xFF11998E),
      'hasStory': true,
      'isOnline': false,
      'note': 'Patna meetup today 🌟',
      'noteTime': '5h ago',
    },
    {
      'id': '6',
      'name': 'Neha S.',
      'handle': '@neha_s',
      'avatar': 'NS',
      'color': const Color(0xFF38EF7D),
      'hasStory': false,
      'isOnline': true,
      'note': 'New cover song out! 🎤',
      'noteTime': '8h ago',
    },
    {
      'id': '7',
      'name': 'Vikram K.',
      'handle': '@vikram_k',
      'avatar': 'VK',
      'color': const Color(0xFF2980B9),
      'hasStory': true,
      'isOnline': false,
      'note': 'Editing stage video ✂️',
      'noteTime': '10h ago',
    },
  ];

  final List<Map<String, dynamic>> _conversations = [
    {
      'id': '1',
      'name': 'Sarah Jenkins',
      'handle': '@sarah_j',
      'avatar': 'SJ',
      'color': const Color(0xFF8A2387),
      'lastMessage': 'Loved your latest reel! Super talent 🔥',
      'time': '2m ago',
      'unread': 2,
      'isOnline': true,
    },
    {
      'id': '2',
      'name': 'Telso Support',
      'handle': '@telso_team',
      'avatar': 'TS',
      'color': AppColors.primaryPink,
      'lastMessage': 'Your reward payout of ₹250 is credited! 🎉',
      'time': '1h ago',
      'unread': 1,
      'isOnline': true,
    },
    {
      'id': '3',
      'name': 'Rahul Mishra',
      'handle': '@rahul_m',
      'avatar': 'RM',
      'color': const Color(0xFF11998E),
      'lastMessage': 'Let’s collaborate on the folk dance video!',
      'time': '3h ago',
      'unread': 0,
      'isOnline': false,
    },
    {
      'id': '4',
      'name': 'Pooja Roy',
      'handle': '@pooja_roy',
      'avatar': 'PR',
      'color': const Color(0xFFF27121),
      'lastMessage': 'Thanks for sharing your referral code ❤️',
      'time': 'Yesterday',
      'unread': 0,
      'isOnline': true,
    },
    {
      'id': '5',
      'name': 'Vikram Kumar',
      'handle': '@vikram_k',
      'avatar': 'VK',
      'color': const Color(0xFF2980B9),
      'lastMessage': 'Check out this new song beat 🎵',
      'time': '2d ago',
      'unread': 0,
      'isOnline': false,
    },
  ];

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'n1',
      'type': 'payout',
      'title': 'Wallet Credit Successful',
      'message': '₹50.00 referral bonus credited to your wallet.',
      'time': '10m ago',
      'icon': Icons.account_balance_wallet_rounded,
      'iconColor': const Color(0xFF00E676),
      'isRead': false,
    },
    {
      'id': 'n2',
      'type': 'like',
      'title': 'New Likes on Reel',
      'message': 'Sarah Jenkins and 18 others liked your video.',
      'time': '1h ago',
      'icon': Icons.favorite_rounded,
      'iconColor': const Color(0xFFFF2A6D),
      'isRead': false,
    },
    {
      'id': 'n3',
      'type': 'follow',
      'title': 'New Follower',
      'message': 'Aman Gupta started following your profile.',
      'time': '3h ago',
      'icon': Icons.person_add_rounded,
      'iconColor': const Color(0xFF00E5FF),
      'isRead': true,
    },
    {
      'id': 'n4',
      'type': 'comment',
      'title': 'New Comment',
      'message': 'Neha Sharma: "Brilliant performance, keep shining!"',
      'time': 'Yesterday',
      'icon': Icons.chat_bubble_rounded,
      'iconColor': const Color(0xFFFFB300),
      'isRead': true,
    },
    {
      'id': 'n5',
      'type': 'system',
      'title': 'Creator Verification Alert',
      'message': 'Your reporter account has been verified officially.',
      'time': '2d ago',
      'icon': Icons.verified_rounded,
      'iconColor': const Color(0xFF7C4DFF),
      'isRead': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _markAllNotificationsRead() {
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });
    Get.snackbar(
      'Updated',
      'All notifications marked as read',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1E1E24),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifsCount = _notifications.where((n) => n['isRead'] == false).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Inbox',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white70, size: 22),
            tooltip: 'Mark all as read',
            onPressed: _markAllNotificationsRead,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(114),
          child: Column(
            children: [
              // 🔍 Interactive Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181822),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search messages, friends & alerts...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPink, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white60, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🌟 Vibrant Pink Glowing Tab Bar
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF161620),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD70F64).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_rounded, size: 16),
                          const SizedBox(width: 6),
                          const Text('Messages'),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '3',
                              style: TextStyle(
                                color: Color(0xFFD70F64),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_active_rounded, size: 16),
                          const SizedBox(width: 6),
                          const Text('Notifications'),
                          if (unreadNotifsCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadNotifsCount',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesView(),
          _buildNotificationsView(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Messages Tab View
  // ─────────────────────────────────────────
  Widget _buildMessagesView() {
    final filteredChats = _conversations.where((chat) {
      if (_searchQuery.isEmpty) return true;
      final name = chat['name']?.toString().toLowerCase() ?? '';
      final handle = chat['handle']?.toString().toLowerCase() ?? '';
      final msg = chat['lastMessage']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || handle.contains(q) || msg.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Online Stories & Notes Carousel (Only when search is empty)
        if (_searchQuery.isEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _onlineUsers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildAddStoryTile();
                final user = _onlineUsers[index - 1];
                return _buildUserStoryTile(user);
              },
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 6),
        ],

        if (filteredChats.isEmpty)
          _buildEmptyState('No conversations found for "$_searchQuery"')
        else
          ...filteredChats.map((chat) => _buildConversationTile(chat)),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Notes / Stories Tiles & Dialogs
  // ─────────────────────────────────────────
  Widget _buildAddStoryTile() {
    final hasCustomNote = _myNote.isNotEmpty;

    return GestureDetector(
      onTap: _openCreateNoteDialog,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            // Floating Mini Note Thought Bubble above avatar
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasCustomNote ? const Color(0xFF2C1926) : const Color(0xFF1E1E28),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasCustomNote ? AppColors.primaryPink.withOpacity(0.5) : Colors.white12,
                ),
              ),
              child: Center(
                child: Text(
                  hasCustomNote ? _myNote : '+ Note',
                  style: TextStyle(
                    color: hasCustomNote ? const Color(0xFFFF6584) : Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // User Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF22222C),
                    border: Border.all(
                      color: hasCustomNote ? AppColors.primaryPink : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryPink,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Note',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStoryTile(Map<String, dynamic> user) {
    final bool hasStory = user['hasStory'] == true;
    final bool isOnline = user['isOnline'] == true;
    final String note = user['note']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _openViewUserNoteDialog(user),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            // Floating Mini Note Thought Bubble above avatar
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF20162A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB388FF).withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  note.isNotEmpty ? note : 'Active',
                  style: const TextStyle(
                    color: Color(0xFFD1C4E9),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Avatar Ring
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory
                        ? const LinearGradient(
                            colors: [AppColors.primaryPink, Color(0xFFFF8008), Color(0xFFFFC837)],
                          )
                        : null,
                    border: !hasStory ? Border.all(color: Colors.white24, width: 1.5) : null,
                  ),
                  padding: EdgeInsets.all(hasStory ? 2.0 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user['color'] as Color,
                    ),
                    child: Center(
                      child: Text(
                        user['avatar'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                if (isOnline)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E676),
                      border: Border.all(color: const Color(0xFF0D0D12), width: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user['name'] as String,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateNoteDialog() {
    final noteCtrl = TextEditingController(text: _myNote);
    final moodShortcuts = [
      '🎵 Vibing to beats',
      '🎬 Shooting reel',
      '✨ Energetic',
      '☕ Coffee break',
      '🔥 New release soon',
      '✈️ Traveling',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💬 Share a Thought / Note',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your note will be visible to your followers for 24 hours at the top of Inbox.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Note Input Bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF20202E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryPink.withOpacity(0.3)),
                ),
                child: TextField(
                  controller: noteCtrl,
                  maxLength: 60,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'What\'s on your mind? (e.g. Shooting music reel 🎬)',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                    border: InputBorder.none,
                    counterStyle: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text('Quick Mood & Status:', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moodShortcuts.map((mood) {
                  return GestureDetector(
                    onTap: () {
                      noteCtrl.text = mood;
                      setModalState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262638),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        mood,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  if (_myNote.isNotEmpty)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _myNote = '';
                          });
                          Navigator.of(ctx).pop();
                          Get.snackbar('Note Deleted', 'Your note has been cleared.',
                              snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white70);
                        },
                        child: const Text('Delete Note', style: TextStyle(color: Colors.white60)),
                      ),
                    ),
                  if (_myNote.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        final text = noteCtrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          _myNote = text;
                        });
                        Navigator.of(ctx).pop();
                        Get.snackbar(
                          'Note Shared! ✨',
                          'Your note is now live on Inbox.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: const Color(0xFF1E1E24),
                          colorText: const Color(0xFF00E676),
                          duration: const Duration(seconds: 2),
                        );
                      },
                      child: const Text('Share Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openViewUserNoteDialog(Map<String, dynamic> user) {
    final String note = user['note']?.toString() ?? 'Active now';
    final String name = user['name']?.toString() ?? 'User';
    final String handle = user['handle']?.toString() ?? '@user';
    final String noteTime = user['noteTime']?.toString() ?? '1h ago';
    final replyCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user['color'] as Color,
                  ),
                  child: Center(
                    child: Text(
                      user['avatar'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        handle,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  noteTime,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Large Glowing Thought Bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF28152A), Color(0xFF1B182B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.primaryPink.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💭 Status Note', style: TextStyle(color: Color(0xFFFF6584), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Reply to Note Input Field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF242436),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Reply to $name...',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primaryPink, size: 20),
                    onPressed: () {
                      final text = replyCtrl.text.trim();
                      if (text.isEmpty) return;
                      Navigator.of(ctx).pop();

                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatDetailView(
                            userName: name,
                            userHandle: handle,
                            userColor: user['color'] as Color,
                            userAvatar: user['avatar'] as String,
                          ),
                        ),
                      );

                      Get.snackbar(
                        'Reply Sent',
                        'Replied to $name\'s note: "$text"',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF1E1E24),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> chat) {
    final unread = chat['unread'] as int;
    final isOnline = chat['isOnline'] == true;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatDetailView(
              userName: chat['name'] as String,
              userHandle: chat['handle'] as String,
              userColor: chat['color'] as Color,
              userAvatar: chat['avatar'] as String,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: chat['color'] as Color,
                  ),
                  child: Center(
                    child: Text(
                      chat['avatar'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                if (isOnline)
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E676),
                      border: Border.all(color: const Color(0xFF0D0D12), width: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat['name'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      Text(
                        chat['time'] as String,
                        style: TextStyle(
                          color: unread > 0 ? AppColors.primaryPink : Colors.white38,
                          fontSize: 12,
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['lastMessage'] as String,
                          style: TextStyle(
                            color: unread > 0 ? Colors.white.withOpacity(0.9) : Colors.white54,
                            fontSize: 13,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD70F64), Color(0xFFFF2A6D)],
                            ),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Notifications / Alerts Tab View
  // ─────────────────────────────────────────
  Widget _buildNotificationsView() {
    final filtered = _notifications.where((n) {
      if (_activityFilter != 'All' && n['type'].toString().toLowerCase() != _activityFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final title = n['title']?.toString().toLowerCase() ?? '';
      final msg = n['message']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || msg.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Payout', 'Like', 'Follow', 'Comment', 'System'].map((filter) {
              final isSelected = _activityFilter == filter;
              return GestureDetector(
                onTap: () => setState(() => _activityFilter = filter),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryPink : const Color(0xFF181822),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryPink : Colors.white10,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          _buildEmptyState('No notifications found')
        else
          ...filtered.map((item) => _buildNotificationTile(item)),
      ],
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> item) {
    final isRead = item['isRead'] == true;

    return GestureDetector(
      onTap: () {
        setState(() => item['isRead'] = true);
        Get.snackbar(
          item['title'] as String,
          item['message'] as String,
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF1E1E28),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF14141C) : const Color(0xFF1C1420),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.white.withOpacity(0.04) : AppColors.primaryPink.withOpacity(0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (item['iconColor'] as Color).withOpacity(0.12),
              ),
              child: Icon(item['icon'] as IconData, size: 22, color: item['iconColor'] as Color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                      Text(
                        item['time'] as String,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['message'] as String,
                    style: TextStyle(
                      color: isRead ? Colors.white60 : Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPink,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Interactive Direct Chat Detail View
// ─────────────────────────────────────────
class ChatDetailView extends StatefulWidget {
  final String userName;
  final String userHandle;
  final Color userColor;
  final String userAvatar;

  const ChatDetailView({
    super.key,
    required this.userName,
    required this.userHandle,
    required this.userColor,
    required this.userAvatar,
  });

  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'them',
      'text': 'Hey! Loved your latest performance video! 🎶',
      'time': '10:14 AM',
    },
    {
      'sender': 'me',
      'text': 'Thank you so much! Really appreciate your support 🙏',
      'time': '10:15 AM',
    },
    {
      'sender': 'them',
      'text': 'Are you planning another video soon on Telso World?',
      'time': '10:16 AM',
    },
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final nowStr = DateFormat('hh:mm a').format(DateTime.now());

    setState(() {
      _messages.add({
        'sender': 'me',
        'text': text,
        'time': nowStr,
      });
      _messageController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulated Auto-Reply for real interactive experience
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'sender': 'them',
          'text': 'Awesome! Looking forward to seeing more great content from you! 🎉',
          'time': DateFormat('hh:mm a').format(DateTime.now()),
        });
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14141C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.userColor),
              child: Center(
                child: Text(
                  widget.userAvatar,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Text('Active now', style: TextStyle(color: Color(0xFF00E676), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white),
            onPressed: () => Get.snackbar(
              'Call',
              'Connecting video call...',
              backgroundColor: const Color(0xFF1E1E24),
              colorText: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'me';

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [AppColors.primaryPink, Color(0xFFFF4081)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe ? null : const Color(0xFF1E1E28),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['text'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'] as String,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Message Composer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF14141C),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white70, size: 20),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E28),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryPink,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/core/constants/app_colors.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int initialTab; // 0: Followers, 1: Following

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialTab = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _fetchFollowers();
    _fetchFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowers() async {
    setState(() => _isLoadingFollowers = true);
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/followers/${widget.userId}');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          if (mounted) {
            setState(() {
              _followers = List<Map<String, dynamic>>.from(data['data']);
              _isLoadingFollowers = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFollowers = false);
  }

  Future<void> _fetchFollowing() async {
    setState(() => _isLoadingFollowing = true);
    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/following/${widget.userId}');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          if (mounted) {
            setState(() {
              _following = List<Map<String, dynamic>>.from(data['data']);
              _isLoadingFollowing = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingFollowing = false);
  }

  Future<void> _toggleFollowUser(Map<String, dynamic> user) async {
    final targetId = user['id'];
    final bool currentFollow = user['is_following'] == true;

    setState(() {
      user['is_following'] = !currentFollow;
    });

    try {
      final token = await SessionTokenStore.getToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/reporter/follow/$targetId');
      await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) {
        setState(() {
          user['is_following'] = currentFollow;
        });
      }
    }
  }

  Widget _buildUserList(List<Map<String, dynamic>> list, bool isLoading, String emptyLabel) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPink, strokeWidth: 2),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 54, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final u = list[index];
        final name = u['name']?.toString() ?? 'Creator';
        final username = u['username']?.toString() ?? 'creator';
        final avatar = u['profile_image']?.toString() ?? '';
        final bool isFollowing = u['is_following'] == true;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF1E1E24),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            username,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Text(
            name,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          trailing: ElevatedButton(
            onPressed: () => _toggleFollowUser(u),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? const Color(0xFF262626) : AppColors.primaryPink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          '@${widget.username}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryPink,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: '${_followers.length} Followers'),
            Tab(text: '${_following.length} Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followers, _isLoadingFollowers, 'No Followers Yet'),
          _buildUserList(_following, _isLoadingFollowing, 'Not Following Anyone Yet'),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/services/session_token_store.dart';
import 'package:telsoworld/views/wallet/withdraw_view.dart';

/// ---------------------------------------------------------------------------
/// 🎁 ReferralScreen (Clean, Easy & Intuitive Instagram-Style Referral Hub)
/// ---------------------------------------------------------------------------
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  String _referralCode = '';
  String _referralLink = '';
  int _totalReferrals = 0;
  double _totalEarnings = 0.0;
  List<dynamic> _levels = [];
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchReferralNetwork();
  }

  Future<void> _fetchReferralNetwork() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) {
        throw Exception('Please log in to view your referral network.');
      }

      final res = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/referral-network'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _referralCode = j['referral_code']?.toString() ?? '';
            _referralLink = j['referral_link']?.toString() ??
                'https://telsoworld.com/invite?ref=$_referralCode';
            _totalReferrals = _toInt(j['total_referrals']);
            _totalEarnings = _parseDouble(j['total_earnings'] ?? j['total_referral_earnings']);
            _levels = j['levels'] is List ? j['levels'] : [];
            _members = j['members'] is List
                ? j['members']
                : (j['referrals'] is List ? j['referrals'] : []);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load referral network (${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _copyCode() {
    if (_referralCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _referralCode));
    Get.snackbar(
      'Copied!',
      'Referral code "$_referralCode" copied to clipboard.',
      backgroundColor: const Color(0xFF1E1E24),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  void _shareOnWhatsApp() {
    final link = _referralLink.isNotEmpty
        ? _referralLink
        : 'https://telsoworld.com/invite?ref=$_referralCode';
    final msg =
        '🎁 Join Telso World using my referral code *$_referralCode* and earn real cash!\n'
        '💸 Earn ₹0.10 on every Ad Reel like + 5-Level team bonus (+₹0.05 per like)!\n'
        '👉 Join now: $link';
    Share.share(msg, subject: 'Join Telso World and Earn!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final cardBg = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF121212);
    final subTextColor = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF737373);
    final borderColor = isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Refer & Earn',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: textColor),
            onPressed: _shareOnWhatsApp,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textColor),
            onPressed: _fetchReferralNetwork,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPink))
          : _errorMessage != null
              ? _buildErrorView(isDark)
              : RefreshIndicator(
                  color: AppColors.primaryPink,
                  backgroundColor: cardBg,
                  onRefresh: _fetchReferralNetwork,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 🌟 1. Top Referral Hero Card (Code + Copy + WhatsApp)
                      _buildHeroCard(isDark),
                      const SizedBox(height: 16),

                      // 📊 2. Quick Stats Row (Total Friends & Total Earned)
                      _buildStatsRow(cardBg, textColor, subTextColor, borderColor),
                      const SizedBox(height: 20),

                      // ⚡ 3. Easy 3-Step "How It Works"
                      _buildHowItWorks(cardBg, textColor, subTextColor, borderColor),
                      const SizedBox(height: 22),

                      // 👥 4. 5-Level Earning Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '5-Level Team Earnings',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '+₹0.05 / Ad Like',
                            style: TextStyle(
                              color: AppColors.primaryPink,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildLevelsSummary(cardBg, textColor, subTextColor, borderColor),
                      const SizedBox(height: 22),

                      // 👫 5. Friends Under You (Downline Members)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Team Members',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_totalReferrals Friends',
                              style: const TextStyle(
                                color: AppColors.primaryPink,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_members.isEmpty)
                        _buildEmptyMembers(cardBg, textColor, subTextColor, borderColor)
                      else
                        ..._members.map((m) => _buildMemberTile(m, cardBg, textColor, subTextColor, borderColor)),

                      const SizedBox(height: 24),

                      // 💳 6. Withdraw Shortcut Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WithdrawScreen(
                                  currentBalance: _totalEarnings,
                                  onWithdrawSuccess: _fetchReferralNetwork,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                          label: const Text(
                            'Withdraw Earnings (UPI / Bank)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ── 1. Hero Card ──────────────────────────────────────
  Widget _buildHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE1306C), // Instagram gradient pink
            Color(0xFF833AB4), // Instagram gradient purple
            Color(0xFF405DE6), // Instagram gradient blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE1306C).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR REFERRAL CODE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Earn ₹0.05/like',
                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _referralCode.isNotEmpty ? _referralCode : 'TELSO2026',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                  onPressed: _copyCode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Two Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _shareOnWhatsApp,
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  label: const Text(
                    'Invite on WhatsApp',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _copyCode,
                child: const Text(
                  'Copy Code',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Quick Stats Row ────────────────────────────────
  Widget _buildStatsRow(Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3897F0).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_rounded, color: Color(0xFF3897F0), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text('Total Friends', style: TextStyle(color: subTextColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_totalReferrals',
                  style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text('Joined with your code', style: TextStyle(color: subTextColor, fontSize: 10)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF00E676), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text('Total Earned', style: TextStyle(color: subTextColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${_totalEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00C853), fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text('In your wallet', style: TextStyle(color: subTextColor, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Easy 3-Step "How It Works" ────────────────────
  Widget _buildHowItWorks(Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 8),
              Text(
                'How It Works (Easy 3 Steps)',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStepRow(
            '1',
            'Share Your Code',
            'Send your referral link or code to your friends on WhatsApp or Instagram.',
            const Color(0xFFE1306C),
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 10),
          _buildStepRow(
            '2',
            'Friends Like Ad Reels',
            'When your friends watch & like sponsored posts, they get ₹0.10 per like.',
            const Color(0xFF833AB4),
            textColor,
            subTextColor,
          ),
          const SizedBox(height: 10),
          _buildStepRow(
            '3',
            'You Get Paid up to 5 Levels',
            'You receive +₹0.05 instantly in your wallet for every like across 5 levels deep!',
            const Color(0xFF00C853),
            textColor,
            subTextColor,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(
    String step,
    String title,
    String desc,
    Color stepColor,
    Color textColor,
    Color subTextColor, {
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: stepColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: stepColor, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(color: stepColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: subTextColor, fontSize: 11.5, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 4. 5-Level Summary ───────────────────────────────
  Widget _buildLevelsSummary(Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    final Map<int, Map<String, dynamic>> defaultLevels = {
      1: {'level': 1, 'count': 0, 'earned': 0.0, 'name': 'Direct Friends (Level 1)'},
      2: {'level': 2, 'count': 0, 'earned': 0.0, 'name': 'Friends of Friends (Level 2)'},
      3: {'level': 3, 'count': 0, 'earned': 0.0, 'name': 'Level 3 Network'},
      4: {'level': 4, 'count': 0, 'earned': 0.0, 'name': 'Level 4 Network'},
      5: {'level': 5, 'count': 0, 'earned': 0.0, 'name': 'Level 5 Network'},
    };

    for (final l in _levels) {
      if (l is Map) {
        final lvl = _toInt(l['level']);
        if (defaultLevels.containsKey(lvl)) {
          defaultLevels[lvl]!['count'] = _toInt(l['count']);
          defaultLevels[lvl]!['earned'] = _parseDouble(l['total_earned']);
        }
      }
    }

    final colors = [
      const Color(0xFFE1306C),
      const Color(0xFF9C27B0),
      const Color(0xFF3F51B5),
      const Color(0xFF00BCD4),
      const Color(0xFFFF9800),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: defaultLevels.values.map((lvl) {
          final int num = lvl['level'];
          final int count = lvl['count'];
          final double earned = lvl['earned'];
          final color = colors[num - 1];
          final bool isLast = num == 5;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'L$num',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lvl['name'],
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      Text(
                        '$count ${count == 1 ? "friend" : "friends"} joined',
                        style: TextStyle(color: subTextColor, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+₹${earned.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text('earned', style: TextStyle(color: subTextColor, fontSize: 9.5)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 5. Member Tile ───────────────────────────────────
  Widget _buildMemberTile(
    dynamic item,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color borderColor,
  ) {
    final m = item is Map ? item : {};
    final name = m['name']?.toString() ?? 'Creator';
    final username = m['username']?.toString() ?? '';
    final level = _toInt(m['level']);
    final joinedAt = _formatDate(m['joined_at']);
    final earned = _parseDouble(m['earned_from_user'] ?? m['earned']);
    final avatar = m['profile_image']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryPink.withValues(alpha: 0.15),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Level $level',
                        style: const TextStyle(color: AppColors.primaryPink, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  username.isNotEmpty ? '@$username' : (joinedAt.isNotEmpty ? joinedAt : 'Active Member'),
                  style: TextStyle(color: subTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+₹${earned.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────
  Widget _buildEmptyMembers(Color cardBg, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: subTextColor),
          const SizedBox(height: 10),
          Text(
            'No friends joined yet',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Share your referral code to build your 5-level team and start earning cash!',
            textAlign: TextAlign.center,
            style: TextStyle(color: subTextColor, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _shareOnWhatsApp,
            icon: const Icon(Icons.share_rounded, color: Colors.white, size: 16),
            label: const Text('Share Code Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Error State ──────────────────────────────────────
  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF5252)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load referrals',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _fetchReferralNetwork,
              child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }
}

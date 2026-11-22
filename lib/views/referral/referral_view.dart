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
  List<dynamic> _recentTransactions = [];

  // Toggle for Earning Guide Language (Hindi / English)
  bool _isHindiGuide = true;

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
            _recentTransactions =
                j['recent_transactions'] is List ? j['recent_transactions'] : [];
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
        '🎁 Join Telso World using my referral code *$_referralCode* and earn real rewards!\n'
        '💸 Earn ₹0.10 on every Ad Reel like, and 5-Level team commissions (+₹0.05 per like)!\n'
        '👉 Join now: $link';
    Share.share(msg, subject: 'Join Telso World and Earn!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF16161E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF14141E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Referral & Team Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareOnWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchReferralNetwork,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPink))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: AppColors.primaryPink,
                  onRefresh: _fetchReferralNetwork,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 🌟 Hero Referral Code Card
                      _buildHeroCard(),
                      const SizedBox(height: 18),

                      // 📊 Performance Metrics (Total Team & Total Earnings)
                      _buildMetricsRow(cardBg, textColor),
                      const SizedBox(height: 20),

                      // 🌳 5-Level Hierarchy Chain
                      Text(
                        '5-Level Downline Chain (L1 to L5)',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      _buildLevelCards(cardBg, textColor),
                      const SizedBox(height: 22),

                      // 📘 Complete Infographic Guide (Matching the Infographic: विस्तृत उदाहरण)
                      _buildVisualInfographicCard(cardBg, textColor, isDark),
                      const SizedBox(height: 24),

                      // 👥 Downline Members Under You
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Members Under You',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPink.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_totalReferrals Users',
                              style: const TextStyle(color: AppColors.primaryPink, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_members.isEmpty)
                        _buildEmptyMembers(cardBg, textColor)
                      else
                        ..._members.map((m) => _buildMemberCard(m, cardBg, textColor)),

                      const SizedBox(height: 24),

                      // 🧾 Real-Time Referral Earning Live Logs
                      if (_recentTransactions.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 18, color: Color(0xFF00E676)),
                            const SizedBox(width: 8),
                            Text(
                              'Referral Earnings Live Audit Log',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._recentTransactions.take(10).map((t) => _buildTxLogCard(t, cardBg, textColor)),
                        const SizedBox(height: 24),
                      ],

                      // 💡 Quick Summary Rules Card
                      _buildRulesCard(cardBg, textColor),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5E17EB),
            Color(0xFF381273),
            Color(0xFF1E083B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E17EB).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Exclusive Referral Code',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Invite friends & earn ₹0.05 per Ad like up to 5 Levels',
                      style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Glowing Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _referralCode.isNotEmpty ? _referralCode : 'TELSO2026',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Code',
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 22),
                  onPressed: _copyCode,
                ),
                IconButton(
                  tooltip: 'WhatsApp Invite',
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 22),
                  onPressed: _shareOnWhatsApp,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _shareOnWhatsApp,
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Share on WhatsApp',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _copyCode,
                icon: const Icon(Icons.content_copy_rounded, color: Colors.white, size: 18),
                label: const Text('Copy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(Color cardBg, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3897F0).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: Color(0xFF3897F0), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('Total Downlines', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_totalReferrals',
                  style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text('Across 5 Levels', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF00E676), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('Total Earned', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₹${_totalEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text('Added to Wallet', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCards(Color cardBg, Color textColor) {
    final Map<int, Map<String, dynamic>> defaultLevels = {
      1: {'level': 1, 'count': 0, 'total_earned': 0.0, 'label': 'Level 1 (Direct Referrals)', 'color': const Color(0xFFFF2A6D)},
      2: {'level': 2, 'count': 0, 'total_earned': 0.0, 'label': 'Level 2 Downline', 'color': const Color(0xFF9C27B0)},
      3: {'level': 3, 'count': 0, 'total_earned': 0.0, 'label': 'Level 3 Downline', 'color': const Color(0xFF3F51B5)},
      4: {'level': 4, 'count': 0, 'total_earned': 0.0, 'label': 'Level 4 Downline', 'color': const Color(0xFF00BCD4)},
      5: {'level': 5, 'count': 0, 'total_earned': 0.0, 'label': 'Level 5 Downline', 'color': const Color(0xFFFF9800)},
    };

    for (final l in _levels) {
      if (l is Map) {
        final lvl = _toInt(l['level']);
        if (defaultLevels.containsKey(lvl)) {
          defaultLevels[lvl]!['count'] = _toInt(l['count']);
          defaultLevels[lvl]!['total_earned'] = _parseDouble(l['total_earned']);
        }
      }
    }

    return Column(
      children: defaultLevels.values.map((lvl) {
        final int levelNum = lvl['level'];
        final int count = lvl['count'];
        final double earned = lvl['total_earned'];
        final Color col = lvl['color'];
        final String label = lvl['label'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: col.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: col, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text('L$levelNum', style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                          child: const Text('+₹0.05 / Ad Like', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count ${count == 1 ? "member" : "members"} in this tier',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+₹${earned.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Text('earned', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📘 Complete Infographic Guide (Matches User's Infographic Exactly)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVisualInfographicCard(Color cardBg, Color textColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF5E17EB).withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E17EB).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Purple Top Banner Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [Color(0xFF5E17EB), Color(0xFF3B0764)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_rounded, color: Color(0xFFFFD54F), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isHindiGuide
                        ? 'विस्तृत उदाहरण: जब Level 5 (E) Post Like करता है, Earning कैसे मिलती है?'
                        : 'Detailed Example: How 5-Level Earning is Distributed When Level 5 Likes a Post',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
                // Language Pill Toggle
                InkWell(
                  onTap: () => setState(() => _isHindiGuide = !_isHindiGuide),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isHindiGuide ? '🇮🇳 हिंदी' : '🌐 EN',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Referral Chain Vertical Flow
                Text(
                  _isHindiGuide ? '🔗 रेफरल हाइयरार्की (Referral Chain):' : '🔗 Referral Hierarchy Chain:',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                _buildHierarchyChain(isDark),
                const SizedBox(height: 18),

                // 2. Step-by-Step Flow (1 to 5)
                Text(
                  _isHindiGuide ? '⚡ Step-by-Step पूरा फ़्लो:' : '⚡ Step-by-Step Execution Flow:',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                _buildStepItem('1', Icons.thumb_up_alt_rounded, const Color(0xFF5E17EB),
                  _isHindiGuide ? 'पोस्ट को Like' : 'Post Liked',
                  _isHindiGuide ? 'Level 5 (E) किसी Ad Reel या Post पर Like करता है।' : 'Level 5 user (E) likes a sponsored Ad Reel / Post.',
                ),
                _buildStepItem('2', Icons.memory_rounded, const Color(0xFF00BCD4),
                  _isHindiGuide ? 'सिस्टम प्रोसेस (Upline Trace)' : 'System Processes Upline Tree',
                  _isHindiGuide ? 'सिस्टम E के रेफरल ट्री को ऊपर की ओर 5 Levels तक तुरंत ट्रेस करता है।' : 'System traces up the upline tree of E up to 5 levels (D, C, B, A, You).',
                ),
                _buildStepItem('3', Icons.calculate_rounded, const Color(0xFFFF9800),
                  _isHindiGuide ? 'रिवॉर्ड कैलकुलेशन' : 'Reward Calculation Rule',
                  _isHindiGuide ? 'E को ₹0.10 (Self) और उसके 5 अपलाइन (D, C, B, A और आप) को ₹0.05-₹0.05 दिया जाता है।' : 'Liking user (E) gets ₹0.10, and each of the 5 uplines gets ₹0.05 each.',
                ),
                _buildStepItem('4', Icons.account_balance_wallet_rounded, const Color(0xFF00E676),
                  _isHindiGuide ? 'वॉलेट में क्रेडिट' : 'Instant Wallet Credit',
                  _isHindiGuide ? 'यह राशि संबंधित सभी यूज़र्स के वॉलेट में रियल-टाइम में तुरंत क्रेडिट हो जाती है।' : 'All credited balances are updated instantly in real-time wallets.',
                ),
                _buildStepItem('5', Icons.receipt_long_rounded, const Color(0xFF9C27B0),
                  _isHindiGuide ? 'ट्रांजेक्शन रिकॉर्ड' : 'Transaction History Record',
                  _isHindiGuide ? 'हर क्रेडिट का रिकॉर्ड ट्रांजेक्शन हिस्ट्री में सुरक्षित हो जाता है (कौन, कारण, राशि)।' : 'Full audit trail with description, timestamp, and amount saved to database.',
                  isLast: true,
                ),
                const SizedBox(height: 18),

                // 3. Earning Breakdown Table (6 users -> ₹0.35 total)
                Text(
                  _isHindiGuide ? '📊 Earning का वितरण (Breakdown Table):' : '📊 Payout Distribution Breakdown:',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                _buildBreakdownTable(isDark),
                const SizedBox(height: 18),

                // 4. "इससे क्या समझें?" Callout Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFD54F), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isHindiGuide ? '💡 इससे क्या समझें?' : '💡 Key Insights:',
                            style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint(_isHindiGuide ? 'E को – ₹0.10 (10 पैसे) मिलते हैं।' : 'E (who liked) gets ₹0.10 (10 Paise).'),
                      _buildBulletPoint(_isHindiGuide ? 'D, C, B, A और आपको – प्रत्येक को ₹0.05 (5 पैसे) मिलते हैं।' : 'D, C, B, A and You – each receives ₹0.05 (5 Paise).'),
                      _buildBulletPoint(_isHindiGuide ? 'कुल 6 लोगों के बीच ₹0.35 (35 पैसे) का रिवॉर्ड वितरित होता है।' : 'Total reward of ₹0.35 (35 Paise) is distributed across 6 people.'),
                      _buildBulletPoint(_isHindiGuide ? 'यह रिवॉर्ड हर Like पर तुरंत और अपने-आप (Automatic) मिलता है।' : 'This reward is granted automatically and instantaneously on every Ad like.'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Business Rules Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isHindiGuide ? '⚙️ नियम (Business Rules) का सारांश:' : '⚙️ Summary of Business Rules:',
                            style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBulletPoint(_isHindiGuide ? 'यूज़र बिना रेफरल कोड या किसी के रेफरल कोड से रजिस्टर कर सकता है।' : 'Users can sign up directly or with a referral code.'),
                      _buildBulletPoint(_isHindiGuide ? 'हर Like पर Like करने वाले यूज़र को ₹0.10 (10 पैसे) मिलते हैं।' : 'Liking user earns ₹0.10 on eligible sponsored posts.'),
                      _buildBulletPoint(_isHindiGuide ? 'उसके ऊपर के अधिकतम 5 Levels तक प्रत्येक को ₹0.05 (5 पैसे) मिलते हैं।' : 'Up to 5 upline levels earn ₹0.05 each.'),
                      _buildBulletPoint(_isHindiGuide ? 'Level 5 से ऊपर (Level 6 या उससे अधिक) को कोई रिवॉर्ड नहीं मिलता।' : 'Levels beyond 5 (Level 6+) receive zero reward (capped).'),
                      _buildBulletPoint(_isHindiGuide ? 'रिवॉर्ड तुरंत यूज़र के वॉलेट में क्रेडिट किया जाता है।' : 'All earnings are credited in real-time to the DB wallet.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyChain(bool isDark) {
    final List<Map<String, String>> chain = [
      {'title': _isHindiGuide ? 'आप (You) - Level 0' : 'You - Level 0', 'sub': _isHindiGuide ? 'Root Creator' : 'Root Creator', 'color': '0xFFFF2A6D'},
      {'title': 'A - Level 1', 'sub': _isHindiGuide ? 'आपके रेफरल से जुड़ा' : 'Referred directly by You', 'color': '0xFF9C27B0'},
      {'title': 'B - Level 2', 'sub': _isHindiGuide ? 'A के रेफरल से जुड़ा' : 'Referred by A', 'color': '0xFF3F51B5'},
      {'title': 'C - Level 3', 'sub': _isHindiGuide ? 'B के रेफरल से जुड़ा' : 'Referred by B', 'color': '0xFF00BCD4'},
      {'title': 'D - Level 4', 'sub': _isHindiGuide ? 'C के रेफरल से जुड़ा' : 'Referred by C', 'color': '0xFFFF9800'},
      {'title': 'E - Level 5', 'sub': _isHindiGuide ? 'D के रेफरल से जुड़ा (Like करने वाला)' : 'Referred by D (Likes Post)', 'color': '0xFF00E676'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F1F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: chain.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final color = Color(int.parse(item['color']!));
          final isLast = idx == chain.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
                    alignment: Alignment.center,
                    child: Text('${idx == 0 ? "★" : idx}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  if (!isLast)
                    Container(width: 2, height: 16, color: Colors.white24),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Row(
                    children: [
                      Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '(${item['sub']!})',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepItem(String num, IconData icon, Color color, String title, String desc, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: color),
            ),
            if (!isLast)
              Container(width: 2, height: 26, color: Colors.white12),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('Step $num', style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownTable(bool isDark) {
    final List<Map<String, String>> rows = [
      {'rank': '1', 'user': 'E', 'relation': _isHindiGuide ? 'जिसने Like किया (Self)' : 'Who Liked (Self)', 'amount': '₹0.10 (10 पैसे)'},
      {'rank': '2', 'user': 'D', 'relation': _isHindiGuide ? 'E का L1 / आपका L4' : 'E’s L1 / Your L4', 'amount': '₹0.05 (5 पैसे)'},
      {'rank': '3', 'user': 'C', 'relation': _isHindiGuide ? 'E का L2 / आपका L3' : 'E’s L2 / Your L3', 'amount': '₹0.05 (5 पैसे)'},
      {'rank': '4', 'user': 'B', 'relation': _isHindiGuide ? 'E का L3 / आपका L2' : 'E’s L3 / Your L2', 'amount': '₹0.05 (5 पैसे)'},
      {'rank': '5', 'user': 'A', 'relation': _isHindiGuide ? 'E का L4 / आपका L1' : 'E’s L4 / Your L1', 'amount': '₹0.05 (5 पैसे)'},
      {'rank': '6', 'user': _isHindiGuide ? 'आप (You)' : 'You', 'relation': _isHindiGuide ? 'E का L5 / Root User' : 'E’s L5 / Root User', 'amount': '₹0.05 (5 पैसे)'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F1F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20, child: Text('#', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(width: 55, child: Text('User', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
                Expanded(child: Text(_isHindiGuide ? 'रिलेशन (संबंध)' : 'Relation', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
                Text(_isHindiGuide ? 'मिली राशि' : 'Reward', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Rows
          ...rows.map((r) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              children: [
                SizedBox(width: 20, child: Text(r['rank']!, style: const TextStyle(color: Colors.white54, fontSize: 11))),
                SizedBox(
                  width: 55,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.primaryPink.withValues(alpha: 0.3),
                        child: Text(r['user']![0], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                      Text(r['user']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(child: Text(r['relation']!, style: const TextStyle(color: Colors.white70, fontSize: 10.5))),
                Text(
                  r['amount']!,
                  style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ],
            ),
          )),
          // Total Summary Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isHindiGuide ? 'कुल वितरित राशि (Total Payout)' : 'Total Distributed Payout',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Text(
                  '₹0.35 (35 पैसे)',
                  style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildTxLogCard(dynamic tx, Color cardBg, Color textColor) {
    final t = tx is Map ? tx : {};
    final title = t['title']?.toString() ?? 'Referral Bonus';
    final desc = t['description']?.toString() ?? '';
    final amount = _parseDouble(t['amount']);
    final date = _formatDate(t['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF00E676), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(date, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(dynamic item, Color cardBg, Color textColor) {
    final m = item is Map ? item : {};
    final name = m['name']?.toString() ?? 'Creator';
    final username = m['username']?.toString() ?? '';
    final level = _toInt(m['level']);
    final joinedAt = _formatDate(m['joined_at']);
    final earned = _parseDouble(m['earned_from_user'] ?? m['earned']);
    final avatar = m['profile_image']?.toString() ?? '';

    Color badgeColor = const Color(0xFFFF2A6D);
    if (level == 2) badgeColor = const Color(0xFF9C27B0);
    if (level == 3) badgeColor = const Color(0xFF3F51B5);
    if (level == 4) badgeColor = const Color(0xFF00BCD4);
    if (level >= 5) badgeColor = const Color(0xFFFF9800);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: badgeColor.withValues(alpha: 0.2),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: Text(
                        'Level $level',
                        style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (username.isNotEmpty)
                  Text('@$username', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (joinedAt.isNotEmpty)
                  Text('Joined: $joinedAt', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+₹${earned.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const Text('Added to you', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMembers(Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.group_add_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text('No Referrals Yet', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Share your referral code. When anyone up to Level 5 likes an Ad Reel, ₹0.05 is added instantly to your wallet!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPink,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _shareOnWhatsApp,
            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
            label: const Text('Invite Friends Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard(Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFFFD54F), size: 18),
              SizedBox(width: 8),
              Text(
                'How 5-Level Referral Works (Business Rules)',
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleStep('1', 'Ad Reel Like Reward (Self)', 'When you or anyone likes an Ad Reel, the liking user receives ₹0.10 directly into their wallet.'),
          _buildRuleStep('2', 'Up to 5 Levels Upline Distribution', 'The system traces up to 5 levels above the user. Each upline (Level 1 to Level 5) gets ₹0.05 credited per like.'),
          _buildRuleStep('3', 'Instant Real-Time Payouts', 'All balances update automatically in the real database wallet with complete transaction transparency.'),
          _buildRuleStep('4', 'Sponsored Posts Only', 'Rewards apply exclusively to Ad Reels and promoted posts, ensuring high advertising value and preventing abuse.'),
        ],
      ),
    );
  }

  Widget _buildRuleStep(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: Color(0xFF261822), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(step, style: const TextStyle(color: AppColors.primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFFF5252)),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Failed to load referral data', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _fetchReferralNetwork,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return iso.toString();
    }
  }
}

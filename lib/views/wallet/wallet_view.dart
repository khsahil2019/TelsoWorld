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

class WalletScreen extends StatefulWidget {
  final int initialTabIndex;
  const WalletScreen({super.key, this.initialTabIndex = 0});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _hideBalance = false;
  String? _errorMessage;
  Map<String, dynamic>? _walletData;
  List<dynamic> _transactions = [];

  // 👥 5-Level Referral Network Data
  Map<String, dynamic>? _referralData;
  List<dynamic> _referralMembers = [];
  List<dynamic> _referralLevels = [];
  String _referralCode = '';
  String _referralLink = '';
  double _totalReferralEarnings = 0.0;
  int _totalReferrals = 0;

  String _filter = 'ALL'; // ALL, CREDIT, DEBIT

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) {
        throw Exception('Please log in to access your wallet & referrals.');
      }

      // Parallel fetch wallet data and referral hierarchy
      final walletFuture = http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/wallet'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      final referralFuture = http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/referral-network'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      final responses = await Future.wait([walletFuture, referralFuture]);
      final walletRes = responses[0];
      final refRes = responses[1];

      if (walletRes.statusCode == 200) {
        final Map<String, dynamic> wJson = jsonDecode(walletRes.body);
        _walletData = wJson;
        _transactions = wJson['transactions'] is List
            ? wJson['transactions']
            : (wJson['data'] is List ? wJson['data'] : []);
      }

      if (refRes.statusCode == 200) {
        final Map<String, dynamic> rJson = jsonDecode(refRes.body);
        _referralData = rJson;
        _referralCode = rJson['referral_code']?.toString() ?? '';
        _referralLink = rJson['referral_link']?.toString() ??
            'https://telsoworld.com/invite?ref=$_referralCode';
        _totalReferrals = _toInt(rJson['total_referrals']);
        _totalReferralEarnings = _parseDouble(rJson['total_earnings'] ?? rJson['total_referral_earnings']);
        _referralMembers = rJson['members'] is List
            ? rJson['members']
            : (rJson['referrals'] is List ? rJson['referrals'] : []);
        _referralLevels = rJson['levels'] is List ? rJson['levels'] : [];
      }

      if (mounted) {
        setState(() => _isLoading = false);
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

  String _formatAmount(dynamic val) {
    final amount = _parseDouble(val);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return formatter.format(amount);
  }

  String _formatDate(dynamic val) {
    if (val == null || val.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  void _copyReferralCode() {
    if (_referralCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _referralCode));
    Get.snackbar(
      'Copied!',
      'Referral code "$_referralCode" copied to clipboard.',
      backgroundColor: const Color(0xFF1E1E24),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
    );
  }

  void _shareReferral() {
    final link = _referralLink.isNotEmpty
        ? _referralLink
        : 'https://telsoworld.com/invite?ref=$_referralCode';
    final msg =
        '🎁 Join Telso World with my referral code *$_referralCode* and earn real rewards on Ad Reels!\n'
        '💸 Earn ₹0.10 on every Ad Reel like, and 5-Level Upline bonuses (+₹0.05 per like)!\n'
        '👉 Join now: $link';
    Share.share(msg, subject: 'Join Telso World and Earn!');
  }

  void _showWithdrawDialog(double availableBalance) {
    final TextEditingController upiCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController(
      text: availableBalance >= 100 ? '100' : availableBalance.toStringAsFixed(0),
    );

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppColors.primaryPink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Instant UPI Withdrawal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Available: ${_formatAmount(availableBalance)} • Min payout: ₹100',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: upiCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'UPI ID (e.g. mobile@upi, name@okaxis)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF222230),
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Withdrawal Amount (₹)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF222230),
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final upi = upiCtrl.text.trim();
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (upi.isEmpty || !upi.contains('@')) {
                      Get.snackbar('Invalid UPI', 'Please enter a valid UPI ID',
                          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
                      return;
                    }
                    if (amt < 100) {
                      Get.snackbar('Minimum ₹100', 'Minimum withdrawal threshold is ₹100.00',
                          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
                      return;
                    }
                    if (amt > availableBalance) {
                      Get.snackbar('Insufficient Balance', 'Requested amount exceeds your wallet balance.',
                          backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
                      return;
                    }
                    Get.back();
                    Get.snackbar(
                      'Request Submitted! 🚀',
                      'Withdrawal of ₹${amt.toStringAsFixed(2)} to $upi has been submitted for admin processing.',
                      backgroundColor: const Color(0xFF1E1E24),
                      colorText: const Color(0xFF00E676),
                      duration: const Duration(seconds: 4),
                    );
                  },
                  child: const Text(
                    'Confirm Payout Request',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final credit = _parseDouble(_walletData?['total_credit'] ?? _walletData?['credit']);
    final debit = _parseDouble(_walletData?['total_debit'] ?? _walletData?['debit']);
    final balance = credit - debit;

    final filteredList = _transactions.where((item) {
      if (item is! Map) return true;
      final type = item['type']?.toString().toUpperCase() ?? '';
      if (_filter == 'CREDIT') return type.contains('CR') || type.contains('CREDIT');
      if (_filter == 'DEBIT') return type.contains('DR') || type.contains('DEBIT');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Telso Financial Hub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchAllData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD70F64), Color(0xFFFF4081)],
                ),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Wallet & Payouts'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hub_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('5-Level Referral'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPink))
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Wallet & Transactions
                    _buildWalletTab(balance, credit, debit, filteredList),

                    // Tab 2: 5-Level Referral Network & Earnings Tree
                    _buildReferralNetworkTab(),
                  ],
                ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // TAB 1: WALLET & TRANSACTIONS
  // ───────────────────────────────────────────────────────────
  Widget _buildWalletTab(
    double balance,
    double credit,
    double debit,
    List<dynamic> filteredList,
  ) {
    return RefreshIndicator(
      color: AppColors.primaryPink,
      backgroundColor: const Color(0xFF1E1E24),
      onRefresh: _fetchAllData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 🌟 Balance Card
          _buildBalanceCard(balance, credit, debit),
          const SizedBox(height: 18),

          // Quick Action Buttons
          _buildActionButtons(balance),
          const SizedBox(height: 22),

          // Filter Chips Row & Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Transaction History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip('ALL'),
                  const SizedBox(width: 4),
                  _buildFilterChip('CREDIT'),
                  const SizedBox(width: 4),
                  _buildFilterChip('DEBIT'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Transactions List
          if (filteredList.isEmpty)
            _buildEmptyTransactions()
          else
            ...filteredList.map((tx) => _buildTransactionCard(tx)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double credit, double debit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD70F64),
            Color(0xFF8E0E45),
            Color(0xFF2A081B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Available Balance',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _hideBalance
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _hideBalance = !_hideBalance),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _hideBalance ? '₹ • • • • •' : _formatAmount(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward_rounded,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Credit',
                            style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(
                          _hideBalance ? '₹ • • •' : _formatAmount(credit),
                          style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(width: 1, height: 26, color: Colors.white12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Debit',
                            style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(
                          _hideBalance ? '₹ • • •' : _formatAmount(debit),
                          style: const TextStyle(
                              color: Color(0xFFFF8A80),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(double balance) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.payments_rounded,
            label: 'Withdraw',
            gradient: const [Color(0xFFD70F64), Color(0xFFFF4081)],
            onTap: () => _showWithdrawDialog(balance),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.share_rounded,
            label: 'Invite Friends',
            gradient: const [Color(0xFF2C2C38), Color(0xFF1E1E28)],
            onTap: () {
              _tabController.animateTo(1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPink : const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryPink : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(dynamic item) {
    final tx = item is Map ? item : {};
    final isCredit = tx['type']?.toString().toUpperCase().contains('CR') == true ||
        tx['type']?.toString().toUpperCase().contains('CREDIT') == true ||
        (tx['amount'] != null && _parseDouble(tx['amount']) > 0 && tx['type'] == null);

    final title = tx['title']?.toString() ??
        tx['description']?.toString() ??
        (isCredit ? 'Reward Credited' : 'Withdrawal');
    final desc = tx['description']?.toString() ?? '';
    final amount = tx['amount'] != null ? _formatAmount(tx['amount']) : '₹0.00';
    final dateStr = _formatDate(tx['created_at'] ?? tx['date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFF00C853).withValues(alpha: 0.12)
                  : const Color(0xFFFF5252).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isCredit ? const Color(0xFF00E676) : const Color(0xFFFF5252),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (desc.isNotEmpty && desc != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isCredit ? '+$amount' : '-$amount',
            style: TextStyle(
              color: isCredit ? const Color(0xFF00E676) : const Color(0xFFFF5252),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text('No transactions found', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // TAB 2: 5-LEVEL REFERRAL NETWORK & DOWNLINE EARNINGS TREE
  // ───────────────────────────────────────────────────────────
  Widget _buildReferralNetworkTab() {
    return RefreshIndicator(
      color: AppColors.primaryPink,
      backgroundColor: const Color(0xFF1E1E24),
      onRefresh: _fetchAllData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 🎁 Referral Code Sharing Hero Card
          _buildReferralCodeCard(),
          const SizedBox(height: 18),

          // 📊 Network Overview Metrics (Total Downlines & Total Earnings)
          _buildNetworkOverviewMetrics(),
          const SizedBox(height: 20),

          // 🌳 5-Level Hierarchy Visual Cards (Levels 1 to 5)
          const Text(
            '5-Level Referral Chain (Level 1 to 5)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _build5LevelHierarchyCards(),
          const SizedBox(height: 24),

          // 📜 Downline Members List ("Who used your referral & their earnings added")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Members Under You',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryPink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_totalReferrals total',
                  style: const TextStyle(
                    color: AppColors.primaryPink,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_referralMembers.isEmpty)
            _buildEmptyReferrals()
          else
            ..._referralMembers.map((m) => _buildMemberCard(m)),

          const SizedBox(height: 24),

          // 💡 How 5-Level Referral Earning Works Card (Matches Infographic)
          _buildHowItWorksCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A148C),
            Color(0xFF2E0854),
            Color(0xFF17032D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
            blurRadius: 18,
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
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Exclusive Referral Code',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Share & Earn ₹0.05 on Every Downline Like',
                      style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Referral Code Box with Copy & Share
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _referralCode.isNotEmpty ? _referralCode : 'TELSO2026',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy Code',
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                  onPressed: _copyReferralCode,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Share on WhatsApp',
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
                  onPressed: _shareReferral,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _shareReferral,
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  label: const Text(
                    'WhatsApp Invite',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _copyReferralCode,
                icon: const Icon(Icons.content_copy_rounded, color: Colors.white, size: 16),
                label: const Text(
                  'Copy',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOverviewMetrics() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16161E),
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
                    const Text('Total Team', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_totalReferrals',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
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
              color: const Color(0xFF16161E),
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
                    const Text('Team Earnings', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatAmount(_totalReferralEarnings),
                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                const Text('Real-time Credited', style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _build5LevelHierarchyCards() {
    final Map<int, Map<String, dynamic>> defaultLevels = {
      1: {'level': 1, 'count': 0, 'total_earned': 0.0, 'label': 'Level 1 (Direct)', 'color': const Color(0xFFFF2A6D)},
      2: {'level': 2, 'count': 0, 'total_earned': 0.0, 'label': 'Level 2', 'color': const Color(0xFF9C27B0)},
      3: {'level': 3, 'count': 0, 'total_earned': 0.0, 'label': 'Level 3', 'color': const Color(0xFF3F51B5)},
      4: {'level': 4, 'count': 0, 'total_earned': 0.0, 'label': 'Level 4', 'color': const Color(0xFF00BCD4)},
      5: {'level': 5, 'count': 0, 'total_earned': 0.0, 'label': 'Level 5', 'color': const Color(0xFFFF9800)},
    };

    for (final l in _referralLevels) {
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
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: col.withValues(alpha: 0.2)),
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
                child: Text(
                  'L$levelNum',
                  style: TextStyle(
                    color: col,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '+₹0.05 / Ad Like',
                            style: TextStyle(color: Colors.white70, fontSize: 9.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count ${count == 1 ? "member" : "members"} joined under this level',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+₹${earned.toFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildMemberCard(dynamic item) {
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
        color: const Color(0xFF16161E),
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
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
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
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                if (joinedAt.isNotEmpty)
                  Text(
                    'Joined: $joinedAt',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
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
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'Added to you',
                  style: TextStyle(color: Colors.white54, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReferrals() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          const Icon(Icons.group_add_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            'No Referrals Yet',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share your referral code with friends and family. Whenever anyone in your 5-level network likes an Ad Reel, you earn ₹0.05 instantly!',
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
            onPressed: _shareReferral,
            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
            label: const Text('Invite First Friend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
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
                'How 5-Level Earning Works (Business Rules)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleStep(
            step: '1',
            title: 'Ad Reel Liking Reward (Self)',
            desc: 'When you or anyone likes an Ad Reel, the user who liked gets ₹0.10 (10 paise) credited directly into their wallet.',
          ),
          _buildRuleStep(
            step: '2',
            title: 'Up to 5 Levels Upline Distribution',
            desc: 'The system automatically traces up to 5 levels above the user. Every upline (Level 1 to Level 5) receives ₹0.05 (5 paise) per like.',
          ),
          _buildRuleStep(
            step: '3',
            title: 'Real-Time Database Wallet Credits',
            desc: 'All earnings are credited in real-time to PostgreSQL wallets, with complete transparent transaction history.',
          ),
          _buildRuleStep(
            step: '4',
            title: 'Ad Reels & Posts Only',
            desc: 'Earnings are generated exclusively on sponsored Ad Reels and posts, protecting against abuse while ensuring genuine advertiser value.',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleStep({
    required String step,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF261822),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.primaryPink,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                ),
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
            Text(
              _errorMessage ?? 'Failed to load wallet & referrals',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPink,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _fetchAllData,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

extension DoubleFormat on double {
  String toFixed(int digits) => toStringAsFixed(digits);
}

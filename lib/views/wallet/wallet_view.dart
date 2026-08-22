import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/services/session_token_store.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  bool _hideBalance = false;
  String? _errorMessage;
  Map<String, dynamic>? _walletData;
  List<dynamic> _transactions = [];

  String _filter = 'ALL'; // ALL, CREDIT, DEBIT

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) {
        throw Exception('Please log in to access your wallet.');
      }

      final response = await http.get(
        Uri.parse('https://telsoworld.com/api/reporter/wallet'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _walletData = json;
            _transactions = json['transactions'] is List
                ? json['transactions']
                : (json['data'] is List ? json['data'] : []);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
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
          'Telso Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchWallet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPink))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: AppColors.primaryPink,
                  backgroundColor: const Color(0xFF1E1E24),
                  onRefresh: _fetchWallet,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // 🌟 Luxury Fintech Balance Card
                      _buildBalanceCard(balance, credit, debit),
                      const SizedBox(height: 20),

                      // Quick Action Buttons
                      _buildActionButtons(),
                      const SizedBox(height: 24),

                      // Filter Chips Row & Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Recent Transactions',
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
            color: AppColors.primaryPink.withOpacity(0.35),
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
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Available Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
              color: Colors.black.withOpacity(0.25),
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
                      child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Credit', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(
                          _hideBalance ? '₹ • • •' : _formatAmount(credit),
                          style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.bold),
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
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Debit', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(
                          _hideBalance ? '₹ • • •' : _formatAmount(debit),
                          style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13, fontWeight: FontWeight.bold),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.payments_rounded,
            label: 'Withdraw',
            gradient: const [Color(0xFFD70F64), Color(0xFFFF4081)],
            onTap: () {
              Get.snackbar(
                'Withdrawal Request',
                'Withdrawal feature is being processed. Minimum payout ₹100.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF1E1E24),
                colorText: Colors.white,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.history_rounded,
            label: 'Statement',
            gradient: const [Color(0xFF2C2C38), Color(0xFF1E1E28)],
            onTap: _fetchWallet,
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
              color: gradient.first.withOpacity(0.3),
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
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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

    final title = tx['title']?.toString() ?? tx['description']?.toString() ?? (isCredit ? 'Reward Credited' : 'Withdrawal');
    final amount = tx['amount'] != null ? _formatAmount(tx['amount']) : '₹0.00';
    final dateStr = tx['created_at']?.toString() ?? tx['date']?.toString() ?? 'Recent';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit ? const Color(0xFF00C853).withOpacity(0.12) : const Color(0xFFFF5252).withOpacity(0.12),
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
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
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
      child: Column(
        children: const [
          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text('No transactions found', style: TextStyle(color: Colors.white54, fontSize: 14)),
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
              _errorMessage ?? 'Failed to load wallet',
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
              onPressed: _fetchWallet,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

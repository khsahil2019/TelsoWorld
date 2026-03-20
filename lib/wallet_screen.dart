import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:telsoworld/session_token_store.dart';

const _kPink = Color(0xFFD70F64);
const _kCardBg = Color(0xFFE8185A);

// ─────────────────────────────────────────
// Logic
// ─────────────────────────────────────────
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  WalletResponse? _wallet;

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
        throw Exception('Login token not found. Please login again.');
      }

      final response = await http
          .get(
            Uri.parse('https://telsoworld.com/api/reporter/wallet'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 25));

      debugPrint('=== WALLET API RESPONSE ===');
      debugPrint('Status Code : ${response.statusCode}');
      debugPrint('Body        : ${response.body}');
      debugPrint('===========================');

      if (response.statusCode != 200) {
        throw Exception('Wallet fetch failed (${response.statusCode}).');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final wallet = WalletResponse.fromJson(json);

      if (!wallet.status) {
        throw Exception('Wallet data not available.');
      }

      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(String value) {
    final amount = double.tryParse(value) ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _currentBalance() {
    final credit = double.tryParse(_wallet?.totalCredit ?? '0') ?? 0;
    final debit = double.tryParse(_wallet?.totalDebit ?? '0') ?? 0;
    return '₹${(credit - debit).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;

    return Scaffold(
      backgroundColor: _kPink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Wallet Transactions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchWallet,
                color: _kPink,
                child: _isLoading
                    ? const _WalletLoadingView()
                    : _errorMessage != null
                    ? _WalletErrorView(
                        message: _errorMessage!,
                        onRetry: _fetchWallet,
                      )
                    : wallet == null
                    ? _WalletErrorView(
                        message: 'Wallet data not found.',
                        onRetry: _fetchWallet,
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TotalIncomeCard(
                              amount: _formatCurrency(wallet.totalIncome),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'TOTAL CREDIT',
                                    amount: _formatCurrency(wallet.totalCredit),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'TOTAL DEBIT',
                                    amount: _formatCurrency(wallet.totalDebit),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Transaction History',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'FILTER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (wallet.transactions.isEmpty)
                              const _EmptyTransactionsView()
                            else
                              ...List.generate(wallet.transactions.length, (
                                index,
                              ) {
                                final tx = wallet.transactions[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        index == wallet.transactions.length - 1
                                        ? 0
                                        : 12,
                                  ),
                                  child: _TransactionTile(
                                    transaction: tx,
                                    amount: _formatCurrency(tx.amountRaw),
                                  ),
                                );
                              }),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              color: _kCardBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Final Current Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        wallet == null ? '₹0.00' : _currentBalance(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kPink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                      ),
                      child: const Text(
                        'Add Money',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Model
// ─────────────────────────────────────────
class WalletResponse {
  final bool status;
  final String totalIncome;
  final String totalCredit;
  final String totalDebit;
  final List<WalletTransaction> transactions;

  const WalletResponse({
    required this.status,
    required this.totalIncome,
    required this.totalCredit,
    required this.totalDebit,
    required this.transactions,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'] as List<dynamic>? ?? [];

    return WalletResponse(
      status: json['status'] == true,
      totalIncome: json['total_income']?.toString() ?? '0',
      totalCredit: json['total_credit']?.toString() ?? '0',
      totalDebit: json['total_debit']?.toString() ?? '0',
      transactions: rawTransactions
          .map(
            (item) => WalletTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class WalletTransaction {
  final int index;
  final int id;
  final String type;
  final String amount;
  final String amountRaw;
  final String sign;
  final String refType;
  final String refTypeLabel;
  final int userId;
  final String description;
  final String date;
  final String time;
  final String createdAt;

  const WalletTransaction({
    required this.index,
    required this.id,
    required this.type,
    required this.amount,
    required this.amountRaw,
    required this.sign,
    required this.refType,
    required this.refTypeLabel,
    required this.userId,
    required this.description,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      index: json['index'] as int? ?? 0,
      id: json['id'] as int? ?? 0,
      type: json['type']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      amountRaw:
          json['amount_raw']?.toString() ?? json['amount']?.toString() ?? '0',
      sign: json['sign']?.toString() ?? '',
      refType: json['ref_type']?.toString() ?? '',
      refTypeLabel: json['ref_type_label']?.toString() ?? '',
      userId: json['user_id'] as int? ?? 0,
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  bool get isCredit => type.toLowerCase() == 'credit';

  String get formattedDateTime {
    if (date.isEmpty && time.isEmpty) return '';
    if (date.isEmpty) return time;
    if (time.isEmpty) return date;
    return '$date • $time';
  }

  String get title {
    if (description.isNotEmpty) return description;
    return 'Transaction #$id';
  }

  String get subtitle {
    final parts = <String>[];
    if (refTypeLabel.isNotEmpty) parts.add(refTypeLabel);
    if (userId > 0) parts.add('User ID: $userId');
    if (id > 0) parts.add('Txn ID: $id');
    return parts.join(' | ');
  }

  IconData get icon {
    switch (refType.toLowerCase()) {
      case 'web_link':
        return Icons.language_rounded;
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return isCredit
            ? Icons.arrow_downward_rounded
            : Icons.arrow_upward_rounded;
    }
  }

  String get badgeLabel => isCredit ? 'SUCCESS' : 'DEBIT';
}

// ─────────────────────────────────────────
// UI
// ─────────────────────────────────────────
class _WalletLoadingView extends StatelessWidget {
  const _WalletLoadingView();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 500,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}

class _WalletErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WalletErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 500,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _kPink,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactionsView extends StatelessWidget {
  const _EmptyTransactionsView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: Color(0xFF9E9E9E), size: 32),
          SizedBox(height: 10),
          Text(
            'No transactions found',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalIncomeCard extends StatelessWidget {
  final String amount;

  const _TotalIncomeCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: Colors.white.withOpacity(0.85),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'TOTAL INCOME',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;

  const _SummaryCard({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final String amount;

  const _TransactionTile({required this.transaction, required this.amount});

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isCredit
        ? const Color(0xFF1DB954)
        : const Color(0xFF1A1A1A);
    final statusColor = transaction.isCredit
        ? const Color(0xFF1DB954)
        : const Color(0xFF888888);
    final statusBg = transaction.isCredit
        ? const Color(0xFFE8F8EF)
        : const Color(0xFFF0F0F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kPink.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(transaction.icon, color: _kPink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.formattedDateTime,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.sign}$amount',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  transaction.badgeLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

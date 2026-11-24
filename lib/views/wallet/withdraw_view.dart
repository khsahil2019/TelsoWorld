import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:telsoworld/core/constants/api_endpoints.dart';
import 'package:telsoworld/core/constants/app_colors.dart';
import 'package:telsoworld/core/services/session_token_store.dart';

class WithdrawScreen extends StatefulWidget {
  final double currentBalance;
  final VoidCallback? onWithdrawSuccess;

  const WithdrawScreen({
    super.key,
    required this.currentBalance,
    this.onWithdrawSuccess,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen>
    with SingleTickerProviderStateMixin {
  late TabController _methodTabController;
  final TextEditingController _amountCtrl = TextEditingController();

  // UPI Fields
  final TextEditingController _upiIdCtrl = TextEditingController();
  final TextEditingController _upiNameCtrl = TextEditingController();

  // Bank Fields
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankHolderCtrl = TextEditingController();
  final TextEditingController _bankAccountCtrl = TextEditingController();
  final TextEditingController _bankConfirmAccountCtrl = TextEditingController();
  final TextEditingController _bankIfscCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingHistory = true;
  List<dynamic> _withdrawalsHistory = [];
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _balance = widget.currentBalance;
    _amountCtrl.text = _balance >= 100 ? '100' : _balance.toStringAsFixed(0);
    _methodTabController = TabController(length: 2, vsync: this);
    _fetchWithdrawalsHistory();
  }

  @override
  void dispose() {
    _methodTabController.dispose();
    _amountCtrl.dispose();
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankHolderCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankConfirmAccountCtrl.dispose();
    _bankIfscCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchWithdrawalsHistory() async {
    try {
      final token = await SessionTokenStore.getToken();
      if (token.isEmpty) return;

      final res = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/withdrawals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (mounted && j['withdrawals'] is List) {
          setState(() {
            _withdrawalsHistory = j['withdrawals'];
            _isLoadingHistory = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _selectQuickAmount(double amount) {
    setState(() {
      _amountCtrl.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _submitWithdrawal() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount < 100.0) {
      Get.snackbar(
        'Minimum ₹100 Required',
        'Minimum withdrawal amount is ₹100.00.',
        backgroundColor: const Color(0xFF1E1E24),
        colorText: const Color(0xFFFF5252),
      );
      return;
    }
    if (amount > _balance) {
      Get.snackbar(
        'Insufficient Balance',
        'You have ₹${_balance.toStringAsFixed(2)} available. Please enter a lower amount.',
        backgroundColor: const Color(0xFF1E1E24),
        colorText: const Color(0xFFFF5252),
      );
      return;
    }

    final isUpi = _methodTabController.index == 0;
    Map<String, dynamic> payload = {
      'amount': amount,
      'payout_method': isUpi ? 'upi' : 'bank',
    };

    if (isUpi) {
      final upi = _upiIdCtrl.text.trim();
      final name = _upiNameCtrl.text.trim();
      if (upi.isEmpty || !upi.contains('@')) {
        Get.snackbar('Invalid UPI ID', 'Please enter a valid UPI address (e.g. mobile@upi)',
            backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
        return;
      }
      payload['upi_id'] = upi;
      payload['account_holder'] = name;
    } else {
      final bankName = _bankNameCtrl.text.trim();
      final holder = _bankHolderCtrl.text.trim();
      final acct = _bankAccountCtrl.text.trim();
      final confirm = _bankConfirmAccountCtrl.text.trim();
      final ifsc = _bankIfscCtrl.text.trim().toUpperCase();

      if (holder.isEmpty) {
        Get.snackbar('Missing Name', 'Please enter Account Holder Name.',
            backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
        return;
      }
      if (acct.isEmpty || acct.length < 8) {
        Get.snackbar('Invalid Account Number', 'Please enter a valid bank account number.',
            backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
        return;
      }
      if (acct != confirm) {
        Get.snackbar('Account Mismatch', 'Account numbers do not match. Please re-check.',
            backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
        return;
      }
      if (ifsc.isEmpty || ifsc.length < 5) {
        Get.snackbar('Invalid IFSC', 'Please enter a valid 11-character IFSC code.',
            backgroundColor: const Color(0xFF1E1E24), colorText: Colors.white);
        return;
      }

      payload['bank_name'] = bankName.isNotEmpty ? bankName : 'Bank Transfer';
      payload['account_holder'] = holder;
      payload['account_number'] = acct;
      payload['ifsc_code'] = ifsc;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await SessionTokenStore.getToken();
      final res = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/reporter/withdraw'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      final j = jsonDecode(res.body);
      if (res.statusCode == 200 && j['status'] == true) {
        setState(() {
          _balance = (_balance - amount).clamp(0.0, double.infinity);
        });
        widget.onWithdrawSuccess?.call();
        _showSuccessDialog(amount, isUpi ? 'UPI: ${_upiIdCtrl.text.trim()}' : 'Bank: ${_bankNameCtrl.text.trim()}');
        _fetchWithdrawalsHistory();
      } else {
        throw Exception(j['message'] ?? 'Withdrawal failed');
      }
    } catch (e) {
      Get.snackbar(
        'Submission Failed',
        e.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFF1E1E24),
        colorText: const Color(0xFFFF5252),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(double amount, String destination) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Withdrawal Initiated! 🚀',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(2)} is being processed for transfer to $destination.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined, color: Color(0xFFFFD54F), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Credits usually reflect in your account within 1 to 24 business hours.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final inputBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF);
    final textColor = isDark ? Colors.white : const Color(0xFF121212);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 🌟 Balance Card
          _buildBalanceHero(),
          const SizedBox(height: 20),

          // 💳 Method Selection Tabs (UPI vs Direct Bank)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A24) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _methodTabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD70F64), Color(0xFFFF4081)],
                ),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flash_on_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('UPI Transfer'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Direct Bank'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 📝 Input Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdrawal Amount (₹)',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primaryPink),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickChip(100),
                    _buildQuickChip(200),
                    _buildQuickChip(500),
                    _buildQuickChip(1000),
                    if (_balance > 0)
                      GestureDetector(
                        onTap: () => _selectQuickAmount(_balance),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryPink),
                          ),
                          child: const Text('All Balance', style: TextStyle(color: AppColors.primaryPink, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Dynamic Form: Tab 0 (UPI) vs Tab 1 (Bank)
                AnimatedBuilder(
                  animation: _methodTabController,
                  builder: (_, __) {
                    final isUpi = _methodTabController.index == 0;
                    return isUpi ? _buildUpiFields(inputBg, textColor) : _buildBankFields(inputBg, textColor);
                  },
                ),
                const SizedBox(height: 22),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSubmitting ? null : _submitWithdrawal,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Withdrawal Request',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 📜 Withdrawal History
          Text('Past Withdrawals', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _isLoadingHistory
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPink))
              : _withdrawalsHistory.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Text('No withdrawal requests yet.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                    )
                  : Column(children: _withdrawalsHistory.map((w) => _buildHistoryItem(w, cardBg, textColor)).toList()),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBalanceHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFD70F64), Color(0xFF8E0E45), Color(0xFF2A081B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available For Instant Payout', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '₹${_balance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF00E676), size: 14),
              SizedBox(width: 4),
              Text('Minimum withdrawal ₹100.00 • Zero fees', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(double amt) {
    return GestureDetector(
      onTap: () => _selectQuickAmount(amt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Text('+₹${amt.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildUpiFields(Color inputBg, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UPI ID / VPA', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _upiIdCtrl,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. 9876543210@paytm or user@okhdfcbank',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text('Account Holder / Beneficiary Name', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _upiNameCtrl,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Name as registered on UPI',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildBankFields(Color inputBg, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account Holder Name', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _bankHolderCtrl,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Name as on bank passbook',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.person_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text('Bank Name', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _bankNameCtrl,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. State Bank of India, HDFC',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.account_balance_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text('Bank Account Number', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _bankAccountCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter 9-18 digit account number',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.tag_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text('Confirm Bank Account Number', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _bankConfirmAccountCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Re-enter account number',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.tag_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text('IFSC Code', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _bankIfscCtrl,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: 'e.g. SBIN0001234',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: inputBg,
            prefixIcon: const Icon(Icons.domain_rounded, color: Colors.white54, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(dynamic item, Color cardBg, Color textColor) {
    final w = item is Map ? item : {};
    final amt = double.tryParse(w['amount']?.toString() ?? '0') ?? 0.0;
    final status = (w['status']?.toString() ?? 'pending').toLowerCase();
    final method = (w['payout_method']?.toString() ?? 'upi').toUpperCase();
    final date = w['created_at']?.toString() ?? '';

    Color statusColor = const Color(0xFFFFB300);
    String statusLabel = 'Processing';
    if (status == 'completed' || status == 'approved') {
      statusColor = const Color(0xFF00E676);
      statusLabel = 'Transferred';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFFF5252);
      statusLabel = 'Rejected';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              method == 'UPI' ? Icons.flash_on_rounded : Icons.account_balance_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$method Payout: ₹${amt.toStringAsFixed(2)}',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(date),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class WalletModel {
  final double balance;
  final double pendingAmount;
  final List<TransactionModel> transactions;

  WalletModel({
    required this.balance,
    required this.pendingAmount,
    this.transactions = const [],
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    var txList = <TransactionModel>[];
    if (json['transactions'] != null && json['transactions'] is List) {
      txList = (json['transactions'] as List)
          .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    return WalletModel(
      balance: double.tryParse(json['balance'].toString()) ?? 0.0,
      pendingAmount: double.tryParse(json['pending_amount'].toString()) ?? 0.0,
      transactions: txList,
    );
  }
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final String date;
  final String status;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.status,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['description']?.toString() ?? 'Transaction',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      date: json['created_at']?.toString() ?? json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'completed',
    );
  }
}

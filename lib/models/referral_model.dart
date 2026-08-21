class ReferralModel {
  final String referralCode;
  final String referralLink;
  final int totalReferrals;
  final double totalEarnings;

  ReferralModel({
    required this.referralCode,
    required this.referralLink,
    this.totalReferrals = 0,
    this.totalEarnings = 0.0,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      referralCode: json['referral_code']?.toString() ?? '',
      referralLink: json['referral_link']?.toString() ?? '',
      totalReferrals: json['total_referrals'] is int
          ? json['total_referrals']
          : int.tryParse(json['total_referrals'].toString()) ?? 0,
      totalEarnings: double.tryParse(json['total_earnings'].toString()) ?? 0.0,
    );
  }
}

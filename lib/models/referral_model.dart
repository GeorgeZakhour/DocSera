class ReferralModel {
  final String id;
  final String? referredName;
  final String? completedAt;
  final int pointsAwarded;

  ReferralModel({
    required this.id,
    this.referredName,
    this.completedAt,
    this.pointsAwarded = 25,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] as String,
      referredName: json['referred_name'] as String?,
      completedAt: json['completed_at'] as String?,
      pointsAwarded: json['points_awarded'] as int? ?? 25,
    );
  }
}

class ReferralInfo {
  final String referralCode;
  final int totalReferrals;
  final int totalPointsEarned;
  final List<ReferralModel> recentReferrals;

  ReferralInfo({
    required this.referralCode,
    required this.totalReferrals,
    required this.totalPointsEarned,
    required this.recentReferrals,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    final referrals = (json['recent_referrals'] as List<dynamic>?)
        ?.map((e) => ReferralModel.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return ReferralInfo(
      referralCode: json['referral_code'] as String,
      totalReferrals: json['total_referrals'] as int? ?? 0,
      totalPointsEarned: json['total_points_earned'] as int? ?? 0,
      recentReferrals: referrals,
    );
  }
}

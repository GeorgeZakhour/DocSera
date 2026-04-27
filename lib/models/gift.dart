class Gift {
  final String claimId;
  final String promotionId;
  final String voucherCode;
  final String status; // 'claimed' | 'used' | 'expired'
  final DateTime claimedAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String insightType; // 'birthday', 'lapsed', etc.
  final String? message;
  final DateTime sentAt;
  final String doctorId;
  final String doctorName;
  final String? doctorImage;
  final String offerType;
  final String? customTitle;
  final String? customTitleAr;
  final String? description;
  final String? descriptionAr;
  final double? discountValue;
  final String? discountType;

  const Gift({
    required this.claimId,
    required this.promotionId,
    required this.voucherCode,
    required this.status,
    required this.claimedAt,
    this.expiresAt,
    this.usedAt,
    required this.insightType,
    this.message,
    required this.sentAt,
    required this.doctorId,
    required this.doctorName,
    this.doctorImage,
    required this.offerType,
    this.customTitle,
    this.customTitleAr,
    this.description,
    this.descriptionAr,
    this.discountValue,
    this.discountType,
  });

  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
        claimId: j['claim_id'] as String,
        promotionId: j['promotion_id'] as String,
        voucherCode: j['voucher_code'] as String,
        status: j['status'] as String,
        claimedAt: DateTime.parse(j['claimed_at'] as String),
        expiresAt: j['expires_at'] != null
            ? DateTime.tryParse(j['expires_at'] as String)
            : null,
        usedAt: j['used_at'] != null
            ? DateTime.tryParse(j['used_at'] as String)
            : null,
        insightType: j['insight_type'] as String,
        message: j['message'] as String?,
        sentAt: DateTime.parse(j['sent_at'] as String),
        doctorId: j['doctor_id'] as String,
        doctorName: (j['doctor_name'] as String?) ?? '',
        doctorImage: j['doctor_image'] as String?,
        offerType: j['offer_type'] as String,
        customTitle: j['custom_title'] as String?,
        customTitleAr: j['custom_title_ar'] as String?,
        description: j['description'] as String?,
        descriptionAr: j['description_ar'] as String?,
        discountValue: (j['discount_value'] as num?)?.toDouble(),
        discountType: j['discount_type'] as String?,
      );
}

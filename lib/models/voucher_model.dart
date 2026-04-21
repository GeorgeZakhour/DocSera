class VoucherModel {
  final String id;
  final String offerId;
  final String code;
  final String status;
  final String redeemedAt;
  final String? usedAt;
  final String expiresAt;
  final String? offerTitle;
  final String? offerTitleAr;
  final String? offerDescription;
  final String? offerDescriptionAr;
  final String? offerCategory;
  final String? discountType;
  final double? discountValue;
  final String? partnerName;
  final String? partnerNameAr;
  final String? partnerAddress;
  final String? partnerAddressAr;
  final String? partnerLogoUrl;

  VoucherModel({
    required this.id,
    required this.offerId,
    required this.code,
    required this.status,
    required this.redeemedAt,
    this.usedAt,
    required this.expiresAt,
    this.offerTitle,
    this.offerTitleAr,
    this.offerDescription,
    this.offerDescriptionAr,
    this.offerCategory,
    this.discountType,
    this.discountValue,
    this.partnerName,
    this.partnerNameAr,
    this.partnerAddress,
    this.partnerAddressAr,
    this.partnerLogoUrl,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] as String,
      offerId: json['offer_id'] as String,
      code: json['code'] as String,
      status: json['status'] as String,
      redeemedAt: json['redeemed_at'] as String,
      usedAt: json['used_at'] as String?,
      expiresAt: json['expires_at'] as String,
      offerTitle: json['offer_title'] as String?,
      offerTitleAr: json['offer_title_ar'] as String?,
      offerDescription: json['offer_description'] as String?,
      offerDescriptionAr: json['offer_description_ar'] as String?,
      offerCategory: json['offer_category'] as String?,
      discountType: json['discount_type'] as String?,
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      partnerName: json['partner_name'] as String?,
      partnerNameAr: json['partner_name_ar'] as String?,
      partnerAddress: json['partner_address'] as String?,
      partnerAddressAr: json['partner_address_ar'] as String?,
      partnerLogoUrl: json['partner_logo_url'] as String?,
    );
  }

  String getLocalizedTitle(String locale) {
    if (locale == 'ar' && offerTitleAr != null && offerTitleAr!.isNotEmpty) return offerTitleAr!;
    return offerTitle ?? '';
  }

  String getLocalizedPartnerName(String locale) {
    if (locale == 'ar' && partnerNameAr != null && partnerNameAr!.isNotEmpty) return partnerNameAr!;
    return partnerName ?? '';
  }

  String getLocalizedPartnerAddress(String locale) {
    if (locale == 'ar' && partnerAddressAr != null && partnerAddressAr!.isNotEmpty) return partnerAddressAr!;
    return partnerAddress ?? '';
  }

  bool get isActive => status == 'active';
  bool get isUsed => status == 'used';
  bool get isExpired => status == 'expired' || DateTime.parse(expiresAt).isBefore(DateTime.now());
}

class OfferModel {
  final String id;
  final String category;
  final String title;
  final String? titleAr;
  final String? description;
  final String? descriptionAr;
  final int pointsCost;
  final String? partnerId;
  final String? partnerName;
  final String? partnerNameAr;
  final String? partnerLogoUrl;
  final String? partnerAddress;
  final String? partnerAddressAr;
  final String? partnerBrandColor;
  final String? partnerType;
  final String? partnerCoverUrl;
  final int partnerOfferCount;
  final String? discountType;
  final double? discountValue;
  final int? maxRedemptions;
  final int currentRedemptions;
  final String? startDate;
  final String? endDate;
  final bool isMegaOffer;
  final int voucherValidityDays;
  final String? imageUrl;

  OfferModel({
    required this.id,
    required this.category,
    required this.title,
    this.titleAr,
    this.description,
    this.descriptionAr,
    required this.pointsCost,
    this.partnerId,
    this.partnerName,
    this.partnerNameAr,
    this.partnerLogoUrl,
    this.partnerAddress,
    this.partnerAddressAr,
    this.partnerBrandColor,
    this.partnerType,
    this.partnerCoverUrl,
    this.partnerOfferCount = 0,
    this.discountType,
    this.discountValue,
    this.maxRedemptions,
    this.currentRedemptions = 0,
    this.startDate,
    this.endDate,
    this.isMegaOffer = false,
    this.voucherValidityDays = 7,
    this.imageUrl,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      pointsCost: json['points_cost'] as int,
      partnerId: json['partner_id'] as String?,
      partnerName: json['partner_name'] as String?,
      partnerNameAr: json['partner_name_ar'] as String?,
      partnerLogoUrl: json['partner_logo_url'] as String?,
      partnerAddress: json['partner_address'] as String?,
      partnerAddressAr: json['partner_address_ar'] as String?,
      partnerBrandColor: json['partner_brand_color'] as String?,
      partnerType: json['partner_type'] as String?,
      partnerCoverUrl: json['partner_cover_url'] as String?,
      partnerOfferCount: (json['partner_offer_count'] as int?) ?? 0,
      discountType: json['discount_type'] as String?,
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      maxRedemptions: json['max_redemptions'] as int?,
      currentRedemptions: json['current_redemptions'] as int? ?? 0,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      isMegaOffer: json['is_mega_offer'] as bool? ?? false,
      voucherValidityDays: json['voucher_validity_days'] as int? ?? 7,
      imageUrl: json['image_url'] as String?,
    );
  }

  String getLocalizedTitle(String locale) {
    if (locale == 'ar' && titleAr != null && titleAr!.isNotEmpty) return titleAr!;
    return title;
  }

  String? getLocalizedDescription(String locale) {
    if (locale == 'ar' && descriptionAr != null && descriptionAr!.isNotEmpty) return descriptionAr;
    return description;
  }

  String? getLocalizedPartnerName(String locale) {
    if (locale == 'ar' && partnerNameAr != null && partnerNameAr!.isNotEmpty) return partnerNameAr;
    return partnerName;
  }

  String? getLocalizedPartnerAddress(String locale) {
    if (locale == 'ar' && partnerAddressAr != null && partnerAddressAr!.isNotEmpty) return partnerAddressAr;
    return partnerAddress;
  }

  bool get isSoldOut => maxRedemptions != null && currentRedemptions >= maxRedemptions!;

  int? get remainingRedemptions =>
      maxRedemptions == null ? null : (maxRedemptions! - currentRedemptions);
}

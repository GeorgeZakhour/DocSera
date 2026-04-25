class PartnerModel {
  final String id;
  final String name;
  final String? nameAr;
  final String? logoUrl;
  final String? coverUrl;
  final String? brandColor;
  final String? partnerType;
  final String? address;
  final String? addressAr;
  final String? phone;
  final String? about;
  final String? aboutAr;
  final bool isActive;

  PartnerModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.logoUrl,
    this.coverUrl,
    this.brandColor,
    this.partnerType,
    this.address,
    this.addressAr,
    this.phone,
    this.about,
    this.aboutAr,
    this.isActive = true,
  });

  factory PartnerModel.fromJson(Map<String, dynamic> json) {
    return PartnerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      brandColor: json['brand_color'] as String?,
      partnerType: json['partner_type'] as String?,
      address: json['address'] as String?,
      addressAr: json['address_ar'] as String?,
      phone: json['phone'] as String?,
      about: json['about'] as String?,
      aboutAr: json['about_ar'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String getLocalizedName(String locale) {
    if (locale == 'ar' && nameAr != null && nameAr!.isNotEmpty) return nameAr!;
    return name;
  }

  String? getLocalizedAddress(String locale) {
    if (locale == 'ar' && addressAr != null && addressAr!.isNotEmpty) return addressAr;
    return address;
  }

  String? getLocalizedAbout(String locale) {
    if (locale == 'ar' && aboutAr != null && aboutAr!.isNotEmpty) return aboutAr;
    return about;
  }
}

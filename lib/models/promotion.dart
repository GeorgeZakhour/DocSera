/// Patient-side model for a promotion that may be owned by either a
/// specific doctor or by a clinic/hospital center.
///
/// Backed by the Supabase RPCs:
///   - get_public_center_promotions(centerId)
///   - get_promotions_for_doctor(doctorId)
///
/// `ownerType` discriminates the two sources. For center-owned promos,
/// `centerId` (and optionally `centerName`) are populated; for
/// doctor-owned promos, `doctorId` is populated.
///
/// `targetDoctorIds` is empty for doctor-owned promos and for
/// center-wide promos. It carries the chosen subset for center
/// promotions narrowed to specific doctors (`targetScope == 'center_selected'`).
class Promotion {
  final String id;
  final String? doctorId;
  final String? centerId;
  final String? centerName;

  /// 'doctor' | 'center'
  final String ownerType;

  /// Empty for owner=='doctor'. For owner=='center': empty list means
  /// "all doctors at the center"; non-empty means narrowed to those ids.
  final List<String> targetDoctorIds;

  final String offerType;
  final String audience;
  final String? customTitle;
  final String? customTitleAr;
  final String? description;
  final String? descriptionAr;
  final double? discountValue;
  final String? discountType;
  final int? pointsCost;
  final DateTime? endDate;
  final bool isFeatured;

  const Promotion({
    required this.id,
    this.doctorId,
    this.centerId,
    this.centerName,
    required this.ownerType,
    this.targetDoctorIds = const [],
    required this.offerType,
    required this.audience,
    this.customTitle,
    this.customTitleAr,
    this.description,
    this.descriptionAr,
    this.discountValue,
    this.discountType,
    this.pointsCost,
    this.endDate,
    this.isFeatured = false,
  });

  /// 'doctor' | 'center_wide' | 'center_selected'.
  String get targetScope => ownerType == 'doctor'
      ? 'doctor'
      : (targetDoctorIds.isEmpty ? 'center_wide' : 'center_selected');

  factory Promotion.fromJson(Map<String, dynamic> json) {
    final doctorId = json['doctor_id'] as String?;
    final centerId = json['center_id'] as String?;
    return Promotion(
      id: json['id'] as String,
      doctorId: doctorId,
      centerId: centerId,
      centerName: json['center_name'] as String?,
      ownerType: json['owner_type'] as String? ??
          (doctorId != null ? 'doctor' : 'center'),
      targetDoctorIds: ((json['target_doctor_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      offerType: json['offer_type'] as String,
      audience: json['audience'] as String? ?? 'all_patients',
      customTitle: json['custom_title'] as String?,
      customTitleAr: json['custom_title_ar'] as String?,
      description: json['description'] as String?,
      descriptionAr: json['description_ar'] as String?,
      discountValue: (json['discount_value'] as num?)?.toDouble(),
      discountType: json['discount_type'] as String?,
      pointsCost: (json['points_cost'] as num?)?.toInt(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }
}

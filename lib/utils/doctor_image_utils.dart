String getDoctorImage({
  required String? imageUrl,
  required String? gender,
  required String? title,
}) {
  if (imageUrl != null && imageUrl.trim().isNotEmpty) {
    return imageUrl;
  }

  final normalizedTitle = title?.toLowerCase().trim();
  final normalizedGender = gender?.toLowerCase().trim();

  final isDoctor = normalizedTitle == 'د.' ||
      normalizedTitle == '.د' ||
      normalizedTitle == 'dr.' ||
      normalizedTitle == 'د' ||
      normalizedTitle == 'doctor';

  if (isDoctor && (normalizedGender == 'أنثى' || normalizedGender == 'female')) {
    return 'assets/images/female-doc.png';
  } else if (isDoctor && (normalizedGender == 'ذكر' || normalizedGender == 'male')) {
    return 'assets/images/male-doc.png';
  } else if (normalizedGender == 'ذكر' || normalizedGender == 'male') {
    return 'assets/images/male-phys.png';
  } else {
    return 'assets/images/female-phys.png';
  }
}

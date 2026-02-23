import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ Custom Cache Manager to prevent storage bloat
/// Keeps only 100 images max, for 7 days.
final customCacheManager = CacheManager(
  Config(
    'customDoctorImageCache',
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 100,
  ),
);

String getDoctorImage({
  required String? imageUrl,
  required String? gender,
  required String? title,
}) {


  if (imageUrl != null &&
      imageUrl.trim().isNotEmpty &&
      imageUrl.trim().toLowerCase() != 'null') {
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
    return 'assets/images/female-doc.webp';
  } else if (isDoctor && (normalizedGender == 'ذكر' || normalizedGender == 'male')) {
    return 'assets/images/male-doc.webp';
  } else if (normalizedGender == 'ذكر' || normalizedGender == 'male') {
    return 'assets/images/male-phys.webp';
  } else {
    return 'assets/images/female-phys.webp';
  }
}

/// Extracts the URL from a NetworkImage if possible, returns null otherwise.
/// Useful for passing image URL to Firestore or Supabase.
String? getDoctorImageUrlFromProvider(ImageProvider provider) {
  if (provider is NetworkImage) {
    return provider.url;
  }
  return null;
}

class DoctorImageResult {
  final String avatarPath;
  final Widget widget;

  DoctorImageResult({required this.avatarPath, required this.widget});

  ImageProvider get imageProvider {
    if (avatarPath.startsWith('http')) {
      return NetworkImage(avatarPath);
    } else {
      return AssetImage(avatarPath);
    }
  }
}

DoctorImageResult resolveDoctorImagePathAndWidget({
  required Map<String, dynamic> doctor,
  double width = 100,
  double height = 100,
}) {

  final gender = doctor['gender']?.toString().toLowerCase() ?? 'ذكر';
  final title = doctor['title']?.toString().toLowerCase() ?? '';


  String? imagePath = doctor['doctor_image']?.toString().trim();

  if (imagePath == null || imagePath.isEmpty || imagePath.toLowerCase() == 'null') {
    imagePath = null;
  } else {
  }

  String? imageUrl;
  if (imagePath != null && imagePath.trim().isNotEmpty) {
    if (imagePath.startsWith('http')) {
      imageUrl = imagePath; // ✅ صورة من الإنترنت أو Supabase مباشرة
    } else if (imagePath.startsWith('assets/')) {
      imageUrl = imagePath; // ✅ صورة من assets
    } else {
      imageUrl = Supabase.instance.client.storage
          .from('doctor')
          .getPublicUrl(imagePath); // ✅ صورة مخزنة بـ path نسبي في Supabase
    }
  }




  final avatarPath = getDoctorImage(
    imageUrl: imageUrl,
    gender: gender,
    title: title,
  );

  final widget = avatarPath.startsWith('http')
      ? CachedNetworkImage(
    imageUrl: avatarPath,
    cacheManager: customCacheManager, // ✅ Use custom cache manager
    memCacheWidth: (width * 3).toInt(), // ✅ Resize in memory to save RAM (3x for high density screens)
    width: width.w,
    height: height.h,
    fit: BoxFit.cover,
    placeholder: (_, __) => SizedBox(
      width: width.w,
      height: height.h,
      child: const Center(
        child: SizedBox.shrink(),
      ),
    ),
    errorWidget: (_, __, ___) =>
        Image.asset("assets/images/male-doc.webp",
            width: width.w, height: height.h, fit: BoxFit.cover),
  )
      : Image.asset(
    avatarPath,
    width: width.w,
    height: height.h,
    fit: BoxFit.cover,
  );



  return DoctorImageResult(avatarPath: avatarPath, widget: widget);
}

DoctorImageResult resolveCenterImagePathAndWidget({
  required Map<String, dynamic> center,
  double width = 100,
  double height = 100,
}) {
  String? imagePath = center['center_image']?.toString().trim();

  if (imagePath == null || imagePath.isEmpty || imagePath.toLowerCase() == 'null') {
    imagePath = null;
  }

  String? imageUrl;
  if (imagePath != null && imagePath.trim().isNotEmpty) {
    if (imagePath.startsWith('http')) {
      imageUrl = imagePath;
    } else if (imagePath.startsWith('assets/')) {
      imageUrl = imagePath;
    } else {
      imageUrl = Supabase.instance.client.storage
          .from('center-images')
          .getPublicUrl(imagePath);
    }
  }

  final avatarPath = imageUrl ?? 'assets/images/logo-placeholder.png';

  final widget = avatarPath.startsWith('http')
      ? CachedNetworkImage(
    imageUrl: avatarPath,
    cacheManager: customCacheManager,
    memCacheWidth: (width * 3).toInt(),
    width: width.w,
    height: height.h,
    fit: BoxFit.cover,
    placeholder: (_, __) => SizedBox(
      width: width.w,
      height: height.h,
      child: const Center(
        child: SizedBox.shrink(),
      ),
    ),
    errorWidget: (_, __, ___) =>
        Image.asset("assets/images/logo-placeholder.png",
            width: width.w, height: height.h, fit: BoxFit.cover),
  )
      : Image.asset(
    avatarPath,
    width: width.w,
    height: height.h,
    fit: BoxFit.cover,
  );

  return DoctorImageResult(avatarPath: avatarPath, widget: widget);
}

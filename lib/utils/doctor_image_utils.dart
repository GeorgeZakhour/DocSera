import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String getDoctorImage({
  required String? imageUrl,
  required String? gender,
  required String? title,
}) {
  print("🧩 [getDoctorImage] imageUrl = '${imageUrl}'");
  print("🧩 [getDoctorImage] gender = '${gender}'");
  print("🧩 [getDoctorImage] title = '${title}'");

  if (imageUrl != null &&
      imageUrl.trim().isNotEmpty &&
      imageUrl.trim().toLowerCase() != 'null') {
    print("✅ [getDoctorImage] Using doctor uploaded image: $imageUrl");
    return imageUrl;
  }

  final normalizedTitle = title?.toLowerCase().trim();
  final normalizedGender = gender?.toLowerCase().trim();

  print("🧩 [getDoctorImage] normalizedTitle = '$normalizedTitle'");
  print("🧩 [getDoctorImage] normalizedGender = '$normalizedGender'");

  final isDoctor = normalizedTitle == 'د.' ||
      normalizedTitle == '.د' ||
      normalizedTitle == 'dr.' ||
      normalizedTitle == 'د' ||
      normalizedTitle == 'doctor';

  print("🧩 [getDoctorImage] isDoctor = $isDoctor");

  if (isDoctor && (normalizedGender == 'أنثى' || normalizedGender == 'female')) {
    print("👩 [getDoctorImage] Using default female doctor image");
    return 'assets/images/female-doc.png';
  } else if (isDoctor && (normalizedGender == 'ذكر' || normalizedGender == 'male')) {
    print("👨 [getDoctorImage] Using default male doctor image");
    return 'assets/images/male-doc.png';
  } else if (normalizedGender == 'ذكر' || normalizedGender == 'male') {
    print("👨‍⚕️ [getDoctorImage] Using default male physician image");
    return 'assets/images/male-phys.png';
  } else {
    print("👩‍⚕️ [getDoctorImage] Using default female physician image");
    return 'assets/images/female-phys.png';
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
    print("🧩 [DoctorImageResult] avatarPath = '$avatarPath'");
    if (avatarPath.startsWith('http')) {
      print("🌐 [DoctorImageResult] Using NetworkImage");
      return NetworkImage(avatarPath);
    } else {
      print("📦 [DoctorImageResult] Using AssetImage");
      return AssetImage(avatarPath);
    }
  }
}

DoctorImageResult resolveDoctorImagePathAndWidget({
  required Map<String, dynamic> doctor,
  double width = 100,
  double height = 100,
}) {
  print("🔍 [resolveDoctorImagePathAndWidget] doctor map = $doctor");

  final gender = doctor['gender']?.toString().toLowerCase() ?? 'ذكر';
  final title = doctor['title']?.toString().toLowerCase() ?? '';

  print("🔍 [resolveDoctorImagePathAndWidget] gender = $gender");
  print("🔍 [resolveDoctorImagePathAndWidget] title = $title");

  String? imagePath = doctor['doctor_image']?.toString().trim();

  if (imagePath == null || imagePath.isEmpty || imagePath.toLowerCase() == 'null') {
    print("❌ [resolveDoctorImagePathAndWidget] imagePath is null or invalid ('$imagePath')");
    imagePath = null;
  } else {
    print("📷 [resolveDoctorImagePathAndWidget] Valid imagePath found: '$imagePath'");
  }

  String? imageUrl;
  if (imagePath != null && imagePath.trim().isNotEmpty) {
    if (imagePath.startsWith('http')) {
      imageUrl = imagePath; // ✅ صورة من الإنترنت أو Supabase مباشرة
      print("🌐 [resolveDoctorImagePathAndWidget] Using existing image URL: $imageUrl");
    } else if (imagePath.startsWith('assets/')) {
      imageUrl = imagePath; // ✅ صورة من assets
      print("📦 [resolveDoctorImagePathAndWidget] Using local asset image: $imageUrl");
    } else {
      imageUrl = Supabase.instance.client.storage
          .from('doctor')
          .getPublicUrl(imagePath); // ✅ صورة مخزنة بـ path نسبي في Supabase
      print("🌐 [resolveDoctorImagePathAndWidget] Generated Supabase URL: $imageUrl");
    }
  }




  final avatarPath = getDoctorImage(
    imageUrl: imageUrl,
    gender: gender,
    title: title,
  );

  final widget = avatarPath.startsWith('http')
      ? Image.network(avatarPath, width: width.w, height: height.h, fit: BoxFit.cover)
      : Image.asset(avatarPath, width: width.w, height: height.h, fit: BoxFit.cover);

  print("✅ [resolveDoctorImagePathAndWidget] Final avatarPath = $avatarPath");

  return DoctorImageResult(avatarPath: avatarPath, widget: widget);
}

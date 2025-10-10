import 'package:docsera/app/const.dart';
import 'package:docsera/screens/auth/sign_up/WelcomePage.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/sign_up_info.dart';
import '../../../app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:device_info_plus/device_info_plus.dart';

class RecapPage extends StatelessWidget {
  final SignUpInfo signUpInfo;
  final SupabaseUserService _supabaseUserService = SupabaseUserService();

  RecapPage({Key? key, required this.signUpInfo}) : super(key: key);

  /// ✅ الحصول على معرف الجهاز
  Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    return androidInfo.id ?? androidInfo.device ?? '';
  }

  /// ✅ تسجيل الدخول التلقائي بعد التسجيل (اختياري)
  Future<void> _autoLogin(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: signUpInfo.email!,
        password: signUpInfo.password!,
      );

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(WelcomePage(signUpInfo: signUpInfo)),
            (Route<dynamic> route) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.autoLoginFailed)),
      );
    }
  }

  /// ✅ تسجيل المستخدم في Supabase (مع إصلاح خاص بـ iOS)
  Future<void> _registerUserWithSupabase(BuildContext context) async {
    try {
      // تحقق من وجود الإيميل مسبقًا
      final existingEmail = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('email', signUpInfo.email!)
          .maybeSingle();

      if (existingEmail != null) {
        throw Exception(AppLocalizations.of(context)!.emailAlreadyRegistered);
      }

      // إنشاء المستخدم في Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: signUpInfo.email!,
        password: signUpInfo.password!,
      );

      // ✅ إصلاح مشكلة iOS: الحصول على المستخدم الحالي إذا لم يتم إرجاعه مباشرة
      final user = response.user ?? Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception(AppLocalizations.of(context)!.registrationFailed);
      }

      final userId = user.id;

      // بيانات المستخدم لحفظها في قاعدة البيانات
      final userData = {
        'id': userId,
        'first_name': signUpInfo.firstName,
        'last_name': signUpInfo.lastName,
        'email': signUpInfo.email,
        'phone_number': signUpInfo.phoneNumber,
        'email_verified': signUpInfo.emailVerified,
        'phone_verified': signUpInfo.phoneVerified,
        'gender': signUpInfo.gender,
        'date_of_birth': signUpInfo.dateOfBirth,
        'terms_accepted': signUpInfo.termsAccepted,
        'marketing_checked': signUpInfo.marketingChecked,
        'two_factor_auth_enabled': false,
        'trusted_devices': [],
      };

      // حفظ المستخدم في Supabase (جدول users)
      await _supabaseUserService.addUser(userId, userData);

      // إضافة معرف الجهاز إلى trusted_devices
      final deviceId = await getDeviceId();
      await Supabase.instance.client
          .from('users')
          .update({'trusted_devices': [deviceId]})
          .eq('id', userId);

      // حفظ الحالة في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString(
          'userName', '${signUpInfo.firstName} ${signUpInfo.lastName}');
      await prefs.setString('userEmail', signUpInfo.email ?? "Not provided");
      await prefs.setString('userPhone', signUpInfo.phoneNumber ?? "Not provided");

      // الانتقال إلى صفحة الترحيب
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(WelcomePage(signUpInfo: signUpInfo)),
              (Route<dynamic> route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.registrationSuccess),
            backgroundColor: AppColors.main.withOpacity(0.9),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.registrationFailed}: $e',
            ),
          ),
        );
      }
    }
  }

  /// ✅ تنسيق عرض الجنس حسب اللغة
  String _getLocalizedGender(BuildContext context) {
    final gender = signUpInfo.gender?.trim() ?? "";
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (gender.isEmpty) return "—";

    if (gender == "Male" || gender == "ذكر") {
      return isArabic ? "ذكر" : AppLocalizations.of(context)!.male;
    } else if (gender == "Female" || gender == "أنثى") {
      return isArabic ? "أنثى" : AppLocalizations.of(context)!.female;
    }

    return gender;
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> recapData = [
      {
        AppLocalizations.of(context)!.name:
        "${signUpInfo.firstName ?? "—"} ${signUpInfo.lastName ?? "—"}"
      },
      {AppLocalizations.of(context)!.gender: _getLocalizedGender(context)},
      {
        AppLocalizations.of(context)!.dateOfBirth:
        signUpInfo.dateOfBirth ?? "—"
      },
      {AppLocalizations.of(context)!.email: signUpInfo.email ?? "—"},
      {
        AppLocalizations.of(context)!.emailVerified:
        signUpInfo.emailVerified ? "✔" : "✖"
      },
      {
        AppLocalizations.of(context)!.phone:
        signUpInfo.phoneNumber?.replaceFirst("00963", "0") ?? "—"
      },
      {
        AppLocalizations.of(context)!.phoneVerified:
        signUpInfo.phoneVerified ? "✔" : "✖"
      },
      {
        AppLocalizations.of(context)!.termsAccepted:
        signUpInfo.termsAccepted ? "✔" : "✖"
      },
      if (signUpInfo.marketingChecked)
        {AppLocalizations.of(context)!.marketingPreferences: "✔"},
    ];

    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context)
            .copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.reviewDetails,
              style: AppTextStyles.getTitle1(context),
            ),
            SizedBox(height: 10.h),

            // ✅ بيانات المراجعة
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: recapData.map((entry) {
                  final title = entry.keys.first;
                  final value = entry.values.first;

                  return Column(
                    children: [
                      Padding(
                        padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(title,
                                style: AppTextStyles.getText2(context)
                                    .copyWith(fontWeight: FontWeight.bold)),
                            Text(value, style: AppTextStyles.getText2(context)),
                          ],
                        ),
                      ),
                      if (entry != recapData.last)
                        Divider(height: 1.h, color: Colors.grey[200]),
                    ],
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20.h),

            // ✅ زر التسجيل
            ElevatedButton(
              onPressed: () => _registerUserWithSupabase(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.register,
                    style: AppTextStyles.getText2(context).copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

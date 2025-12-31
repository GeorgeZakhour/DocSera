import 'dart:io';

import 'package:docsera/app/const.dart';
import 'package:docsera/screens/auth/sign_up/WelcomePage.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
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

  RecapPage({super.key, required this.signUpInfo});

  /// ✅ Device ID موحد Android / iOS
  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();

    try {
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? 'ios-unknown';
      }

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id ?? android.device ?? 'android-unknown';
      }

      return 'unknown-platform';
    } catch (_) {
      return 'unknown-device';
    }
  }

  /// ---------------------------------------------------------------------------
  /// ✅ التسجيل النهائي (النسخة الصحيحة 100%)
  /// ---------------------------------------------------------------------------
  Future<void> _registerUserWithSupabase(BuildContext context) async {
    try {
      // ---------------------------------------------------------------------
      // 1️⃣ تحقق أساسي
      // ---------------------------------------------------------------------
      if (signUpInfo.email == null || signUpInfo.password == null) {
        throw Exception('Missing email or password');
      }


      // ---------------------------------------------------------------------
      // 3️⃣ Supabase Auth Sign-Up
      // ---------------------------------------------------------------------
      final authRes = await Supabase.instance.client.auth.signUp(
        email: signUpInfo.email!,
        password: signUpInfo.password!,
      );

      final authClient = Supabase.instance.client.auth;

      if (authClient.currentSession == null) {
        await authClient.refreshSession();
      }

      if (authClient.currentSession == null) {
        throw Exception('Auth session not established');
      }



      final user =
          authRes.user ?? Supabase.instance.client.auth.currentUser;

      if (user == null || user.id.isEmpty) {
        throw Exception('User creation failed (no auth user)');
      }

      final userId = user.id;

      // ---------------------------------------------------------------------
      // 4️⃣ إدخال صف المستخدم في جدول users
      // ---------------------------------------------------------------------
      final userData = {
        'id': userId,
        'first_name': signUpInfo.firstName ?? '',
        'last_name': signUpInfo.lastName ?? '',
        'email': signUpInfo.email ?? '',
        'phone_number': signUpInfo.phoneNumber ?? '',
        'email_verified': signUpInfo.emailVerified,
        'phone_verified': signUpInfo.phoneVerified,
        'gender': signUpInfo.gender ?? '',
        'date_of_birth': signUpInfo.dateOfBirth ?? '',
        'terms_accepted': signUpInfo.termsAccepted,
        'marketing_checked': signUpInfo.marketingChecked,
        'two_factor_auth_enabled': false, // ✅ كما طلبت
        'trusted_devices': [],
      };

      await _supabaseUserService.addUser(userData);

      // ---------------------------------------------------------------------
      // 5️⃣ إضافة الجهاز الحالي عبر RPC (Security Definer)
      // ---------------------------------------------------------------------
      final deviceId = await _getDeviceId();

      await Supabase.instance.client.rpc(
        'trust_current_device',
        params: {'p_device_id': deviceId},
      );

      // ---------------------------------------------------------------------
      // 6️⃣ تخزين محلي (غير أمني – UI فقط)
      // ---------------------------------------------------------------------
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString(
        'userName',
        '${signUpInfo.firstName ?? ''} ${signUpInfo.lastName ?? ''}'.trim(),
      );
      await prefs.setString('userEmail', signUpInfo.email!);
      await prefs.setString(
        'userPhone',
        signUpInfo.phoneNumber ?? '',
      );

      // ---------------------------------------------------------------------
      // 7️⃣ الانتقال لصفحة الترحيب
      // ---------------------------------------------------------------------
      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(WelcomePage(signUpInfo: signUpInfo)),
            (_) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.registrationSuccess,
          ),
          backgroundColor: AppColors.main.withOpacity(0.9),
        ),
      );
    } catch (e, s) {
      debugPrint('❌ Registration failed: $e');
      debugPrintStack(stackTrace: s);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.registrationFailed}: $e',
          ),
        ),
      );
    }
  }

  /// ---------------------------------------------------------------------------
  /// UI Helpers
  /// ---------------------------------------------------------------------------
  String _getLocalizedGender(BuildContext context) {
    final gender = signUpInfo.gender?.trim() ?? '';
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (gender.isEmpty) return '—';

    if (gender == 'Male' || gender == 'ذكر') {
      return isAr ? 'ذكر' : AppLocalizations.of(context)!.male;
    }
    if (gender == 'Female' || gender == 'أنثى') {
      return isAr ? 'أنثى' : AppLocalizations.of(context)!.female;
    }

    return gender;
  }

  @override
  Widget build(BuildContext context) {
    final recapData = <Map<String, String>>[
      {
        AppLocalizations.of(context)!.name:
        '${signUpInfo.firstName ?? '—'} ${signUpInfo.lastName ?? '—'}',
      },
      {
        AppLocalizations.of(context)!.gender:
        _getLocalizedGender(context),
      },
      {
        AppLocalizations.of(context)!.dateOfBirth:
        signUpInfo.dateOfBirth ?? '—',
      },
      {
        AppLocalizations.of(context)!.email:
        signUpInfo.email ?? '—',
      },
      {
        AppLocalizations.of(context)!.emailVerified:
        signUpInfo.emailVerified ? '✔' : '✖',
      },
      {
        AppLocalizations.of(context)!.phone:
        signUpInfo.phoneNumber?.replaceFirst('00963', '0') ?? '—',
      },
      {
        AppLocalizations.of(context)!.phoneVerified:
        signUpInfo.phoneVerified ? '✔' : '✖',
      },
      {
        AppLocalizations.of(context)!.termsAccepted:
        signUpInfo.termsAccepted ? '✔' : '✖',
      },
      if (signUpInfo.marketingChecked)
        {AppLocalizations.of(context)!.marketingPreferences: '✔'},
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: recapData.map((entry) {
                  final k = entry.keys.first;
                  final v = entry.values.first;

                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              k,
                              style: AppTextStyles.getText2(context)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              v,
                              style: AppTextStyles.getText2(context),
                            ),
                          ],
                        ),
                      ),
                      if (entry != recapData.last)
                        Divider(
                          height: 1.h,
                          color: Colors.grey[200],
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: () => _registerUserWithSupabase(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.register,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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

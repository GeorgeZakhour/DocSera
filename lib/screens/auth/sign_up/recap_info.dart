import 'dart:io';

import 'package:docsera/app/const.dart';
import 'package:docsera/screens/auth/sign_up/WelcomePage.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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


  const RecapPage({super.key, required this.signUpInfo});

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
    if (signUpInfo.authMethod == AuthMethod.phoneOtp) {
      if (signUpInfo.phoneNumber == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.registrationFailed)),
          );
        }
        return;
      }
      await _registerWithPhoneOtp(context);
    } else {
      if (signUpInfo.email == null || signUpInfo.password == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.registrationFailed)),
          );
        }
        return;
      }
      await _registerWithPassword(context, signUpInfo.password!);
    }
  }

  Future<void> _registerWithPhoneOtp(BuildContext context) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'phone_otp_signup',
        body: {
          'phone': signUpInfo.phoneNumber!,
          'otp_code': signUpInfo.otpCode!,
          'app': 'docsera',
        },
      );

      final body = res.data as Map<String, dynamic>;
      final userId = body['user_id'] as String;
      final refreshToken = body['refresh_token'] as String?;

      if (refreshToken != null) {
        await Supabase.instance.client.auth.setSession(refreshToken);
      }

      await _finalizeUserRecord(context, userId);
    } catch (e) {
      debugPrint('❌ Phone OTP Registration failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.registrationFailed}: $e')),
      );
    }
  }

  Future<void> _finalizeUserRecord(BuildContext context, String userId) async {
    // -------------------------------------------------------------------
    // 2️⃣ إدخال صف المستخدم في جدول users
    // -------------------------------------------------------------------
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
      'two_factor_auth_enabled': false,
      'trusted_devices': [],
    };

    if (!context.mounted) return;
    await context.read<SupabaseUserService>().addUser(userData);

    // -------------------------------------------------------------------
    // 3️⃣ إضافة الجهاز الحالي عبر RPC (Security Definer)
    // -------------------------------------------------------------------
    final deviceId = await _getDeviceId();
    await Supabase.instance.client.rpc(
      'trust_current_device',
      params: {'p_device_id': deviceId},
    );

    // -------------------------------------------------------------------
    // 4️⃣ تخزين محلي (غير أمني – UI فقط)
    // -------------------------------------------------------------------
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', userId);
    await prefs.setString(
      'userName',
      '${signUpInfo.firstName ?? ''} ${signUpInfo.lastName ?? ''}'.trim(),
    );
    if (signUpInfo.email != null) await prefs.setString('userEmail', signUpInfo.email!);
    await prefs.setString('userPhone', signUpInfo.phoneNumber ?? '');

    // -------------------------------------------------------------------
    // 5️⃣ الانتقال لصفحة الترحيب
    // -------------------------------------------------------------------
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      fadePageRoute(WelcomePage(signUpInfo: signUpInfo)),
          (_) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.registrationSuccess),
        backgroundColor: AppColors.main.withOpacity(0.9),
      ),
    );
  }

  /// Core registration logic — called with either the user's chosen password
  /// or their existing password (cross-app case).
  Future<void> _registerWithPassword(BuildContext context, String password) async {
    try {
      // -------------------------------------------------------------------
      // 1️⃣ Cross-App Signup (handles new + existing users)
      // -------------------------------------------------------------------
      Map<String, dynamic> body;
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'cross_app_signup',
          body: {
            'email': signUpInfo.email!,
            'password': password,
            'app': 'docsera',
          },
        );
        body = res.data as Map<String, dynamic>;
      } on FunctionException catch (e) {
        // Supabase SDK throws FunctionException on non-200 status codes
        final details = e.details;
        if (details is Map<String, dynamic>) {
          final error = details['error'] as String? ?? '';
          if (error == 'wrong_password') {
            if (!context.mounted) return;
            _showExistingPasswordDialog(context);
            return;
          }
          if (error == 'already_registered_same_app') {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.registrationFailed)),
            );
            return;
          }
        }
        rethrow;
      }

      final userId = body['user_id'] as String;
      final refreshToken = body['refresh_token'] as String?;

      // Set the session from the Edge Function tokens
      if (refreshToken != null) {
        await Supabase.instance.client.auth.setSession(refreshToken);
      }

      final authClient = Supabase.instance.client.auth;
      if (authClient.currentSession == null) {
        await authClient.refreshSession();
      }
      if (authClient.currentSession == null) {
        throw Exception('Auth session not established');
      }

      await _finalizeUserRecord(context, userId);
    } catch (e, s) {
      debugPrint('❌ Registration failed: $e');
      debugPrintStack(stackTrace: s);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.registrationFailed}: $e'),
        ),
      );
    }
  }

  /// Shows a dialog when the user already has an account from DocSera Pro.
  /// They need to enter their existing password to link the accounts.
  void _showExistingPasswordDialog(BuildContext context) {
    final existingPwController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                AppLocalizations.of(context)!.existingAccountTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.getTitle2(context),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.existingAccountMessage,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: existingPwController,
                    obscureText: obscure,
                    style: AppTextStyles.getText2(context),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.password,
                      labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final existingPw = existingPwController.text.trim();
                    if (existingPw.isEmpty) return;
                    Navigator.pop(dialogContext);
                    _registerWithPassword(context, existingPw);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.main,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.continueButton,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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

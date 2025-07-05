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


  Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    return androidInfo.id ?? androidInfo.device ?? '';
  }


  /// **Auto Login after successful registration**
  Future<void> _autoLogin(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: signUpInfo.email!,
        password: signUpInfo.password!,
      );


      // ✅ Save login state
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(WelcomePage(signUpInfo: signUpInfo)), // ✅ Navigate to Welcome Page
            (Route<dynamic> route) => false,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.autoLoginFailed)),
      );
    }
  }

  /// **Register user in Firebase and store data in Firestore**
  Future<void> _registerUserWithSupabase(BuildContext context) async {
    try {


// ✅ تحقق من الإيميل الحقيقي فقط إذا تم إدخاله
      final existingEmail = await Supabase.instance.client
          .from('users')
          .select('email')
          .eq('email', signUpInfo.email!)
          .maybeSingle();

      if (existingEmail != null) {
        throw Exception(AppLocalizations.of(context)!.emailAlreadyRegistered);
      }





      // ✅ Register user in Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: signUpInfo.email!,
        password: signUpInfo.password!,
      );

      final user = response.user;
      if (user == null) {
        throw Exception(AppLocalizations.of(context)!.registrationFailed);
      }

      final userId = user?.id;

      final userData = {
        'id': userId, // ✅ أضف هذا السطر
        'first_name': signUpInfo.firstName,
        'last_name': signUpInfo.lastName,
        'email': signUpInfo.email,
        'phone_number': signUpInfo.phoneNumber,
        'email_verified': signUpInfo.emailVerified,
        'phone_verified': signUpInfo.phoneVerified,
        'gender': signUpInfo.gender == "ذكر" ? "ذكر" : "أنثى",
        'date_of_birth': signUpInfo.dateOfBirth,
        'terms_accepted': signUpInfo.termsAccepted,
        'marketing_checked': signUpInfo.marketingChecked,
        'two_factor_auth_enabled': false,
        'trusted_devices': [],
      };

      // ✅ Save user data in Firestore
      if (userId == null) throw Exception('User ID is null');
      await _supabaseUserService.addUser(userId, userData);

      final deviceId = await getDeviceId();
      await Supabase.instance.client
          .from('users')
          .update({'trusted_devices': [deviceId]})
          .eq('id', userId);



      // ✅ Store user info in SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userName', '${signUpInfo.firstName} ${signUpInfo.lastName}');
      await prefs.setString('userEmail', signUpInfo.email ?? "Not provided");
      await prefs.setString('userPhone', signUpInfo.phoneNumber ?? "Not provided");


      if (context.mounted) {
        // ✅ Navigate to Home
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(WelcomePage(signUpInfo: signUpInfo)), // ✅ Navigate to Welcome Page
              (Route<dynamic> route) => false,
        );


        // ✅ Show confirmation message
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
          SnackBar(content: Text('${AppLocalizations.of(context)!.registrationFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> recapData = [
      {AppLocalizations.of(context)!.name: "${signUpInfo.firstName ?? "—"} ${signUpInfo.lastName ?? "—"}"},
      {
        AppLocalizations.of(context)!.gender:
        Localizations.localeOf(context).languageCode == 'ar'
            ? (signUpInfo.gender == "Male" ? "ذكر" : "أنثى")
            : (signUpInfo.gender ?? "—"),
      },
      {AppLocalizations.of(context)!.dateOfBirth: signUpInfo.dateOfBirth ?? "—"},
      {AppLocalizations.of(context)!.email: signUpInfo.email ?? "—"},
      {AppLocalizations.of(context)!.emailVerified: signUpInfo.emailVerified ? "✔" : "✖"},
      {AppLocalizations.of(context)!.phone: signUpInfo.phoneNumber?.replaceFirst("00963", "0") ?? "—"},
      {AppLocalizations.of(context)!.phoneVerified: signUpInfo.phoneVerified ? "✔" : "✖"},
      {AppLocalizations.of(context)!.termsAccepted: signUpInfo.termsAccepted ? "✔" : "✖"},
      if (signUpInfo.marketingChecked) {AppLocalizations.of(context)!.marketingPreferences: "✔"},
    ];

    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.signUp,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
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

            // **White Container with Rounded Borders**
            Container(
              // padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!), // Thin grey border
              ),
              child: Column(
                children: recapData.map((entry) {
                  final title = entry.keys.first;
                  final value = entry.values.first;

                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(title, style: AppTextStyles.getText2(context).copyWith(fontWeight: FontWeight.bold)),
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

            // **Register Button**
            ElevatedButton(
              onPressed: () => _registerUserWithSupabase(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.main,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.register,
                    style: AppTextStyles.getText2(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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

import 'dart:io';

import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_otp.dart';
import 'package:docsera/services/supabase/supabase_user_service.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:crypto/crypto.dart'; // For hashing
import 'package:docsera/app/const.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:flutter/material.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:local_auth/local_auth.dart'; // Face ID Auth
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../Business_Logic/Account_page/user_cubit.dart';
import 'package:device_info_plus/device_info_plus.dart';



class LogInPage extends StatefulWidget {
  final String? preFilledInput; // Optional pre-filled email or phone number

  const LogInPage({super.key, this.preFilledInput});

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  late TextEditingController _inputController;
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseUserService _supabaseUserService = SupabaseUserService();
  final LocalAuthentication auth = LocalAuthentication();
  bool isPasswordVisible = false;
  bool isValid = false;
  bool isFaceIdEnabled = false;
  String? errorMessage;
  bool isLoading = false;
  String biometricType = ""; // Default empty string
  bool biometricAvailable = false;
  bool isFaceID = false;


  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.preFilledInput);
    isValid = widget.preFilledInput != null && widget.preFilledInput!.isNotEmpty;
    _checkBiometricType();
  }







  Future<void> _checkBiometricType() async {
    final prefs = await SharedPreferences.getInstance();
    final isBiometricEnabled = prefs.getBool('enableFaceID') ?? false;

    if (!isBiometricEnabled) return;

    final availableBiometrics = await auth.getAvailableBiometrics();
    setState(() {
      biometricAvailable = availableBiometrics.isNotEmpty;
      isFaceID = availableBiometrics.contains(BiometricType.face);
    });

    print("✅ Biometric available: $biometricAvailable");
    print("✅ Is Face ID: $isFaceID");
  }


  /// **🔐 Hash the password using SHA-256**
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

/// ✅ الحصول على معرف الجهاز بطريقة آمنة تعمل على Android و iOS
Future<String> getDeviceId() async {
  try {
    final info = DeviceInfoPlugin();

    if (Platform.isIOS) {
      // 🟢 iOS
      final iosInfo = await info.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios-unknown';
    } else if (Platform.isAndroid) {
      // 🤖 Android
      final androidInfo = await info.androidInfo;
      return androidInfo.id ?? androidInfo.device ?? 'android-unknown';
    } else {
      return 'unknown-platform';
    }
  } catch (e) {
    print('⚠️ [DEBUG] Failed to get deviceId: $e');
    return 'unknown-device';
  }
}




  /// ✅ تنسيق الرقم لصيغة 00963 كما في صفحة التسجيل
  String getFormattedPhoneNumber(String phone) {
    phone = phone.trim();
    if (phone.startsWith('09')) {
      phone = phone.substring(1);
    }
    return "00963$phone";
  }


  Future<void> _logInUser() async {
    setState(() => isLoading = true);

    try {
      var input = _inputController.text.trim();
      final password = _passwordController.text.trim();

      // 🟢 تأكد أن الإيميل دائمًا بحروف صغيرة (lowercase)
      if (input.contains('@')) {
        input = input.toLowerCase();
      }

      final isPhone = RegExp(r'^0\d{9}$').hasMatch(input) || RegExp(r'^00963\d{9}$').hasMatch(input);
      final formattedPhone = isPhone ? getFormattedPhoneNumber(input) : null;

      print("📥 [INPUT] المستخدم أدخل: $input");
      if (isPhone) {
        print("📞 [FORMAT] تم التعرف عليه كرقم هاتف وتم تنسيقه إلى: $formattedPhone");
      } else {
        print("📧 [FORMAT] تم التعرف عليه كإيميل: $input");
      }

      // ✅ جلب بيانات المستخدم من Supabase
      final userDoc = await _supabaseUserService.getUserByEmailOrPhone(isPhone ? formattedPhone! : input);
      print("🧾 [USER DATA] البيانات المسترجعة من Supabase: $userDoc");

      final userData = userDoc;
      if (userData == null) throw Exception("❌ لم يتم العثور على بيانات المستخدم");

      final email = userData['email']?.toString();
      if (email == null || email.isEmpty) throw Exception("❌ الإيميل غير متوفر");

      print("📨 [AUTH EMAIL] الإيميل الذي سيتم استخدامه لتسجيل الدخول: $email");

      // ✅ تسجيل الدخول في Supabase Auth
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) throw Exception("❌ فشل تسجيل الدخول في Supabase");

      final userId = supabaseUser.id;
      print("✅ [LOGIN SUCCESS] User ID: $userId");

      // ✅ تحضير البيانات
      final firstName = userData['firstName']?.toString() ?? '';
      final lastName = userData['lastName']?.toString() ?? '';
      final fullName = '$firstName $lastName'.trim();
      final userPhone = userData['phone_number']?.toString() ?? '';
      final userEmail = userData['email']?.toString() ?? '';

      // ✅ تخزين البيانات في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userName', fullName);
      await prefs.setString('userEmail', userEmail);
      await prefs.setString('userPhone', userPhone);
      await prefs.setString('userPassword', password); // للبصمة

      print("💾 [SHARED PREFS] تم حفظ بيانات المستخدم");

      // ✅ تحديث Cubit
      context.read<UserCubit>().loadUserData(context);
      print("🔁 [CUBIT] تم استدعاء loadUserData");

      // ✅ التحقق من الأجهزة الموثوقة والتحقق بخطوتين
      if (context.mounted) {
        final deviceId = await getDeviceId();
        print("📱 [DEVICE ID] $deviceId");

        final trustedDevices = (userData['trustedDevices'] as List?) ?? [];
        final is2FAEnabled = userData['twoFactorAuthEnabled'] == true;

        print("🛡️ [2FA] مفعل؟ $is2FAEnabled");
        print("🧩 [DEVICE TRUSTED?] ${trustedDevices.contains(deviceId)}");

        if (is2FAEnabled && !trustedDevices.contains(deviceId)) {
          final phone = userData['phone_number']?.toString();
          print("📞 [2FA PHONE] قيمة phone_number = $phone");

          if (phone == null || phone.isEmpty) {
            print("🚨 [ERROR] لا يمكن إرسال المستخدم إلى صفحة OTP لأن رقم الهاتف غير موجود");
            throw Exception("رقم الهاتف غير متوفر");
          }

          print("🚨 [2FA] الانتقال إلى صفحة OTP للتحقق");
          print("📞 [TYPE CHECK] phone.runtimeType = ${phone.runtimeType}");

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LoginOTPPage(
                phoneNumber: phone.toString(),
                userId: userId,
              ),
            ),
                (route) => false,
          );
        } else {
          print("✅ [NAVIGATION] الانتقال إلى الصفحة الرئيسية");
          Navigator.pushAndRemoveUntil(
            context,
            fadePageRoute(CustomBottomNavigationBar()),
                (route) => false,
          );
        }
      }
      } catch (e) {
        print("❌ خطأ أثناء تسجيل الدخول: $e");
        String message;

        // 🔍 تحليل نوع الخطأ وإظهار النص المناسب
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('invalid login credentials') ||
            errorStr.contains('invalid email or password') ||
            errorStr.contains('wrong password')) {
          message = AppLocalizations.of(context)!.errorWrongPassword;
        } else if (errorStr.contains('user not found') ||
                  errorStr.contains('no user') ||
                  errorStr.contains('not found')) {
          message = AppLocalizations.of(context)!.errorUserNotFound;
        } else {
          message = AppLocalizations.of(context)!.errorGenericLogin;
        }

        setState(() {
          errorMessage = message;
        });
      } finally {
            setState(() => isLoading = false);
          }
        }




  Future<void> _authenticateWithFaceID() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('userPhone');
      final savedPassword = prefs.getString('userPassword');

      print("🟢 [DEBUG] Checking Saved Credentials for Biometric Login");
      print("🔹 Saved Phone: ${savedPhone ?? 'Not Found'}");
      print("🔹 Password Exists: ${savedPassword != null}");

      if (savedPhone == null || savedPassword == null) {
        print("❌ No saved credentials.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.faceIdNoCredentials)),
        );
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: biometricType == AppLocalizations.of(context)!.faceIdTitle
            ? AppLocalizations.of(context)!.faceIdPrompt
            : AppLocalizations.of(context)!.fingerprintPrompt,
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated) {
        final formattedDisplayPhone = savedPhone.startsWith('00963')
            ? '0${savedPhone.substring(5)}'
            : savedPhone;

        print("✅ Auto-filled from biometric: $formattedDisplayPhone");

        setState(() {
          _inputController.text = formattedDisplayPhone;
          _passwordController.text = savedPassword;
          isValid = true;
        });

        await _logInUser(); // ✅ نفذ تسجيل الدخول تلقائيًا بعد تعبئة الحقول
      }
    } catch (e) {
      print("❌ Biometric Authentication Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.faceIdFailed)),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.logIn,
        style: AppTextStyles.getTitle1(context).copyWith(color: AppColors.whiteText),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.logIn,
                style: AppTextStyles.getTitle1(context).copyWith(fontSize: 12.sp, color: AppColors.mainDark)),
            SizedBox(height: 20.h),

            // 🟢 Email or Phone Number Input
            TextFormField(
              controller: _inputController,
              textDirection: detectTextDirection(_inputController.text), // ✅ ضبط الاتجاه ديناميكيًا
              textAlign: getTextAlign(context),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.emailOrPhone,
                labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                border: const OutlineInputBorder(),
                hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
              ),
              // onTap: () async {
              //   if (isFaceIdEnabled) {
              //     _showBiometricLoginSheet(); // ✅ Suggest biometric login first
              //   }
              // },
              onChanged: (value) {
                setState(() {
                  isValid = value.isNotEmpty;
                  errorMessage = null;
                });
              },
            ),
            SizedBox(height: 10.h),

            // 🔵 Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: !isPasswordVisible,
              textDirection: detectTextDirection(_inputController.text), // ✅ ضبط الاتجاه ديناميكيًا
              textAlign: getTextAlign(context),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.password,
                labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    size: 16.sp,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
              // onTap: () async {
              //   if (isFaceIdEnabled) {
              //     _showBiometricLoginSheet(); // ✅ Suggest biometric login first
              //   }
              // },
            ),
            if (errorMessage != null) SizedBox(height: 10.h),

            // 🔴 Error Message
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: AppTextStyles.getText2(context).copyWith(color: AppColors.red),
              ),

            // 🔵 بعد حقل كلمة المرور مباشرة:
            SizedBox(height: 5.h),
            Align(
              alignment: AlignmentDirectional.centerStart, // ✅ يتكيف مع اللغات RTL/LTR
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.sp),
                child: TextButton(
                  onPressed: () {
                    // 🚀 تنفيذ وظيفة استعادة كلمة المرور لاحقًا
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, // ✅ إزالة أي هوامش داخل الزر
                    minimumSize: Size(0, 0), // ✅ تقليل المساحة القابلة للنقر
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ✅ تقليل حجم الضغط
                    overlayColor: Colors.transparent, // ✅ تأثير عند النقر
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.forgotPassword, // 🔹 نص متعدد اللغات
                    style: AppTextStyles.getText3(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // ✅ Login Button
            ElevatedButton(
              onPressed: isValid ? _logInUser : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? AppColors.main : Colors.grey,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.r),
                ),
                minimumSize: Size(double.infinity, 50.h),
              ),
              child: isLoading
                  ? SizedBox(
                width: 15.w,
                height: 15.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                AppLocalizations.of(context)!.logIn,
                style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
              ),
            ),

            if (biometricAvailable)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: _authenticateWithFaceID,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 50.h),
                      child: isFaceID
                          ? Image.asset(
                        'assets/images/face_Id.png',
                        width: 65.w,
                        height: 65.w,
                        color: AppColors.main,
                      )
                          : Image.asset(
                        'assets/images/fingerprint.png',
                        width: 55.w,
                        height: 55.w,
                        color: AppColors.main,
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

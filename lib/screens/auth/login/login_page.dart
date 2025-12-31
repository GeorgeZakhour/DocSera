import 'dart:io';

import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_otp.dart';
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
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
  bool _canUseBiometric = false;


  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.preFilledInput);
    isValid = widget.preFilledInput != null && widget.preFilledInput!.isNotEmpty;
    _checkBiometricReadiness();
  }


  Future<void> _checkBiometricReadiness() async {
    // ⛔ Do not show if user already logged in
    if (Supabase.instance.client.auth.currentUser != null) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 1️⃣ Is biometric enabled in settings?
    final enabled = await BiometricStorage.isEnabled();
    if (!enabled) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 2️⃣ Are credentials saved?
    final creds = await BiometricStorage.getCredentials();
    if (creds == null) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 3️⃣ Does device support biometrics?
    final available = await auth.getAvailableBiometrics();
    if (available.isEmpty) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // ✅ READY
    setState(() {
      _canUseBiometric = true;
      isFaceID = available.contains(BiometricType.face);
    });
  }


  /// **🔐 Hash the password using SHA-256**
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

/// ✅ الحصول على معرف الجهاز بطريقة آمنة تعمل على Android و iOS
  Future<String> getDeviceId() async {
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
    } catch (e) {
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
      // ---------------------------------------------------------------------
      // 1️⃣ Read & normalize input
      // ---------------------------------------------------------------------
      var input = _inputController.text.trim();
      final password = _passwordController.text.trim();

      // 🟢 Always lowercase emails
      if (input.contains('@')) {
        input = input.toLowerCase();
      }

      final isPhone =
          RegExp(r'^0\d{9}$').hasMatch(input) ||
              RegExp(r'^00963\d{9}$').hasMatch(input);

      final formattedPhone = isPhone ? getFormattedPhoneNumber(input) : null;

      print("📥 [INPUT] المستخدم أدخل: $input");
      if (isPhone) {
        print("📞 [FORMAT] تم التعرف عليه كرقم هاتف وتم تنسيقه إلى: $formattedPhone");
      } else {
        print("📧 [FORMAT] تم التعرف عليه كإيميل: $input");
      }

      // ---------------------------------------------------------------------
      // 2️⃣ PRE-AUTH lookup (anonymous, RLS-safe)
      //    email + is_active ONLY
      // ---------------------------------------------------------------------
      final loginInfo = await _supabaseUserService.getLoginInfoByEmailOrPhone(
        isPhone ? formattedPhone! : input,
      );

      final email = loginInfo['email']?.toString();
      if (email == null || email.isEmpty) {
        throw Exception("user not found");
      }

      final isActive = loginInfo['is_active'] == true;
      if (!isActive) {
        throw Exception("account_disabled");
      }

      print("📨 [AUTH EMAIL] الإيميل المستخدم لتسجيل الدخول: $email");

      // ---------------------------------------------------------------------
      // 3️⃣ Supabase Auth (password check)
      // ---------------------------------------------------------------------
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        throw Exception("wrong password");
      }

      // 🔐 Save biometric credentials (EMAIL-BASED)
      final prefs = await SharedPreferences.getInstance();

      final isEnabled = await BiometricStorage.isEnabled();
      if (isEnabled) {
        await BiometricStorage.saveCredentials(
          email: email,
          password: password,
        );
      }



      final userId = supabaseUser.id;
      print("✅ [LOGIN SUCCESS] User ID: $userId");

      // ---------------------------------------------------------------------
      // 4️⃣ Persist minimal auth data (biometric-only)
      // ---------------------------------------------------------------------
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userEmail', email);
      await prefs.setString('userPassword', password); // biometric only

      print("💾 [SHARED PREFS] Auth data saved");

      // ---------------------------------------------------------------------
      // 5️⃣ POST-AUTH security state (RLS-safe, auth.uid())
      //    2FA + trusted devices + phone
      // ---------------------------------------------------------------------
      final securityState =
      await _supabaseUserService.getMySecurityState();

      final bool is2FAEnabled =
          securityState['two_factor_auth_enabled'] == true;

      final List trustedDevices =
          (securityState['trusted_devices'] as List?) ?? [];

      final String? phone =
      securityState['phone_number']?.toString();

      final deviceId = await getDeviceId();

      print("🛡️ [2FA] Enabled: $is2FAEnabled");
      print("🧩 [DEVICE] Current: $deviceId");
      print("🧩 [DEVICE] Trusted: ${trustedDevices.contains(deviceId)}");

      // ---------------------------------------------------------------------
      // 6️⃣ 2FA routing decision
      // ---------------------------------------------------------------------
      if (is2FAEnabled && !trustedDevices.contains(deviceId)) {
        if (phone == null || phone.isEmpty) {
          print("🚨 [2FA ERROR] Phone number missing");
          throw Exception("phone_not_available_for_2fa");
        }

        print("🚨 [2FA] Redirecting to OTP login");

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginOTPPage(
              phoneNumber: phone,
            ),
          ),
              (_) => false,
        );

        return; // ⛔ stop here
      }

      // ---------------------------------------------------------------------
      // 7️⃣ Enter app normally
      // ---------------------------------------------------------------------
      print("✅ [NAVIGATION] Entering app");

      context.read<UserCubit>().loadUserData(context);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(const CustomBottomNavigationBar()),
            (_) => false,
      );
    } catch (e) {
      print("❌ خطأ أثناء تسجيل الدخول: $e");

      String message;
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('wrong password') ||
          errorStr.contains('invalid login credentials') ||
          errorStr.contains('invalid email or password')) {
        message = AppLocalizations.of(context)!.errorWrongPassword;
      } else if (errorStr.contains('account_disabled')) {
        message = AppLocalizations.of(context)!.accountDisabled;
      } else if (errorStr.contains('user not found') ||
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

      // 🔐 Biometric credentials (EMAIL-based)
      final email = prefs.getString('biometric_login');
      final password = prefs.getString('userPassword');

      if (email == null || password == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.faceIdNoCredentials,
            ),
          ),
        );
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: biometricType == AppLocalizations.of(context)!.faceIdTitle
            ? AppLocalizations.of(context)!.faceIdPrompt
            : AppLocalizations.of(context)!.fingerprintPrompt,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) return;

      // ✅ Autofill credentials (EMAIL + PASSWORD)
      setState(() {
        _inputController.text = email;
        _passwordController.text = password;
        isValid = true;
      });

      // 🔁 Continue normal login flow
      await _logInUser();
    } catch (e) {
      debugPrint("❌ Biometric authentication error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.faceIdFailed),
        ),
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
                    minimumSize: const Size(0, 0), // ✅ تقليل المساحة القابلة للنقر
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

            if (_canUseBiometric)
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

import 'dart:io';

import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_otp.dart';
import 'package:docsera/screens/auth/forgot_password/forgot_password_page.dart';
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:crypto/crypto.dart'; // For hashing
import 'package:docsera/app/const.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:docsera/widgets/base_scaffold.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/screens/auth/sign_up/account_method_choice.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:local_auth/local_auth.dart'; // Face ID Auth
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../Business_Logic/Account_page/user_cubit.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:docsera/Business_Logic/Popups/popup_banner_cubit.dart';



class LogInPage extends StatefulWidget {
  final String? preFilledInput; // Optional pre-filled email or phone number

  const LogInPage({super.key, this.preFilledInput});

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  late TextEditingController _inputController;
  final TextEditingController _passwordController = TextEditingController();
  late final SupabaseUserService _supabaseUserService;
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

  // ── Dual Mode State ──
  bool _isPhoneMode = true; 
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  late final FocusNode _phoneFocus;
  late final FocusNode _inputFocus;
  late final FocusNode _passwordFocus;
  bool _phoneOtpSent = false;
  bool _phoneOtpSending = false;

  final RegExp _phoneRegex = RegExp(r'^09\d{8}$');

  @override
  void initState() {
    super.initState();
    _supabaseUserService = context.read<SupabaseUserService>();
    _inputController = TextEditingController(text: widget.preFilledInput);
    
    _phoneFocus = FocusNode();
    _inputFocus = FocusNode();
    _passwordFocus = FocusNode();

    isValid = widget.preFilledInput != null && widget.preFilledInput!.isNotEmpty;
    _checkBiometricReadiness();
    context.read<PopupBannerCubit>().checkBanners(); 
  }

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phoneFocus.dispose();
    _inputFocus.dispose();
    _passwordFocus.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (!_phoneRegex.hasMatch(phone)) return;
    
    setState(() { _phoneOtpSending = true; errorMessage = null; });
    try {
      final formatted = getFormattedPhoneNumber(phone);
      await _supabaseUserService.sendPhoneOtp(formatted, isLogin: true);
      setState(() { _phoneOtpSent = true; _phoneOtpSending = false; });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _otpFocusNodes[0].requestFocus();
      });
    } catch (e) {
      debugPrint("OTP Send error: $e");
      setState(() {
        _phoneOtpSending = false;
        errorMessage = AppLocalizations.of(context)!.errorGenericLogin;
      });
    }
  }

  Future<void> _submitPhoneOtp() async {
    final phone = getFormattedPhoneNumber(_phoneController.text.trim());
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) return;
    
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final response = await _supabaseUserService.phoneOtpLogin(phone, code);
      final supabaseUser = response.user;
      if (supabaseUser == null) throw Exception("Login failed");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', supabaseUser.id);
      
      if (!mounted) return;
      context.read<UserCubit>().loadUserData(context: context);

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(CustomBottomNavigationBar()),
            (_) => false,
      );
    } catch (e) {
      debugPrint("OTP Verify error: $e");
      setState(() => errorMessage = AppLocalizations.of(context)!.logInFailed);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onPhoneOtpFieldChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    if (index == 5 && value.length == 1) {
      _submitPhoneOtp();
    }
  }

  Widget _buildModeToggle() {
    return Container(
      height: 64.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.main.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _isPhoneMode ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isPhoneMode = true;
                    errorMessage = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        size: 18.sp,
                        color: _isPhoneMode ? AppColors.main : AppColors.main.withOpacity(0.4),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AppLocalizations.of(context)!.phoneLogin,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isPhoneMode ? AppColors.mainDark : AppColors.mainDark.withOpacity(0.45),
                          fontWeight: _isPhoneMode ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isPhoneMode = false;
                    errorMessage = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 18.sp,
                        color: !_isPhoneMode ? AppColors.main : AppColors.main.withOpacity(0.4),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AppLocalizations.of(context)!.emailLogin,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isPhoneMode ? AppColors.mainDark : AppColors.mainDark.withOpacity(0.45),
                          fontWeight: !_isPhoneMode ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkBiometricReadiness() async {
    debugPrint("🔍 [BIOMETRIC_DEBUG] Starting check...");

    // ⛔ Do not show if user already logged in
    if (_supabaseUserService.getCurrentUser() != null) {
      debugPrint("❌ [BIOMETRIC_DEBUG] User already logged in.");
      setState(() => _canUseBiometric = false);
      return;
    }

    // 1️⃣ Is biometric enabled in settings?
    final enabled = await BiometricStorage.isEnabled();
    debugPrint("🔍 [BIOMETRIC_DEBUG] Is enabled in settings: $enabled");
    if (!enabled) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 2️⃣ Are credentials saved?
    final creds = await BiometricStorage.getCredentials();
    debugPrint("🔍 [BIOMETRIC_DEBUG] Credentials found: ${creds != null}");
    if (creds == null) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 3️⃣ Does device support biometrics?
    final available = await auth.getAvailableBiometrics();
    debugPrint("🔍 [BIOMETRIC_DEBUG] Hardware available: $available");
    if (available.isEmpty) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // ✅ READY
    debugPrint("✅ [BIOMETRIC_DEBUG] ALL CHECKS PASSED!");
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

      debugPrint("📥 [INPUT] المستخدم أدخل: $input");
      if (isPhone) {
        debugPrint("📞 [FORMAT] تم التعرف عليه كرقم هاتف وتم تنسيقه إلى: $formattedPhone");
      } else {
        debugPrint("📧 [FORMAT] تم التعرف عليه كإيميل: $input");
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

      debugPrint("📨 [AUTH EMAIL] الإيميل المستخدم لتسجيل الدخول: $email");

      // ---------------------------------------------------------------------
      // 3️⃣ Supabase Auth (password check)
      // ---------------------------------------------------------------------
      final response = await _supabaseUserService.signInWithPassword(
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
      debugPrint("✅ [LOGIN SUCCESS] User ID: $userId");

      // ---------------------------------------------------------------------
      // 4️⃣ Persist minimal auth data (biometric-only)
      // ---------------------------------------------------------------------
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userEmail', email);
      await prefs.setString('userPassword', password); // biometric only

      debugPrint("💾 [SHARED PREFS] Auth data saved");

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

      debugPrint("🛡️ [2FA] Enabled: $is2FAEnabled");
      debugPrint("🧩 [DEVICE] Current: $deviceId");
      debugPrint("🧩 [DEVICE] Trusted: ${trustedDevices.contains(deviceId)}");

      // ---------------------------------------------------------------------
      // 6️⃣ 2FA routing decision
      // ---------------------------------------------------------------------
      // ---------------------------------------------------------------------
      // 6️⃣ New Device Check (Email OTP)
      // ---------------------------------------------------------------------
      if (!trustedDevices.contains(deviceId)) {
        debugPrint("🚨 [SECURITY] New device detected ($deviceId). Redirecting to Email OTP.");

        if (!mounted) return;
        
        // -----------------------------------------------------------------
        // 🛠️ DEBUG DIALOG (REMOVE LATER)
        // -----------------------------------------------------------------
        /*
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Debug Mode"),
            content: Text(
              "Current Device:\n$deviceId\n\nTrusted List:\n$trustedDevices\n\nIs Trusted: ${trustedDevices.contains(deviceId)}"
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        */

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginOTPPage(
              email: email, // ✅ Pass email for verification
            ),
          ),
        );

        return; // ⛔ stop here
      }

      // ---------------------------------------------------------------------
      // 7️⃣ Enter app normally
      // ---------------------------------------------------------------------
      debugPrint("✅ [NAVIGATION] Entering app");

      context.read<UserCubit>().loadUserData(context: context);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(CustomBottomNavigationBar()),
            (_) => false,
      );
    } catch (e) {
      debugPrint("❌ خطأ أثناء تسجيل الدخول: $e");

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
      // 🔐 Get credentials from Secure Storage
      final credentials = await BiometricStorage.getCredentials();

      if (credentials == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.faceIdNoCredentials,
            ),
          ),
        );
        return;
      }

      final email = credentials['email'];
      final password = credentials['password'];
      
      if (email == null || password == null) return; // Should not happen if credentials != null

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
            Text(
              AppLocalizations.of(context)!.logIn,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.mainDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              AppLocalizations.of(context)!.loginMethodDescription,
              style: TextStyle(
                fontSize: 9.sp,
                color: AppColors.mainDark.withOpacity(0.5),
                height: 1.2,
              ),
            ),
            SizedBox(height: 20.h),

            _buildModeToggle(),
            SizedBox(height: 20.h),

            if (_isPhoneMode) ...[
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                enabled: !_phoneOtpSent,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 14.sp),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                  labelText: AppLocalizations.of(context)!.phoneNumber,
                  hintText: '09XXXXXXXX',
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
                ),
                onChanged: (val) {
                  setState(() {
                    isValid = _phoneRegex.hasMatch(val);
                    errorMessage = null;
                  });
                },
              ),
              SizedBox(height: 15.h),

              if (!_phoneOtpSent)
                ElevatedButton(
                  onPressed: _phoneOtpSending || !isValid ? null : _sendPhoneOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? AppColors.main : Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                    minimumSize: Size(double.infinity, 50.h),
                  ),
                  child: _phoneOtpSending
                      ? SizedBox(
                          height: 15.h,
                          width: 15.w,
                          child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          AppLocalizations.of(context)!.sendOtp,
                          style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                        ),
                ),

              if (_phoneOtpSent) ...[
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.otpSentToPhone,
                    style: TextStyle(fontSize: 12.sp, color: AppColors.mainDark),
                  ),
                ),
                SizedBox(height: 15.h),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: SizedBox(
                          width: 40.w,
                          child: TextField(
                            controller: _otpControllers[i],
                            focusNode: _otpFocusNodes[i],
                            maxLength: 1,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.1),
                              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: BorderSide(color: AppColors.mainDark.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: AppColors.mainDark, width: 2),
                              ),
                            ),
                            onChanged: (val) => _onPhoneOtpFieldChanged(val, i),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                    FocusScope.of(context).unfocus();
                    Future.delayed(const Duration(milliseconds: 100), _submitPhoneOtp);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainDark,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                    minimumSize: Size(double.infinity, 50.h),
                  ),
                  child: isLoading
                      ? SizedBox(
                    width: 15.w,
                    height: 15.h,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                    AppLocalizations.of(context)!.logIn,
                    style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ] else ...[
              // 🟢 Email Input
              TextFormField(
                controller: _inputController,
                focusNode: _inputFocus,
                textDirection: detectTextDirection(_inputController.text),
                textAlign: getTextAlign(context),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.email,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
                  hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                ),
                onChanged: (value) {
                  setState(() {
                    isValid = value.isNotEmpty;
                    errorMessage = null;
                  });
                },
              ),
              SizedBox(height: 15.h),

              // 🔵 Password Input
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: !isPasswordVisible,
                textDirection: detectTextDirection(_passwordController.text),
                textAlign: getTextAlign(context),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.password,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
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
              ),

              if (errorMessage != null) SizedBox(height: 10.h),
              if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: AppTextStyles.getText2(context).copyWith(color: AppColors.red),
                ),

              SizedBox(height: 5.h),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.sp),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        fadePageRoute(const ForgotPasswordPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      overlayColor: Colors.transparent,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.forgotPassword,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

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
              SizedBox(height: 15.h),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountMethodChoicePage(),
                      ),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.createAnAccount,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.mainDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],

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

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/models/sign_up_info.dart';
import 'package:docsera/screens/auth/login/login_otp.dart';
import 'package:docsera/screens/auth/sign_up/sign_up_phone.dart';
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:local_auth/local_auth.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docsera/Business_Logic/Account_page/user_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LoginPage extends StatefulWidget {
  final Animation<double> backgroundHeightAnimation;
  const LoginPage({super.key, required this.backgroundHeightAnimation});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuth = LocalAuthentication();
  late final SupabaseUserService _supabaseUserService;

  bool _isAuthenticating = false;
  bool _authFailed = false;
  bool _isLoading = false;
  bool _showPassword = false;

  bool _inputEmpty = false;
  bool _passwordEmpty = false;
  final bool _biometricAvailable = false;
  bool _isFaceID = false;
  bool _canUseBiometric = false;


  final Random _random = Random();
  List<_AnimatedLogo> _logos = [];
  bool _logosVisible = true;
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _supabaseUserService = context.read<SupabaseUserService>();
    _getAppVersion();
    _generateLogos();
    _startAnimationLoop();

    _checkBiometricReadiness();
    _tryAutoBiometricLogin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputController.dispose();
    super.dispose();
  }



  Future<void> _checkBiometricReadiness() async {
    debugPrint("🔍 [BIOMETRIC_DEBUG_START] Starting check...");

    // ⛔ إذا المستخدم مسجّل دخول، لا نعرض الزر
    if (_supabaseUserService.getCurrentUser() != null) {
      debugPrint("❌ [BIOMETRIC_DEBUG_START] User already logged in.");
      setState(() => _canUseBiometric = false);
      return;
    }

    // 1️⃣ هل البيومتريك مفعّل من الإعدادات؟
    final enabled = await BiometricStorage.isEnabled();
    debugPrint("🔍 [BIOMETRIC_DEBUG_START] Is enabled in settings: $enabled");
    if (!enabled) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 2️⃣ هل هناك Credentials محفوظة؟
    final creds = await BiometricStorage.getCredentials();
    debugPrint("🔍 [BIOMETRIC_DEBUG_START] Credentials found: ${creds != null}");
    if (creds == null) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // 3️⃣ هل الجهاز يدعم Biometric؟
    final available = await _localAuth.getAvailableBiometrics();
    debugPrint("🔍 [BIOMETRIC_DEBUG_START] Hardware available: $available");
    if (available.isEmpty) {
      setState(() => _canUseBiometric = false);
      return;
    }

    // ✅ جاهز 100%
    debugPrint("✅ [BIOMETRIC_DEBUG_START] ALL CHECKS PASSED!");
    setState(() {
      _canUseBiometric = true;
      _isFaceID = available.contains(BiometricType.face);
    });
  }



  void _getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = 'v${info.version}';
    });
  }

  void _generateLogos() {
    _logos = List.generate(12, (index) {
      return _AnimatedLogo(
        random: _random,
        logoPath: _getRandomLogo(),
        delay: _random.nextInt(5),
      );
    });
  }

  String _getRandomLogo() {
    List<String> logos = [
      'assets/images/DocSera-shape-main.svg',
      'assets/images/DocSera-shape-main2.svg',
      'assets/images/DocSera-shape-main3.svg',
    ];
    return logos[_random.nextInt(logos.length)];
  }

  Timer? _timer;

  void _startAnimationLoop() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      setState(() => _logosVisible = false);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _generateLogos();
          _logosVisible = true;
        });
      });
    });
  }




  Future<void> _authenticateBiometric() async {
    try {
      setState(() => _isAuthenticating = true);

      // 🔐 Get credentials from Secure Storage
      final credentials = await BiometricStorage.getCredentials();

      if (credentials == null) {
        setState(() {
          _authFailed = true;
          _isAuthenticating = false;
        });
        return;
      }

      final email = credentials['email'];
      final password = credentials['password'];

      if (email == null || password == null) return;

      final authenticated = await _localAuth.authenticate(
        localizedReason: AppLocalizations.of(context)!.biometricPrompt,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) {
        setState(() {
          _authFailed = true;
          _isAuthenticating = false;
        });
        return;
      }

      // ✅ Autofill credentials (EMAIL + PASSWORD)
      _inputController.text = email;
      _passwordController.text = password;

      // 🔁 Continue normal login flow
      await _loginWithCredentials();
    } catch (e) {
      debugPrint("❌ Biometric auth error: $e");
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _tryAutoBiometricLogin() async {
    // 1. Check if enabled
    final isBiometricEnabled = await BiometricStorage.isEnabled();

    // 2. Check if credentials exist in Secure Storage
    final credentials = await BiometricStorage.getCredentials();

    debugPrint("🟢 [BIOMETRIC] Enabled: $isBiometricEnabled");
    debugPrint("🟢 [BIOMETRIC] Credentials found: ${credentials != null}");

    // ⛔ لا تحاول البيومتريك إذا كان المستخدم مسجّل دخول أصلًا
    if (_supabaseUserService.getCurrentUser() != null) return;

    if (!isBiometricEnabled || credentials == null) return;

    // ⏱ تأخير بسيط حتى يستقر الـ UI
    Future.delayed(
      const Duration(milliseconds: 300),
      _authenticateBiometric,
    );
  }



  Future<void> _loginWithCredentials() async {
    FocusScope.of(context).unfocus();

    var input = _inputController.text.trim();
    final password = _passwordController.text.trim();

    // 🟢 Always lowercase emails
    if (input.contains('@')) {
      input = input.toLowerCase();
    }

    setState(() {
      _inputEmpty = input.isEmpty;
      _passwordEmpty = password.isEmpty;
      _authFailed = false;
    });

    if (_inputEmpty || _passwordEmpty) return;

    setState(() => _isLoading = true);

    try {
      // ---------------------------------------------------------------------
      // 1️⃣ Detect phone vs email + normalize
      // ---------------------------------------------------------------------
      final isPhone =
          RegExp(r'^0\d{9}$').hasMatch(input) ||
              RegExp(r'^00963\d{9}$').hasMatch(input);

      final formattedInput =
      isPhone ? _formatPhone(input) : input;

      debugPrint("📥 [INPUT] المستخدم أدخل: $input");
      if (isPhone) {
        debugPrint("📞 [FORMAT] رقم هاتف بعد التنسيق: $formattedInput");
      } else {
        debugPrint("📧 [FORMAT] إيميل");
      }

      // ---------------------------------------------------------------------
      // 2️⃣ PRE-AUTH lookup (anonymous, RLS-safe)
      // ---------------------------------------------------------------------
      final loginInfo =
      await _supabaseUserService.getLoginInfoByEmailOrPhone(
        formattedInput,
      );

      final email = loginInfo['email']?.toString();
      if (email == null || email.isEmpty) {
        throw Exception("user not found");
      }

      final isActive = loginInfo['is_active'] == true;
      if (!isActive) {
        // ⛔ Do NOT authenticate disabled accounts
        throw Exception("account_disabled");
      }

      debugPrint("📨 [AUTH EMAIL] $email");

      // ---------------------------------------------------------------------
      // 3️⃣ Supabase Auth (password validation)
      // ---------------------------------------------------------------------
      final response =
      await _supabaseUserService.signInWithPassword(
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
      debugPrint("✅ [LOGIN SUCCESS] userId = $userId");

      // ---------------------------------------------------------------------
      // 4️⃣ Persist minimal auth data (biometric only)
      // ---------------------------------------------------------------------
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userEmail', email);
      await prefs.setString('userPassword', password);

      debugPrint("💾 [PREFS] Saved auth credentials");

      // ---------------------------------------------------------------------
      // 5️⃣ POST-AUTH security state (RLS-safe, auth.uid)
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
      // 6️⃣ 2FA routing
      // ---------------------------------------------------------------------
      // ---------------------------------------------------------------------
      // 6️⃣ New Device Check (Email OTP)
      // ---------------------------------------------------------------------
      if (!trustedDevices.contains(deviceId)) {
        debugPrint("🚨 [SECURITY] New device detected ($deviceId). Redirecting to Email OTP.");

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginOTPPage(
              email: email, // ✅ Pass email for verification
            ),
          ),
        );

        return; // ⛔ stop normal navigation
      }

      // ---------------------------------------------------------------------
      // 7️⃣ Enter app normally
      // ---------------------------------------------------------------------
      debugPrint("✅ [NAVIGATION] Entering app");

      context.read<UserCubit>().loadUserData(context: context);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomBottomNavigationBar(),
        ),
      );
    } catch (e) {
      debugPrint("❌ Login failed: $e");

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

      setState(() => _authFailed = true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, textAlign: TextAlign.center),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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


  String _formatPhone(String phone) {
    phone = phone.trim();
    if (phone.startsWith('09')) {
      phone = phone.substring(1);
    }
    return '00963$phone';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bgHeight = widget.backgroundHeightAnimation.value;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          // الخلفية المنحنية
          AnimatedBuilder(
            animation: widget.backgroundHeightAnimation,
            builder: (_, __) {
              return Align(
                alignment: Alignment.topCenter,
                child: ClipPath(
                  clipper: CustomTopBarClipper(),
                  child: Container(
                    width: screenWidth,
                    height: bgHeight,
                    color: AppColors.main,
                  ),
                ),
              );
            },
          ),

          // لوجو التطبيق العلوي
          Positioned(
            top: bgHeight / 2 - 30.h,
            left: screenWidth / 2 - 55.w,
            right: screenWidth / 2 - 55.w,
            child: AnimatedOpacity(
              opacity: isKeyboardVisible ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: SvgPicture.asset(
                'assets/images/docsera_white.svg',
                height: 45.h,
                width: 45.w,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),

          // الشعارات المتحركة
          Positioned.fill(
            top: bgHeight,
            child: Stack(
              children: _logos.map((logo) => logo.build(context, _logosVisible)).toList(),
            ),
          ),

          // المحتوى الرئيسي
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: isKeyboardVisible ? 120.h : 250.h,
                  ),
                  Text(
                    AppLocalizations.of(context)!.logIn,
                    style: AppTextStyles.getTitle1(context).copyWith(
                      color: Colors.white.withOpacity(isKeyboardVisible ? 0.9 : 0.7),
                      fontSize: isKeyboardVisible ? 14.sp : 11.sp,
                    ),
                  ),
                  SizedBox(height: isKeyboardVisible ? 25.h : 15.h),

                  TextField(
                    controller: _inputController,
                    textAlign: getTextAlign(context),
                    textDirection: detectTextDirection(_inputController.text),
                    keyboardType: TextInputType.emailAddress, // ✅ Email friendly keyboard
                    style: TextStyle(fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.emailOrPhone,
                      hintStyle: TextStyle(fontSize: 12.sp),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: _inputEmpty ? AppColors.orangeText : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textAlign: getTextAlign(context),
                    textDirection: detectTextDirection(_passwordController.text),
                    style: TextStyle(fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.password,
                      hintStyle: TextStyle(fontSize: 12.sp),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                          color: _passwordEmpty ? AppColors.orangeText : Colors.transparent,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),

                  if (_authFailed)
                    Padding(
                      padding: EdgeInsets.only(top: 10.h),
                      child: Text(
                        AppLocalizations.of(context)!.logInFailed,
                        style: TextStyle(color: AppColors.orangeText, fontSize: 9.sp),
                      ),
                    ),

                  SizedBox(height: 20.h),

                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                      FocusScope.of(context).unfocus(); // إغلاق الكيبورد
                      Future.delayed(const Duration(milliseconds: 100), _loginWithCredentials);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainDark,
                      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                      height: 18.w,
                      width: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(
                      AppLocalizations.of(context)!.logIn,
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ),

                  if (_supabaseUserService.getCurrentUser() == null) ...[
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SignUpFirstPage(signUpInfo: SignUpInfo()),
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
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),

          // زر الإغلاق للدخول كزائر
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            right: Directionality.of(context) == TextDirection.ltr ? 16.w : null,
            left: Directionality.of(context) == TextDirection.rtl ? 16.w : null,
            child: GestureDetector(
              onTap: () async {
                FocusScope.of(context).unfocus(); // إغلاق الكيبورد
                await Future.delayed(const Duration(milliseconds: 150));

                if (_supabaseUserService.getCurrentUser() != null) {
                  await _supabaseUserService.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('isLoggedIn');
                  await prefs.remove('userId');
                  await prefs.remove('userName');
                  await prefs.remove('userEmail');
                }

                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => CustomBottomNavigationBar()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _supabaseUserService.getCurrentUser() == null
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 18.w, color: Colors.white),
                    SizedBox(width: 6.w),
                    Text(
                      AppLocalizations.of(context)!.continueAsGuest,
                      style: TextStyle(color: Colors.white, fontSize: 10.sp),
                    ),
                  ],
                )
                    : Icon(Icons.close, size: 22.w, color: Colors.white),
              ),
            ),
          ),


          if (!_isAuthenticating && _canUseBiometric)
            Positioned(
              bottom: isKeyboardVisible ? 40.h : 65.h,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _authenticateBiometric,
                child: _isFaceID
                    ? Image.asset(
                  'assets/images/face_Id.png',
                  width: isKeyboardVisible ? 55.w : 65.w,
                  height: isKeyboardVisible ? 55.w : 65.w,
                  color: AppColors.main,
                )
                    : Image.asset(
                  'assets/images/fingerprint.png',
                  width: isKeyboardVisible ? 55.w : 65.w,
                  height: isKeyboardVisible ? 55.w : 65.w,
                  color: AppColors.main,
                ),
              ),
            ),


          if (!isKeyboardVisible) ...[
            Positioned(
              bottom: 25,
              left: 0,
              right: 0,
              child: Text(
                appVersion,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText4(context).copyWith(
                  color: AppColors.grayMain,
                  fontWeight: FontWeight.w300,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ✅ شعار متحرك مع Fade In
class _AnimatedLogo {
  final Random random;
  final String logoPath;
  double size;
  double opacity;
  double blur;
  double left;
  double top;
  double moveX;
  double moveY;
  int delay;

  _AnimatedLogo({required this.random, required this.logoPath, required this.delay})
      : size = random.nextDouble() * 15 + 20,
        opacity = random.nextDouble() * 0.5 + 0.5,
        left = random.nextDouble() * 350,
        top = random.nextDouble() * 400 + 20,
        moveX = random.nextDouble() * 60 - 30,
        moveY = random.nextDouble() * 60 - 30,
        blur = 5 + (random.nextDouble() * 8);

  Widget build(BuildContext context, bool isVisible) {
    return Positioned(
      left: left.w,
      top: top.h,
      child: TweenAnimationBuilder<double>(
        duration: Duration(seconds: isVisible ? 12 : 3),
        tween: Tween(begin: isVisible ? 0 : opacity, end: isVisible ? opacity : 0.0),
        builder: (context, value, child) {
          return AnimatedContainer(
            duration: const Duration(seconds: 8),
            transform: Matrix4.translationValues(moveX, moveY, 0),
            child: Opacity(
              opacity: value,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: blur,
                      color: Colors.white.withOpacity(0.3),
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: SvgPicture.asset(
                  logoPath,
                  height: size.h,
                  width: size.w,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.25),
                    BlendMode.lighten,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

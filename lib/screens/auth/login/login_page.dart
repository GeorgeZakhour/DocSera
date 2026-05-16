import 'dart:async';
import 'dart:io';

import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_otp.dart';
import 'package:docsera/screens/auth/forgot_password/forgot_password_page.dart';
import 'package:docsera/services/biometrics/biometric_storage.dart';
import 'package:docsera/services/supabase/user/supabase_user_service.dart';
import 'package:docsera/utils/text_direction_utils.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/screens/home/account/pending_deletion_page.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:flutter/foundation.dart';
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
import 'package:package_info_plus/package_info_plus.dart';



class LogInPage extends StatefulWidget {
  final String? preFilledInput; // Optional pre-filled email or phone number

  const LogInPage({super.key, this.preFilledInput});

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> with SingleTickerProviderStateMixin {
  late TextEditingController _inputController;
  final TextEditingController _passwordController = TextEditingController();
  late final AnimationController _shakeController;
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
  late final FocusNode _phoneFocus;
  late final FocusNode _inputFocus;
  late final FocusNode _passwordFocus;

  final RegExp _phoneRegex = RegExp(r'^09\d{8}$');


  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _supabaseUserService = context.read<SupabaseUserService>();

    // Auto-route to the phone tab when the pre-filled value is a
    // local-format phone (`09…`) rather than an email — typical case
    // is the duplicate-phone dialog routing the user to login with
    // their phone pre-filled.
    final preFilled = widget.preFilledInput ?? '';
    final looksLikePhone = RegExp(r'^09\d{0,8}$').hasMatch(preFilled);
    if (looksLikePhone) {
      _isPhoneMode = true;
      _phoneController.text = preFilled;
      _inputController = TextEditingController();
    } else {
      _isPhoneMode = false;
      _inputController = TextEditingController(text: preFilled);
    }

    _phoneFocus = FocusNode();
    _inputFocus = FocusNode();
    _passwordFocus = FocusNode();

    isValid = preFilled.isNotEmpty;
    _checkBiometricReadiness();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        context.read<PopupBannerCubit>().checkBanners(appVersion: info.version);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phoneFocus.dispose();
    _inputFocus.dispose();
    _passwordFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Phone + password daily login. Mirrors [_logInUser] (email path)
  /// except the auth call uses the synthetic-email shim hidden inside
  /// [signInWithPhonePassword]. Post-auth security (2FA / new device)
  /// is identical — the user goes through [LoginOTPPage] when the
  /// device isn't trusted yet.
  Future<void> _logInUserWithPhonePassword() async {
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final phone = getFormattedPhoneNumber(_phoneController.text.trim());
      final password = _passwordController.text.trim();

      // 1. Auth via synthetic email shim
      final response = await _supabaseUserService.signInWithPhonePassword(
        phone: phone,
        password: password,
      );
      final supabaseUser = response.user;
      if (supabaseUser == null) {
        throw Exception("wrong password");
      }
      final userId = supabaseUser.id;

      // 2. Persist for biometrics / quick relaunch
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = await BiometricStorage.isEnabled();
      if (isEnabled) {
        // Biometric storage is keyed on email today. We use the
        // synthetic email so a future biometric login replays the
        // exact same shim.
        await BiometricStorage.saveCredentials(
          email: '$phone@phone.docsera.app'
              .replaceAll('+', '00')
              .toLowerCase(),
          password: password,
        );
      }
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userPhone', phone);

      // 3. Same post-auth security flow as the email path
      final securityState = await _supabaseUserService.getMySecurityState();
      final List trustedDevices =
          (securityState['trusted_devices'] as List?) ?? [];
      final deviceId = await getDeviceId();

      if (!trustedDevices.contains(deviceId)) {
        // 2FA step-up. Prefer email when there's a real one on file
        // (cheaper, more reliable than SMS in Syria). Fall back to
        // SMS for phone-only patients. Don't pass empty strings —
        // LoginOTPPage branches on null vs non-null and would route
        // to email + fail with `send_email_otp` if we passed `''`.
        final realEmail =
            (securityState['email'] as String?)?.trim() ?? '';
        final realPhone =
            (securityState['phone_number'] as String?)?.trim() ?? phone;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginOTPPage(
              email: realEmail.isNotEmpty ? realEmail : null,
              phoneNumber: realEmail.isEmpty ? realPhone : null,
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      context.read<UserCubit>().loadUserData(context: context);

      // Grace-window check (Tier 2 deletion in progress) — same as the
      // email path. We could fold this into rpc_get_login_info but the
      // phone+password path doesn't currently hit that RPC, so query
      // status directly post-auth.
      if (await _isInDeletionGraceWindow()) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const PendingDeletionPage()),
          (_) => false,
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        fadePageRoute(CustomBottomNavigationBar()),
            (_) => false,
      );
    } on AuthException catch (_) {
      // Could be a real wrong password OR a legacy phone-OTP-only
      // account that never set one. Ask the server which it is so we
      // can route the user straight to forgot-password instead of
      // dead-ending them at "wrong password".
      await _handleAuthFailureForLegacy(_phoneController.text.trim());
    } catch (e) {
      debugPrint("Phone+password login error: $e");
      setState(() => errorMessage = AppLocalizations.of(context)!.logInFailed);
      _shakeController.forward(from: 0);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Returns true if the freshly-authenticated user has an open Tier 2
  /// deletion request still inside the 30-day grace window. Used by
  /// both the email and phone login paths to route to PendingDeletionPage
  /// instead of dropping the user on home.
  Future<bool> _isInDeletionGraceWindow() async {
    try {
      final res = await Supabase.instance.client
          .rpc('rpc_get_account_deletion_status');
      if (res is! Map) return false;
      final raw = res['deletion_requested_at']?.toString();
      if (raw == null || raw.isEmpty) return false;
      final dt = DateTime.tryParse(raw)?.toUtc();
      if (dt == null) return false;
      return DateTime.now().toUtc().difference(dt).inDays < 30;
    } catch (_) {
      return false;
    }
  }

  /// Differentiates "wrong password" from "this user pre-dates the
  /// password requirement and has never set one". Legacy users go
  /// directly to the forgot-password screen with a friendly nudge;
  /// genuine wrong passwords get the usual error.
  Future<void> _handleAuthFailureForLegacy(String identifier) async {
    String status = 'has_password';
    try {
      status = await _supabaseUserService.checkPasswordStatus(identifier);
    } catch (_) {
      // Fall through to plain wrong-password handling — better than
      // blocking the user on a backend hiccup.
    }

    if (!mounted) return;

    if (status == 'legacy_no_password') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.legacyAccountSetPasswordPrompt),
          duration: const Duration(seconds: 4),
        ),
      );
      // Pre-select the channel matching what the user typed: phone tab
      // when this came from the phone+password path, email otherwise.
      Navigator.push(
        context,
        fadePageRoute(ForgotPasswordPage(
          initialPhoneMode: _isPhoneMode,
          prefilledIdentifier: _isPhoneMode
              ? _phoneController.text.trim()
              : _inputController.text.trim(),
        )),
      );
      return;
    }

    setState(() => errorMessage = AppLocalizations.of(context)!.logInFailed);
    _shakeController.forward(from: 0);
  }

  Widget _buildModeToggle() {
    return Container(
      height: 64.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.main.withValues(alpha: 0.08),
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
                    color: Colors.black.withValues(alpha: 0.06),
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
                        color: _isPhoneMode ? AppColors.main : AppColors.main.withValues(alpha: 0.4),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AppLocalizations.of(context)!.phoneLogin,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isPhoneMode ? AppColors.mainDark : AppColors.mainDark.withValues(alpha: 0.45),
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
                        color: !_isPhoneMode ? AppColors.main : AppColors.main.withValues(alpha: 0.4),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AppLocalizations.of(context)!.emailLogin,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isPhoneMode ? AppColors.mainDark : AppColors.mainDark.withValues(alpha: 0.45),
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

      // A phone-only user (signed up via phone OTP, never set an email)
      // returns is_active + user_id but a null email. We still proceed —
      // the actual auth call below uses signInWithPhonePassword (synthetic
      // email shim) when no real email is on file.
      final email = loginInfo['email']?.toString();
      if (!isPhone && (email == null || email.isEmpty)) {
        throw Exception("user not found");
      }
      if (isPhone && email == null && loginInfo['user_id'] == null) {
        throw Exception("user not found");
      }

      final isActive = loginInfo['is_active'] == true;
      // Distinguish a soft "deletion pending" deactivation (the 30-day grace
      // window after rpc_request_account_deletion) from a hard ban. The
      // former MUST allow login so the user can reach the cancel-deletion
      // screen — they were trapped behind the same accountDisabled message
      // before this branch existed.
      final deletionRequestedAtRaw = loginInfo['deletion_requested_at']?.toString();
      final deletionRequestedAt = (deletionRequestedAtRaw == null || deletionRequestedAtRaw.isEmpty)
          ? null
          : DateTime.tryParse(deletionRequestedAtRaw)?.toUtc();
      final isInGraceWindow = deletionRequestedAt != null &&
          DateTime.now().toUtc().difference(deletionRequestedAt).inDays < 30;
      if (!isActive && !isInGraceWindow) {
        throw Exception("account_disabled");
      }

      // Don't log the email — it's PII. Outcome will be logged below.

      // ---------------------------------------------------------------------
      // 3️⃣ Supabase Auth (password check)
      //    For email signups: signInWithPassword(email, password).
      //    For phone-only signups: signInWithPhonePassword shims through
      //    the synthetic <e164>@phone.docsera.app email the signup flow
      //    stamped on auth.users.
      // ---------------------------------------------------------------------
      final response = isPhone && (email == null || email.isEmpty)
          ? await _supabaseUserService.signInWithPhonePassword(
              phone: formattedPhone!,
              password: password,
            )
          : await _supabaseUserService.signInWithPassword(
              email: email!,
              password: password,
            );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        throw Exception("wrong password");
      }

      // Resolve the email we'll use for biometric save and downstream
      // session bookkeeping. For phone-only users the auth.users.email
      // is the synthetic shim — that's fine, biometric login uses it
      // verbatim on subsequent attempts.
      final resolvedEmail = supabaseUser.email ?? email ?? '';

      // 🔐 Save biometric credentials
      final prefs = await SharedPreferences.getInstance();

      final isEnabled = await BiometricStorage.isEnabled();
      if (isEnabled) {
        await BiometricStorage.saveCredentials(
          email: resolvedEmail,
          password: password,
        );
      }



      final userId = supabaseUser.id;
      debugPrint("✅ [LOGIN SUCCESS] User ID: $userId");

      // ---------------------------------------------------------------------
      // 4️⃣ Persist minimal auth data (NO plaintext password — biometric
      //    credentials live in flutter_secure_storage via BiometricStorage)
      // ---------------------------------------------------------------------
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userId);
      await prefs.setString('userEmail', resolvedEmail);

      // Defense-in-depth: scrub any legacy plaintext password that may have
      // been persisted by older builds before the security review.
      if (prefs.containsKey('userPassword')) {
        await prefs.remove('userPassword');
      }

      if (kDebugMode) debugPrint("💾 [SHARED PREFS] Auth data saved");

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
              email: resolvedEmail.isNotEmpty ? resolvedEmail : null,
            ),
          ),
        );

        return; // ⛔ stop here
      }

      // ---------------------------------------------------------------------
      // 7️⃣ Enter app normally — except when deletion is pending. In that
      //    case route directly to PendingDeletionPage so the user lands on
      //    the cancel-deletion control instead of being dropped into the
      //    main app where features they no longer have access to would
      //    silently fail.
      // ---------------------------------------------------------------------
      debugPrint("✅ [NAVIGATION] Entering app");

      context.read<UserCubit>().loadUserData(context: context);

      if (!mounted) return;

      if (isInGraceWindow) {
        Navigator.pushAndRemoveUntil(
          context,
          fadePageRoute(const PendingDeletionPage()),
          (_) => false,
        );
        return;
      }

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
        // Could be a real wrong password OR a legacy phone-OTP-only
        // user trying to log in via email. Ask the server. If legacy,
        // route to forgot-password with a friendly nudge instead of
        // dead-ending them on "wrong password".
        await _handleAuthFailureForLegacy(_inputController.text.trim());
        return;
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

      // Detect a phone-signed-up account: biometrics for those was
      // saved with the synthetic email shim (00963…@phone.docsera.app).
      // Don't expose that internal identifier in the email field —
      // strip it back to the local phone (09…) and route through the
      // phone-tab login flow instead.
      final syntheticMatch = RegExp(
        r'^00963(\d{9})@phone\.docsera\.app$',
      ).firstMatch(email);

      if (syntheticMatch != null) {
        final localPhone = '0${syntheticMatch.group(1)}';
        setState(() {
          _isPhoneMode = true;
          _phoneController.text = localPhone;
          _passwordController.text = password;
          _inputController.text = '';
          isValid = true;
        });
        await _logInUserWithPhonePassword();
        return;
      }

      // Real email — autofill the email tab and clear the phone tab so
      // a manual toggle doesn't surface stale data from a previous run.
      setState(() {
        _isPhoneMode = false;
        _inputController.text = email;
        _passwordController.text = password;
        _phoneController.text = '';
        isValid = true;
      });
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
                color: AppColors.mainDark.withValues(alpha: 0.5),
                height: 1.2,
              ),
            ),
            SizedBox(height: 20.h),

            _buildModeToggle(),
            SizedBox(height: 20.h),

            if (_isPhoneMode) ...[
              // ── Phone + password daily login ───────────────────
              // Replaces the previous phone-OTP daily login. The OTP
              // path is reserved for verification moments (signup,
              // password reset, contact change, new-device step-up).
              // Field design intentionally mirrors the email tab —
              // no prefix icon, label-as-hint, start-aligned text.
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textDirection: detectTextDirection(_phoneController.text),
                textAlign: getTextAlign(context),
                style: TextStyle(fontSize: 14.sp),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.phoneNumber,
                  hintText: AppLocalizations.of(context)!.phoneNumber,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
                ),
                onChanged: (val) {
                  setState(() {
                    isValid = _phoneRegex.hasMatch(val) &&
                        _passwordController.text.isNotEmpty;
                    errorMessage = null;
                  });
                },
              ),
              SizedBox(height: 15.h),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: !isPasswordVisible,
                textDirection: detectTextDirection(_passwordController.text),
                textAlign: getTextAlign(context),
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.password,
                  hintText: AppLocalizations.of(context)!.password,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      size: 16.sp,
                    ),
                    onPressed: () => setState(
                        () => isPasswordVisible = !isPasswordVisible),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    isValid = _phoneRegex.hasMatch(_phoneController.text.trim()) &&
                        val.isNotEmpty;
                    errorMessage = null;
                  });
                },
                onFieldSubmitted: (_) {
                  if (isValid && !isLoading) _logInUserWithPhonePassword();
                },
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
                        fadePageRoute(ForgotPasswordPage(
                          initialPhoneMode: true,
                          prefilledIdentifier: _phoneController.text.trim(),
                        )),
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
              SizedBox(height: 15.h),
              ElevatedButton(
                onPressed: isLoading || !isValid
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        _logInUserWithPhonePassword();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? AppColors.main : Colors.grey,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 15.h,
                        width: 15.w,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        AppLocalizations.of(context)!.logIn,
                        style: AppTextStyles.getText2(context).copyWith(color: Colors.white),
                      ),
              ),

            ] else ...[
              // 🟢 Email Input
              TextFormField(
                controller: _inputController,
                focusNode: _inputFocus,
                textDirection: detectTextDirection(_inputController.text),
                textAlign: getTextAlign(context),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => FocusScope.of(context).requestFocus(_passwordFocus),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.email,
                  hintText: AppLocalizations.of(context)!.email,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r)),
                  hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey.withValues(alpha: 0.5)),
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
                  hintText: AppLocalizations.of(context)!.password,
                  labelStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey),
                  hintStyle: AppTextStyles.getText2(context).copyWith(color: Colors.grey.withValues(alpha: 0.5)),
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
                        fadePageRoute(ForgotPasswordPage(
                          initialPhoneMode: false,
                          prefilledIdentifier: _inputController.text.trim(),
                        )),
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
                        'assets/images/face_Id.webp',
                        width: 65.w,
                        height: 65.w,
                        color: AppColors.main,
                      )
                          : Image.asset(
                        'assets/images/fingerprint.webp',
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

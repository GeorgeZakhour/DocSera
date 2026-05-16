import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/auth/login/login_start.dart';
import 'package:docsera/screens/home/account/pending_deletion_page.dart';
import 'package:docsera/services/notifications/notification_service.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'dart:async';
import 'dart:math';
import 'Business_Logic/Authentication/auth_cubit.dart';
import 'Business_Logic/Authentication/auth_state.dart';
import 'app/const.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/app_config/app_config_service.dart';
import 'screens/misc/force_update_screen.dart';
import 'widgets/legal_reconsent_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  late AnimationController _rotationController;
  late AnimationController _sizeController;
  late AnimationController _shiftController;
  late AnimationController _textFadeController;
  late AnimationController _fadeOutController;
  late AnimationController _backgroundShiftController;
  late AnimationController _bottomTextFadeController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _shiftAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _backgroundHeightAnimation;
  late Animation<double> _bottomTextFadeAnimation;

  double screenHeight = 0;
  double screenWidth = 0;

  // الهدف النهائي: StatusBar/Notch + AppBar + TopSection(30%)
  double _topTargetHeight = 0.0;

  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersionSafely();
  }

  Future<void> _loadVersionSafely() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final ver = info.version.trim();
      if (mounted) setState(() => appVersion = ver.isNotEmpty ? 'v$ver' : '');
    } catch (_) {
      if (mounted) setState(() => appVersion = '');
    }
  }

  // نفس ما يظهر في Main: AppBar + TopSection(0.30 من ارتفاع الشاشة)
  double _computeTopTargetHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final padTop = MediaQuery.of(context).padding.top; // للنوتش/الستاتس بار
    const topSectionFactor = 0.30; // مطابق لـ TopSection
    const appBarHeight = kToolbarHeight; // ارتفاع الـAppBar القياسي
    return padTop + appBarHeight + h * topSectionFactor;
  }

  void _initAnimations() {
    _fadeInController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _rotationController = AnimationController(duration: const Duration(seconds: 3), vsync: this);
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi * 2).animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOut));

    _sizeController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _sizeAnimation = Tween<double>(begin: 160, end: 30).animate(CurvedAnimation(parent: _sizeController, curve: Curves.easeOut));

    _shiftController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _shiftAnimation = Tween<double>(begin: 0, end: -screenWidth * 0.25).animate(CurvedAnimation(parent: _shiftController, curve: Curves.easeInOut));

    _textFadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _textFadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textFadeController, curve: Curves.easeIn));

    _fadeOutController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeOutAnimation = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn));

    _bottomTextFadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _bottomTextFadeAnimation = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _bottomTextFadeController, curve: Curves.easeIn));

    _backgroundShiftController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    // النهاية = الهدف المحسوب (AppBar + TopSection)
    _backgroundHeightAnimation = Tween<double>(
      begin: screenHeight * 0.95,
      end: _topTargetHeight,
    ).animate(CurvedAnimation(parent: _backgroundShiftController, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;

    // احسب الهدف قبل تهيئة الأنيميشن
    _topTargetHeight = _computeTopTargetHeight(context);

    _initAnimations();
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _fadeInController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _rotationController.forward();
    _sizeController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    _shiftController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textFadeController.forward();
    await Future.delayed(const Duration(milliseconds: 1000));
    _fadeOutController.forward();
    _bottomTextFadeController.forward();
    _backgroundShiftController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    await _waitForAuthReady();

    if (!mounted) return;
    final updateCheck = await AppConfigService.instance.check();
    if (updateCheck.forceUpdate) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ForceUpdateScreen(
            storeUrl: updateCheck.storeUrl,
            messageEn: updateCheck.messageEn,
            messageAr: updateCheck.messageAr,
          ),
        ),
      );
      return;
    }

    final authCubit = context.read<AuthCubit>();
    final state = authCubit.state;
    final biometricRequired = await _isBiometricRequired();

    if (state is AuthAuthenticated && !biometricRequired) {
      // Pending-deletion check: a session can be valid AND the user can
      // still be inside the 30-day deletion grace window. Route them
      // straight to PendingDeletionPage so they don't pop into a
      // partially-functional home with an account that's scheduled to
      // close. UserCubit's silent path (no auto-signout for grace-window
      // state) used to drop them onto home with no signpost.
      if (await _isPendingDeletion()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          fadePageRoute(const PendingDeletionPage()),
        );
        return;
      }

      // Trusted-device gate. Password-auth created a Supabase session,
      // but until the user completes the new-device OTP the session is
      // not "real". Closing the app at the OTP screen and reopening
      // should drop the user back at the start of login, not silently
      // resume into home OR resume into a half-finished OTP flow.
      // So: if this device isn't in trusted_devices, sign out cleanly
      // and route to LoginPage (the canonical start). Treat the
      // password auth as abandoned.
      if (await _isUntrustedDevice()) {
        try {
          await NotificationService.instance.deleteToken();
        } catch (_) { /* best effort */ }
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginPage(
              backgroundHeightAnimation: _backgroundHeightAnimation,
            ),
          ),
        );
        return;
      }

      _navigateToHomeScreen();
    } else {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            backgroundHeightAnimation: _backgroundHeightAnimation,
          ),
        ),
      );
    }
  }

  void _navigateToHomeScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1400), // 🟢 اجعلها أطول قليلاً
        pageBuilder: (context, animation, secondaryAnimation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut, // ✅ يجعل الـ fade سلس جداً
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: LegalReconsentGate(child: CustomBottomNavigationBar()),
          );
        },
      ),
    );
  }

  Future<void> _waitForAuthReady() async {
    final authCubit = context.read<AuthCubit>();
    AppAuthState state = authCubit.state;
    if (state is AuthInitial || state is AuthLoading) {
      await authCubit.stream.firstWhere(
            (newState) => newState is AuthAuthenticated || newState is AuthUnauthenticated,
      );
    }
  }

  Future<bool> _isBiometricRequired() async {
    return false;
  }

  /// Returns true if the current physical device is NOT in the user's
  /// trusted_devices array. The splash routes such users back to login
  /// start (after clean signOut) so an abandoned OTP flow doesn't
  /// silently resume into the app on the next cold start.
  ///
  /// Errors fall through to false (don't trap the user) — backend
  /// hiccup shouldn't kick anyone to login.
  Future<bool> _isUntrustedDevice() async {
    try {
      final security = await Supabase.instance.client
          .rpc('rpc_get_my_security_state');
      if (security is! Map) return false;
      final List trustedDevices =
          (security['trusted_devices'] as List?) ?? const [];
      final deviceId = await _getDeviceId();
      return !trustedDevices.contains(deviceId);
    } catch (_) {
      return false;
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? 'ios-unknown';
      }
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id;
      }
      return 'unknown-platform';
    } catch (_) {
      return 'unknown-error';
    }
  }

  /// Returns true if the user has an open Tier 2 deletion request that
  /// hasn't expired yet. Errors fall through to false so a backend hiccup
  /// doesn't trap the user on the deletion page.
  Future<bool> _isPendingDeletion() async {
    try {
      final res = await Supabase.instance.client
          .rpc('rpc_get_account_deletion_status');
      if (res is! Map) return false;
      final raw = res['deletion_requested_at']?.toString();
      if (raw == null || raw.isEmpty) return false;
      final dt = DateTime.tryParse(raw)?.toUtc();
      if (dt == null) return false;
      // Inside the 30-day window?
      return DateTime.now().toUtc().difference(dt).inDays < 30;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _rotationController.dispose();
    _sizeController.dispose();
    _shiftController.dispose();
    _textFadeController.dispose();
    _fadeOutController.dispose();
    _backgroundShiftController.dispose();
    _bottomTextFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // إذا تغيّر الـpadding.top أو الاتجاه (iOS notch) نحدّث الهدف أثناء العرض
    final newTarget = _computeTopTargetHeight(context);
    if ((newTarget - _topTargetHeight).abs() > 0.5) {
      _topTargetHeight = newTarget;
      _backgroundHeightAnimation = Tween<double>(
        begin: _backgroundHeightAnimation.value,
        end: _topTargetHeight,
      ).animate(CurvedAnimation(parent: _backgroundShiftController, curve: Curves.easeInOut));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _backgroundShiftController,
            builder: (context, child) {
              return Align(
                alignment: Alignment.topCenter,
                child: ClipPath(
                  clipper: CustomTopBarClipper(),
                  child: Container(
                    width: screenWidth,
                    height: _backgroundHeightAnimation.value,
                    color: AppColors.main,
                  ),
                ),
              );
            },
          ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _fadeInController,
                _rotationController,
                _sizeController,
                _shiftController,
                _textFadeController,
                _fadeOutController,
              ]),
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeOutAnimation.value,
                  child: Transform.translate(
                    offset: Offset(screenWidth / 4 + _shiftAnimation.value, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.ltr,
                      children: [
                        Transform.rotate(
                          angle: _rotationAnimation.value,
                          child: SvgPicture.asset(
                            "assets/images/DocSera-shape-white.svg",
                            width: _sizeAnimation.value,
                          ),
                        ),
                        const SizedBox(width: 1),
                        AnimatedOpacity(
                          opacity: _textFadeAnimation.value,
                          duration: const Duration(milliseconds: 600),
                          child: SvgPicture.asset(
                            "assets/images/DocSera-text.svg",
                            width: 180,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (appVersion.isNotEmpty)
            Positioned(
              bottom: 35,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _bottomTextFadeAnimation.value,
                duration: const Duration(milliseconds: 600),
                child: Text(
                  appVersion,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.getText4(context).copyWith(
                    color: AppColors.grayMain,
                    fontWeight: FontWeight.w300,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


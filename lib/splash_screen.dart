import 'package:docsera/app/text_styles.dart';
import 'package:docsera/screens/home/shimmer/shimmer_widgets.dart';
import 'package:docsera/utils/custom_clippers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'dart:async';
import 'dart:math';
import 'Business_Logic/Authentication/auth_cubit.dart';
import 'Business_Logic/Authentication/auth_state.dart';
import 'app/const.dart';
import 'package:package_info_plus/package_info_plus.dart';


class SplashScreen extends StatefulWidget {
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

  late Animation<double> _fadeInAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _shiftAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _backgroundHeightAnimation;
  late Animation<double> _bottomTextFadeAnimation;

  double screenHeight = 0;
  double screenWidth = 0;

  String appVersion = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenHeight = MediaQuery.of(context).size.height;
    screenWidth = MediaQuery.of(context).size.width;

    PackageInfo.fromPlatform().then((info) {
      setState(() {
        appVersion = 'v${info.version}';
      });
    });


    // ✅ Step 1: Shape Appears (Fade In)
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn));

    // ✅ Step 2: Shape Rotates Slowly & Shrinks
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi * 2).animate(CurvedAnimation(parent: _rotationController, curve: Curves.easeOut));

    _sizeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _sizeAnimation = Tween<double>(begin: 160, end: 50).animate(CurvedAnimation(parent: _sizeController, curve: Curves.easeOut));

    // ✅ Step 3: Shape Moves Left AFTER Rotation Stops
    _shiftController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _shiftAnimation = Tween<double>(begin: 0, end: -screenWidth * 0.25).animate(CurvedAnimation(parent: _shiftController, curve: Curves.easeInOut));

    // ✅ Step 4: Text Logo Appears AFTER Shape Moves
    _textFadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textFadeController, curve: Curves.easeIn));

    // ✅ Step 5: Fade Out Both Elements Before Background Moves
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeOutAnimation = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn));

    // ✅ Step 6: Move Background Upwards & Keep Bottom White
    _backgroundShiftController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _backgroundHeightAnimation = Tween<double>(
      begin: screenHeight * 0.95,
      end: screenHeight * 0.411,
    ).animate(CurvedAnimation(parent: _backgroundShiftController, curve: Curves.easeInOut));

    // ✅ Step 7: Fade Out Bottom Texts when Background Moves
    _bottomTextFadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _bottomTextFadeAnimation = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _bottomTextFadeController, curve: Curves.easeIn));

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _fadeInController.forward(); // 1️⃣ Fade In the Shape
    await Future.delayed(const Duration(milliseconds: 600)); // ⬅️ تم تقليل الزمن

    _rotationController.forward();
    _sizeController.forward();
    await Future.delayed(const Duration(milliseconds: 1200)); // ⬅️ تقليل الزمن هنا أيضًا

    _shiftController.forward();
    await Future.delayed(const Duration(milliseconds: 400)); // ⬅️ تقليل زمن الانتظار

    _textFadeController.forward();
    await Future.delayed(const Duration(milliseconds: 1000)); // ⬅️ تقليل الزمن

    _fadeOutController.forward();
    _bottomTextFadeController.forward();
    _backgroundShiftController.forward();
    await Future.delayed(const Duration(milliseconds: 800)); // ⬅️ تعديل المدة

    await _waitForAuthReady();
    _navigateToHomeScreen();
  }

  void _navigateToHomeScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: CustomBottomNavigationBar(),
          );
        },
      ),
    );
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

  Future<void> _waitForAuthReady() async {
    final authCubit = context.read<AuthCubit>();
    AuthState state = authCubit.state;

    // ✅ إذا AuthCubit ما خلّص بعد (ما زال AuthInitial أو AuthLoading)
    if (state is AuthInitial || state is AuthLoading) {
      // انتظر حتى يطلق حالة AuthAuthenticated أو AuthUnauthenticated
      await authCubit.stream.firstWhere((newState) =>
      newState is AuthAuthenticated || newState is AuthUnauthenticated);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ✅ Move Background Up
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

          // ✅ Shape & Text Logo Animation
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
                            "assets/images/DocSera-shape.svg",
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

          // ✅ **Bottom Texts (Version & Powered by TechSpearz)**
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _bottomTextFadeAnimation.value,
              duration: const Duration(milliseconds: 600),
              child: Text(
                appVersion.isEmpty ? '' : appVersion,
                textAlign: TextAlign.center,
                style: AppTextStyles.getText4(context).copyWith(
                  color: AppColors.grayMain,
                  fontWeight: FontWeight.w300,
                  fontSize: 8
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _bottomTextFadeAnimation.value,
              duration: const Duration(milliseconds: 600),
              child: Text("Powered by TechSpearz", textAlign: TextAlign.center, style: AppTextStyles.getText4(context).copyWith(color: AppColors.grayMain, fontSize: 8)),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/const.dart';
import '../../../app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

class GoodbyePage extends StatefulWidget {
  const GoodbyePage({super.key});

  @override
  State<GoodbyePage> createState() => _GoodbyePageState();
}

class _GoodbyePageState extends State<GoodbyePage> {
  final Random _random = Random();
  List<_AnimatedLogo> _logos = [];
  bool _logosVisible = true;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 10), () {
      _generateLogos();
      _startAnimationLoop();
      if (mounted) {
        setState(() => _logosVisible = false);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _logosVisible = true);
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _generateLogos() {
    _logos = List.generate(10, (index) {
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

  void _startAnimationLoop() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
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

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background3,
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: _logos.map((logo) => logo.build(context, _logosVisible)).toList(),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/docsera_main.svg',
                    width: 150.w,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    local.goodbyeMessage,
                    style: AppTextStyles.getTitle1(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    local.goodbyeSubtext,
                    style: AppTextStyles.getText2(context).copyWith(
                      color: AppColors.grayMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 50.h),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        fadePageRoute(const CustomBottomNavigationBar()),
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.main,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: SizedBox(
                      width: 200.w,
                      child: Center(
                        child: Text(
                          local.goToHomepage,
                          style: AppTextStyles.getText2(context).copyWith(
                            color: AppColors.whiteText,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      : size = random.nextDouble() * 30 + 40,
        opacity = random.nextDouble() * 0.5 + 0.5,
        left = random.nextDouble() * 350,
        top = random.nextDouble() * 650,
        moveX = random.nextDouble() * 80 - 40,
        moveY = random.nextDouble() * 80 - 40,
        blur = 5 + (random.nextDouble() * 10);

  Widget build(BuildContext context, bool isVisible) {
    return Positioned(
      left: left.w,
      top: top.h,
      child: TweenAnimationBuilder<double>(
        duration: Duration(seconds: isVisible ? 20 : 3),
        tween: Tween(begin: isVisible ? opacity : 0.0, end: isVisible ? opacity : 0.0),
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
                      color: Colors.white.withOpacity(0.4),
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: SvgPicture.asset(
                  logoPath,
                  height: size.h,
                  width: size.w,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(0.35),
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

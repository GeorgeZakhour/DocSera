import 'dart:async';
import 'dart:math';
import 'package:docsera/widgets/custom_bottom_navigation_bar.dart';
import 'package:docsera/utils/page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/const.dart';
import '../../../app/text_styles.dart';
import '../../../models/sign_up_info.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:confetti/confetti.dart';

class WelcomePage extends StatefulWidget {
  final SignUpInfo signUpInfo;

  const WelcomePage({super.key, required this.signUpInfo});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final Random _random = Random();
  List<_AnimatedLogo> _logos = [];
  bool _logosVisible = true;
  late ConfettiController _confettiController;


  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

    Future.delayed(const Duration(seconds: 5), () {
      _generateLogos();
      _startAnimationLoop();
      if (mounted) {
        setState(() {
          _logosVisible = false; // تبدأ مخفية
        });
      }

      // ✅ ثم تظهر بسلاسة بعد نصف ثانية
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _logosVisible = true;
          });
        }
      });
    });


  }


  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }


  /// ✅ Generate initial logos with random properties
  void _generateLogos() {
    _logos = List.generate(10, (index) {
      return _AnimatedLogo(
        random: _random,
        logoPath: _getRandomLogo(),
        delay: _random.nextInt(5), // ✅ Different delay for each
      );
    });
  }

  /// ✅ Randomly select one of the three logos
  String _getRandomLogo() {
    List<String> logos = [
      'assets/images/DocSera-shape-main.svg',
      'assets/images/DocSera-shape-main2.svg',
      'assets/images/DocSera-shape-main3.svg',
    ];
    return logos[_random.nextInt(logos.length)];
  }

  /// ✅ Start Animation Loop (10 sec visible → fade out → 10 sec visible → repeat)
  void _startAnimationLoop() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;

      setState(() {
        _logosVisible = false; // ✅ Start fading out
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;

        setState(() {
          _generateLogos(); // ✅ Generate new ones after old ones disappear
          _logosVisible = true; // ✅ Fade new ones in
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background3,
      body: Stack(
        children: [

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 35,
              maximumSize: const Size(8, 8), // ✅ حجم صغير جداً
              minimumSize: const Size(4, 4),
              shouldLoop: false,
              colors: [
                AppColors.main,
                AppColors.main.withOpacity(0.7),
                AppColors.main.withOpacity(0.5),
                Colors.white.withOpacity(0.6),
              ],
            ),
          ),

          // ✅ Animated Background Logos
          Positioned.fill(
            child: Stack(
              children: _logos.map((logo) => logo.build(context, _logosVisible)).toList(),
            ),
          ),

          // ✅ Main Content
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
                    "🎉 ${AppLocalizations.of(context)!.welcomeToDocsera} ${widget.signUpInfo.firstName}!",
                    style: AppTextStyles.getTitle1(context).copyWith(
                      color: AppColors.main,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10.h),

                  Text(
                    AppLocalizations.of(context)!.welcomeMessageInfo,
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
                          AppLocalizations.of(context)!.goToHomepage,
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

/// **🎨 Animated Logo Class**
class _AnimatedLogo   {
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
      : size = random.nextDouble() * 30 + 40, // ✅ أصغر: بين 40 و 80
        opacity = random.nextDouble() * 0.5 + 0.5, // ✅ شفافية من 0.5 إلى 1
        left = random.nextDouble() * 350,
        top = random.nextDouble() * 650,
        moveX = random.nextDouble() * 80 - 40, // ✅ حركة أسرع (±40)
        moveY = random.nextDouble() * 80 - 40, // ✅ حركة أسرع (±40),
        blur = 5 + (random.nextDouble() * 10); // ✅ بلور من 5 إلى 15 حسب الحجم تقريبًا

  Widget build(BuildContext context, bool isVisible) {
    return Positioned(
      left: left.w,
      top: top.h,
      child: TweenAnimationBuilder<double>(
        duration: Duration(seconds: isVisible ? 20 : 3),
        tween: Tween(begin: isVisible ? opacity : 0.0, end: isVisible ? opacity : 0.0),
        builder: (context, value, child) {
          return AnimatedContainer(
            duration: const Duration(seconds: 8), // ✅ حركة أسرع
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

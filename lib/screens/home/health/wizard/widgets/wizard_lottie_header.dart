import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:docsera/app/const.dart';

/// Lottie illustration sitting inside a soft tinted circular bubble.
///
/// The bubble is the design anchor — it remains visible even when the
/// Lottie JSON is an empty placeholder, and gives real Lotties a halo
/// to read against the page backdrop.
class WizardLottieHeader extends StatelessWidget {
  final String assetName;
  final double bubbleSize;
  final double lottieSize;

  const WizardLottieHeader({
    super.key,
    required this.assetName,
    this.bubbleSize = 96,
    this.lottieSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: bubbleSize.w,
      height: bubbleSize.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.main.withValues(alpha: 0.10),
            AppColors.main.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: AppColors.main.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: lottieSize.w,
        height: lottieSize.w,
        child: Lottie.asset(
          'assets/lottie/health_profile/$assetName.json',
          repeat: true,
          errorBuilder: (_, error, stack) => Icon(
            Icons.favorite_rounded,
            size: (lottieSize * 0.6).w,
            color: AppColors.main,
          ),
        ),
      ),
    );
  }
}

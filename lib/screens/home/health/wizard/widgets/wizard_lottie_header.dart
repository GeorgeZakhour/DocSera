import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:docsera/app/const.dart';

/// Lottie illustration sitting inside a soft tinted circular bubble.
///
/// A meaningful Material [icon] is rendered as a base layer so the bubble
/// is never visually empty — handy while Lottie placeholders are still
/// empty stubs. Real Lotties (when added) render on top of the icon and
/// effectively replace it.
class WizardLottieHeader extends StatelessWidget {
  final String assetName;
  final IconData icon;
  final double bubbleSize;
  final double lottieSize;
  final double iconSize;

  const WizardLottieHeader({
    super.key,
    required this.assetName,
    required this.icon,
    this.bubbleSize = 96,
    this.lottieSize = 64,
    this.iconSize = 38,
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: iconSize.w,
            color: AppColors.main,
          ),
          SizedBox(
            width: lottieSize.w,
            height: lottieSize.w,
            child: Lottie.asset(
              'assets/lottie/health_profile/$assetName.json',
              repeat: true,
              // If the asset can't load, just leave the icon visible.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

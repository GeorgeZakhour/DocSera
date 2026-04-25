import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:docsera/app/const.dart';

/// Small Lottie illustration shown above each wizard step's title.
///
/// Loads from `assets/lottie/health_profile/<assetName>.json` (registered
/// in pubspec.yaml). On any load/parse failure, falls back to a simple
/// heart icon — the wizard does not block on Lottie errors.
class WizardLottieHeader extends StatelessWidget {
  final String assetName; // e.g. 'vitals_height'
  final double size;

  const WizardLottieHeader({
    super.key,
    required this.assetName,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.w,
      height: size.w,
      child: Lottie.asset(
        'assets/lottie/health_profile/$assetName.json',
        repeat: true,
        errorBuilder: (_, error, stack) => Icon(
          Icons.favorite_rounded,
          size: (size * 0.6).w,
          color: AppColors.main,
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Glass pill banner shown at the top of the Health page when the patient
/// hasn't completed their health profile yet. Tap to launch the wizard.
class CompleteProfileBanner extends StatefulWidget {
  /// 0..1 — fraction of the profile filled. v1: pass 0.0 (decorative-only).
  final double progress;
  final VoidCallback onTap;

  const CompleteProfileBanner({
    super.key,
    required this.progress,
    required this.onTap,
  });

  @override
  State<CompleteProfileBanner> createState() => _CompleteProfileBannerState();
}

class _CompleteProfileBannerState extends State<CompleteProfileBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.main.withValues(alpha: 0.30),
            ),
            gradient: LinearGradient(colors: [
              AppColors.main.withValues(alpha: 0.10),
              AppColors.mainDark.withValues(alpha: 0.05),
            ]),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + 0.04 * _pulse.value,
                  child: SizedBox(
                    width: 52.w,
                    height: 52.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 52.w,
                          height: 52.w,
                          child: CircularProgressIndicator(
                            value: widget.progress.clamp(0.0, 1.0),
                            strokeWidth: 3.5,
                            backgroundColor:
                                AppColors.main.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.main,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.favorite_rounded,
                          color: AppColors.main,
                          size: 22.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.healthProfile_banner_title,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        fontSize: 14.sp,
                        color: AppColors.mainDark,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      t.healthProfile_banner_subtitle,
                      style: TextStyle(
                        color: AppColors.grayMain,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: widget.onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.main,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                ),
                child: Text(
                  t.healthProfile_banner_cta,
                  style: TextStyle(fontSize: 13.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

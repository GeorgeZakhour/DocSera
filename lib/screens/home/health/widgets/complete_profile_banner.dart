import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';

/// Premium hero card shown at the top of the Health page when the patient
/// hasn't completed their health profile yet. Tap anywhere on the card or
/// on the explicit Start button to launch the wizard.
class CompleteProfileBanner extends StatelessWidget {
  /// Reserved for a future progress indicator. Not rendered in v1.
  final double progress;
  final VoidCallback onTap;

  const CompleteProfileBanner({
    super.key,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 14.w, 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                AppColors.background4,
              ],
            ),
            border: Border.all(
              color: AppColors.main.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.mainDark.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _HeartBubble(),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.healthProfile_banner_title,
                      style: AppTextStyles.getTitle1(context).copyWith(
                        fontSize: 13.5.sp,
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PointsPill(),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            t.healthProfile_banner_subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.grayMain,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              _StartChip(label: t.healthProfile_banner_cta, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartBubble extends StatefulWidget {
  @override
  State<_HeartBubble> createState() => _HeartBubbleState();
}

class _HeartBubbleState extends State<_HeartBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 1.0 + 0.05 * _pulse.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.main.withValues(alpha: 0.20),
                  AppColors.main.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: AppColors.main.withValues(alpha: 0.25),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.favorite_rounded,
              color: AppColors.main,
              size: 22.sp,
            ),
          ),
        );
      },
    );
  }
}

class _PointsPill extends StatelessWidget {
  const _PointsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.main, AppColors.mainDark],
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, color: Colors.white, size: 10.sp),
          SizedBox(width: 1.w),
          Text(
            '15',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StartChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.main, AppColors.mainDark],
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: AppColors.main.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 5.w),
                Icon(
                  isRtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 14.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/health_profile_wizard_page.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

/// Compact horizontal CTA card for surfacing the "complete your health
/// profile, earn +15" prompt outside the Health page.
///
/// Self-loads completion state from `users.health_profile_completed_at`;
/// renders nothing when the user has already completed the wizard or
/// when no auth session exists.
class HealthProfileCompactCta extends StatefulWidget {
  const HealthProfileCompactCta({super.key});

  @override
  State<HealthProfileCompactCta> createState() =>
      _HealthProfileCompactCtaState();
}

class _HealthProfileCompactCtaState extends State<HealthProfileCompactCta> {
  bool _loading = true;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _loading = false; _show = false; });
      return;
    }
    try {
      final res = await client
          .from('users')
          .select('health_profile_completed_at')
          .eq('id', user.id)
          .maybeSingle();
      final raw = res?['health_profile_completed_at'] as String?;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _show = raw == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _show = false; });
    }
  }

  void _open() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthProfileWizardPage(
          repo: HealthProfileRepository(),
          userId: user.id,
        ),
      ),
    ).then((_) => _check());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_show) return const SizedBox.shrink();
    final t = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppColors.background4,
              ],
            ),
            border: Border.all(
              color: AppColors.main.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              _MiniBadge(),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.healthProfile_points_inline_title,
                      style: AppTextStyles.getText1(context).copyWith(
                        color: AppColors.mainDark,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      t.healthProfile_points_inline_subtitle,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: AppColors.grayMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppColors.main,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.healthProfile_points_inline_cta,
                      style: AppTextStyles.getText3(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      isRtl
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 12.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.main, AppColors.mainDark],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  '+',
                  style: AppTextStyles.getText3(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '15',
                style: AppTextStyles.getText1(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Icon(
              Icons.star_rounded,
              size: 10.sp,
              color: Colors.amber.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

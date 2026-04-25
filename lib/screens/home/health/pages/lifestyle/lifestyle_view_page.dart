import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/health_profile_wizard_page.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

enum _LifestyleField { sport, smoking, alcohol }

class LifestyleViewPage extends StatefulWidget {
  const LifestyleViewPage({super.key});

  @override
  State<LifestyleViewPage> createState() => _LifestyleViewPageState();
}

class _LifestyleViewPageState extends State<LifestyleViewPage> {
  final HealthProfileRepository _repo = HealthProfileRepository();
  Map<String, dynamic>? _row;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    final row = await _repo.fetchOwnProfile(userId);
    if (!mounted) return;
    setState(() {
      _row = row;
      _loading = false;
    });
  }

  void _openWizard() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthProfileWizardPage(repo: _repo, userId: userId),
      ),
    ).then((_) => _load());
  }

  String? _freqLabel(AppLocalizations t, String? code) {
    switch (code) {
      case 'never':
        return t.healthProfile_freq_never;
      case 'less_than_weekly':
        return t.healthProfile_freq_lt_weekly;
      case '1_2':
        return t.healthProfile_freq_1_2;
      case '3_4':
        return t.healthProfile_freq_3_4;
      case '5_plus':
        return t.healthProfile_freq_5_plus;
      default:
        return null;
    }
  }

  String? _smokingLabel(AppLocalizations t, String? code) {
    switch (code) {
      case 'never':
        return t.healthProfile_smoking_never;
      case 'former':
        return t.healthProfile_smoking_former;
      case 'occasional':
        return t.healthProfile_smoking_occasional;
      case 'daily':
        return t.healthProfile_smoking_daily;
      default:
        return null;
    }
  }

  Future<void> _edit(_LifestyleField field) async {
    final t = AppLocalizations.of(context)!;
    final List<({String code, String label})> options;
    final String currentCode;
    final String title;

    switch (field) {
      case _LifestyleField.sport:
        title = t.healthProfile_step_sport_title;
        currentCode = _row?['sport_frequency'] as String? ?? '';
        options = [
          (code: 'never', label: t.healthProfile_freq_never),
          (code: 'less_than_weekly', label: t.healthProfile_freq_lt_weekly),
          (code: '1_2', label: t.healthProfile_freq_1_2),
          (code: '3_4', label: t.healthProfile_freq_3_4),
          (code: '5_plus', label: t.healthProfile_freq_5_plus),
        ];
        break;
      case _LifestyleField.smoking:
        title = t.healthProfile_step_smoking_title;
        currentCode = _row?['smoking_status'] as String? ?? '';
        options = [
          (code: 'never', label: t.healthProfile_smoking_never),
          (code: 'former', label: t.healthProfile_smoking_former),
          (code: 'occasional', label: t.healthProfile_smoking_occasional),
          (code: 'daily', label: t.healthProfile_smoking_daily),
        ];
        break;
      case _LifestyleField.alcohol:
        title = t.healthProfile_step_alcohol_title;
        currentCode = _row?['alcohol_frequency'] as String? ?? '';
        options = [
          (code: 'never', label: t.healthProfile_freq_never),
          (code: 'less_than_weekly', label: t.healthProfile_freq_lt_weekly),
          (code: '1_2', label: t.healthProfile_freq_1_2),
          (code: '3_4', label: t.healthProfile_freq_3_4),
          (code: '5_plus', label: t.healthProfile_freq_5_plus),
        ];
        break;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.getTitle2(context).copyWith(
                  color: AppColors.mainDark,
                ),
              ),
              SizedBox(height: 16.h),
              ...options.map((o) {
                final isSel = o.code == currentCode;
                return InkWell(
                  onTap: () => Navigator.pop(sheetCtx, o.code),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
                    margin: EdgeInsets.only(bottom: 6.h),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.main.withValues(alpha: 0.08)
                          : null,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.main.withValues(
                          alpha: isSel ? 0.3 : 0.10,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            o.label,
                            style: AppTextStyles.getText1(context).copyWith(
                              color: isSel
                                  ? AppColors.mainDark
                                  : AppColors.blackText,
                              fontWeight:
                                  isSel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSel)
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.main,
                            size: 20.sp,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;

    switch (field) {
      case _LifestyleField.sport:
        await _repo.upsertVitalsLifestyle(sportFrequency: selected);
        break;
      case _LifestyleField.smoking:
        await _repo.upsertVitalsLifestyle(smokingStatus: selected);
        break;
      case _LifestyleField.alcohol:
        await _repo.upsertVitalsLifestyle(alcoholFrequency: selected);
        break;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final sport = _row?['sport_frequency'] as String?;
    final smoking = _row?['smoking_status'] as String?;
    final alcohol = _row?['alcohol_frequency'] as String?;
    final hasAny = sport != null || smoking != null || alcohol != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          t.healthProfile_lifestyle_card_title,
          style: AppTextStyles.getTitle2(context).copyWith(
            color: AppColors.mainDark,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.mainDark),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
              child: hasAny
                  ? _buildLoaded(t, sport, smoking, alcohol)
                  : _EmptyView(onComplete: _openWizard),
            ),
    );
  }

  Widget _buildLoaded(
    AppLocalizations t,
    String? sport,
    String? smoking,
    String? alcohol,
  ) {
    return ListView(
      children: [
        _LifestyleRow(
          icon: Icons.directions_run_rounded,
          label: t.healthProfile_step_sport_title,
          value: _freqLabel(t, sport) ?? '—',
          onTap: () => _edit(_LifestyleField.sport),
        ),
        SizedBox(height: 10.h),
        _LifestyleRow(
          icon: Icons.smoking_rooms_rounded,
          label: t.healthProfile_step_smoking_title,
          value: _smokingLabel(t, smoking) ?? '—',
          onTap: () => _edit(_LifestyleField.smoking),
        ),
        SizedBox(height: 10.h),
        _LifestyleRow(
          icon: Icons.local_bar_rounded,
          label: t.healthProfile_step_alcohol_title,
          value: _freqLabel(t, alcohol) ?? '—',
          onTap: () => _edit(_LifestyleField.alcohol),
        ),
      ],
    );
  }
}

class _LifestyleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _LifestyleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.main.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.main.withValues(alpha: 0.10),
                    ),
                    child: Icon(icon, size: 18.sp, color: AppColors.mainDark),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.grayMain,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.grayMain.withValues(alpha: 0.6),
                    size: 18.sp,
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                value,
                style: AppTextStyles.getText1(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onComplete;
  const _EmptyView({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 64.sp,
            color: AppColors.main.withValues(alpha: 0.40),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              t.healthProfile_view_no_data,
              textAlign: TextAlign.center,
              style: AppTextStyles.getText2(context).copyWith(
                color: AppColors.grayMain,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              t.healthProfile_view_complete_button,
              style: AppTextStyles.getText2(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

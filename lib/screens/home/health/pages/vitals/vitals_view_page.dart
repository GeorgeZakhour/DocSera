import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/health_profile_wizard_page.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

/// Read-only view of the patient's vitals (height, weight, BMI).
/// Tapping the bottom CTA reopens the wizard so the user can edit;
/// the RPC is idempotent so no points are re-awarded.
class VitalsViewPage extends StatefulWidget {
  const VitalsViewPage({super.key});

  @override
  State<VitalsViewPage> createState() => _VitalsViewPageState();
}

class _VitalsViewPageState extends State<VitalsViewPage> {
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final height = _row?['height_cm'] as num?;
    final weight = _row?['weight_kg'] as num?;
    final bmi = (height != null && weight != null && height > 0)
        ? (weight / ((height / 100) * (height / 100)))
        : null;
    final hasAny = height != null || weight != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          t.healthProfile_vitals_card_title,
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
                  ? _buildLoaded(t, height, weight, bmi)
                  : _buildEmpty(t),
            ),
    );
  }

  Widget _buildLoaded(AppLocalizations t, num? height, num? weight, num? bmi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ValueCard(
          icon: Icons.height_rounded,
          label: t.vital_height,
          value: height == null ? '—' : '$height cm',
        ),
        SizedBox(height: 10.h),
        _ValueCard(
          icon: Icons.monitor_weight_rounded,
          label: t.vital_weight,
          value: weight == null ? '—' : '$weight kg',
        ),
        SizedBox(height: 10.h),
        _ValueCard(
          icon: Icons.straighten_rounded,
          label: t.healthProfile_view_bmi_label,
          value: bmi == null ? '—' : bmi.toStringAsFixed(1),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _openWizard,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              t.healthProfile_view_update,
              style: AppTextStyles.getText2(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(AppLocalizations t) => _EmptyView(onComplete: _openWizard);
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ValueCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.main.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.main.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 20.sp, color: AppColors.mainDark),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.getText2(context).copyWith(
                color: AppColors.grayMain,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.getText1(context).copyWith(
              color: AppColors.mainDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
            Icons.favorite_rounded,
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

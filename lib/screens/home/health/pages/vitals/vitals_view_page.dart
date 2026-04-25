import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:docsera/app/const.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/wizard/health_profile_wizard_page.dart';
import 'package:docsera/services/supabase/repositories/health_profile_repository.dart';

/// View + inline-edit page for the patient's vitals (height, weight, BMI).
/// Tap any row to update that field via a small dialog. BMI is read-only
/// because it's derived from height + weight.
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

  Future<void> _editHeight() async {
    final t = AppLocalizations.of(context)!;
    final current = _row?['height_cm'] as num?;
    final result = await _showNumberEditDialog(
      title: t.healthProfile_step_height_title,
      label: t.healthProfile_step_height_input,
      initial: current?.toString(),
    );
    if (result == null) return;
    await _repo.upsertVitalsLifestyle(heightCm: result);
    await _load();
  }

  Future<void> _editWeight() async {
    final t = AppLocalizations.of(context)!;
    final current = _row?['weight_kg'] as num?;
    final result = await _showNumberEditDialog(
      title: t.healthProfile_step_weight_title,
      label: t.healthProfile_step_weight_input,
      initial: current?.toString(),
    );
    if (result == null) return;
    await _repo.upsertVitalsLifestyle(weightKg: result);
    await _load();
  }

  Future<num?> _showNumberEditDialog({
    required String title,
    required String label,
    required String? initial,
  }) {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<num?>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: AppTextStyles.getTitle2(context).copyWith(
                  color: AppColors.mainDark,
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: AppTextStyles.getText1(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: AppTextStyles.getText2(context).copyWith(
                    color: Colors.grey,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 14.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.r),
                    borderSide:
                        const BorderSide(color: AppColors.main, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        side: BorderSide(
                          color: AppColors.grayMain.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        t.cancel,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: AppColors.grayMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.main,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: () {
                        final v = int.tryParse(controller.text.trim());
                        Navigator.pop(dialogCtx, v);
                      },
                      child: Text(
                        t.save,
                        style: AppTextStyles.getText2(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                  : _EmptyView(onComplete: _openWizard),
            ),
    );
  }

  Widget _buildLoaded(AppLocalizations t, num? height, num? weight, num? bmi) {
    return ListView(
      children: [
        _ValueRow(
          icon: Icons.height_rounded,
          label: t.vital_height,
          value: height == null ? '—' : '$height cm',
          onTap: _editHeight,
        ),
        SizedBox(height: 10.h),
        _ValueRow(
          icon: Icons.monitor_weight_rounded,
          label: t.vital_weight,
          value: weight == null ? '—' : '$weight kg',
          onTap: _editWeight,
        ),
        SizedBox(height: 10.h),
        _ValueRow(
          icon: Icons.straighten_rounded,
          label: t.healthProfile_view_bmi_label,
          subtitle: t.healthProfile_bmi_explanation,
          value: bmi == null ? '—' : bmi.toStringAsFixed(1),
          onTap: null, // computed — not editable
        ),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String value;
  final VoidCallback? onTap;
  const _ValueRow({
    required this.icon,
    required this.label,
    this.subtitle,
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
            border:
                Border.all(color: AppColors.main.withValues(alpha: 0.10)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.getText2(context).copyWith(
                        color: AppColors.grayMain,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle!,
                        style: AppTextStyles.getText3(context).copyWith(
                          color: AppColors.grayMain.withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                value,
                style: AppTextStyles.getText1(context).copyWith(
                  color: AppColors.mainDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onTap != null) ...[
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.grayMain.withValues(alpha: 0.6),
                  size: 18.sp,
                ),
              ],
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

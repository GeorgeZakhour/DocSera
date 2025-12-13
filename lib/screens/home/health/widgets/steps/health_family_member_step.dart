import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:docsera/app/text_styles.dart';
import 'package:docsera/app/const.dart';
import 'package:docsera/gen_l10n/app_localizations.dart';
import 'package:docsera/screens/home/health/widgets/health_primary_button.dart';

class FamilyMembersStep extends StatefulWidget {

  final List<String> selected; // keep API as list
  final void Function(List<String>) onChanged;
  final VoidCallback onNext;

  const FamilyMembersStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<FamilyMembersStep> createState() => _FamilyMembersStepState();
}

class _FamilyMembersStepState extends State<FamilyMembersStep> {
  String? _selected; // SINGLE VALUE

  @override
  void initState() {
    super.initState();
    _selected = widget.selected.isNotEmpty ? widget.selected.first : null;
  }

  void _select(String m) {
    setState(() {
      _selected = m;
    });

    // Return a list with one item to match cubit signature
    widget.onChanged([m]);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final members = [
      t.family_father,
      t.family_mother,
      t.family_brother,
      t.family_sister,
      t.family_maternal_grandfather,
      t.family_maternal_grandmother,
      t.family_paternal_grandfather,
      t.family_paternal_grandmother,
      t.family_daughter,
      t.family_son,
      t.family_uncle,
      t.family_aunt,
      t.family_cousin_f,
      t.family_cousin_m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        SizedBox(height: 10.h),

        Text(
          t.addFamily_step2_title,
          style: AppTextStyles.getTitle1(context).copyWith(
            color: AppColors.mainDark,
            fontSize: 12.sp,
          ),
        ),

        SizedBox(height: 4.h),

        Text(
          t.addFamily_step2_desc,
          style: AppTextStyles.getText3(context).copyWith(
            fontSize: 10.sp,
            color: AppColors.grayMain,
          ),
        ),

        SizedBox(height: 14.h),

        Expanded(
          child: ListView.separated(
            itemCount: members.length,
            separatorBuilder: (_, __) => Divider(height: 1),
            itemBuilder: (context, index) {
              final m = members[index];
              final selected = _selected == m;

              return InkWell(
                onTap: () => _select(m),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (_) => _select(m),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        activeColor: AppColors.main,   // ← اللون الأساسي
                        checkColor: Colors.white,      // ← لون علامة الصح
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          m,
                          style: AppTextStyles.getText2(context),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        HealthPrimaryButton(
          text: t.next,
          enabled: _selected != null,
          onTap: _selected != null ? widget.onNext : null,
        ),

        SizedBox(height: 15.h),
      ],
    );
  }
}
